import Foundation
import Network

public struct DLNADevice: Identifiable, Hashable {
    public let id: String
    public var name: String
    public let ipAddress: String
    public var controlURL: URL?
    public var isManual: Bool = false

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: DLNADevice, rhs: DLNADevice) -> Bool {
        lhs.ipAddress == rhs.ipAddress
    }
}

/// Hem SSDP Multicast, hem Apple Bonjour, hem de Subnet Sweep (Yerel Ağ Taraması)
/// yöntemlerini aynı anda kullanarak Vestel ve diğer tüm TV'leri bulan gelişmiş tarayıcı.
public class DLNADiscovery: ObservableObject {
    public static let shared = DLNADiscovery()

    @Published public var discoveredDevices: [DLNADevice] = []
    @Published public var isScanning: Bool = false
    @Published public var scanProgress: String = "Hazır"

    private var udpSocket: NWConnection?
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.opencast.discovery", qos: .userInitiated)

    // Akıllı TV'lerin (Vestel, Samsung, LG, Philips vb.) kullandığı standart UPnP portları
    private let commonTVPorts: [Int] = [8080, 2869, 80, 8008, 7676, 1985]

    public init() {}

    public func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = "Ağ taranıyor..."

        // 1. Apple Bonjour Taraması (iOS Yerel Ağ İznini tetikler)
        startBonjourBrowse()

        // 2. SSDP Multicast Taraması
        sendSSDPMsearch()

        // 3. Yerel Alt Ağ (Subnet IP) Taraması (Multicast engellerini aşar)
        startSubnetSweep()

        // 8 saniye sonra taramayı bitir
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.isScanning = false
            self?.scanProgress = "Tarama tamamlandı"
        }
    }

    // MARK: - 1. Bonjour Taraması (iOS Yerel Ağ İzni İçin Şart)
    private func startBonjourBrowse() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: nil)
        let params = NWParameters()
        params.includePeerToPeer = true
        browser = NWBrowser(for: descriptor, using: params)
        browser?.stateUpdateHandler = { state in
            print("[OpenCast] Bonjour durumu: \(state)")
        }
        browser?.start(queue: queue)
    }

    // MARK: - 2. SSDP Multicast Taraması
    private func sendSSDPMsearch() {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("239.255.255.250"),
            port: NWEndpoint.Port(rawValue: 1900)!
        )

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        udpSocket = NWConnection(to: endpoint, using: params)
        udpSocket?.stateUpdateHandler = { [weak self] state in
            if state == .ready {
                let targets = [
                    "urn:schemas-upnp-org:device:MediaRenderer:1",
                    "urn:schemas-upnp-org:service:AVTransport:1",
                    "ssdp:all"
                ]
                for target in targets {
                    let msg = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 3\r\nST: \(target)\r\n\r\n"
                    if let data = msg.data(using: .utf8) {
                        self?.udpSocket?.send(content: data, completion: .contentProcessed { _ in })
                    }
                }
                self?.listenSSDP()
            }
        }
        udpSocket?.start(queue: queue)
    }

    private func listenSSDP() {
        udpSocket?.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            if let content = content, let response = String(data: content, encoding: .utf8) {
                self.parseSSDPResponse(response)
            }
            if error == nil && !isComplete && self.isScanning {
                self.listenSSDP()
            }
        }
    }

    private func parseSSDPResponse(_ response: String) {
        for line in response.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("location:") {
                let urlStr = line.dropFirst(9).trimmingCharacters(in: .whitespaces)
                if let url = URL(string: urlStr) {
                    fetchDescriptionXML(url)
                }
                break
            }
        }
    }

    // MARK: - 3. Subnet Sweep (Multicast İzolasyonunu Aşan Doğrudan Tarama)
    private func startSubnetSweep() {
        guard let myIP = NetworkUtils.getWiFiAddress() else { return }
        let components = myIP.split(separator: ".")
        guard components.count == 4 else { return }
        let subnetPrefix = "\(components[0]).\(components[1]).\(components[2])."

        // Ev ağlarında en yaygın TV IP aralıkları (1 - 60 ve 100 - 150)
        let ipRanges = Array(1...60) + Array(100...150)

        for i in ipRanges {
            let targetIP = "\(subnetPrefix)\(i)"
            if targetIP == myIP { continue } // Kendi telefonumuzu atla

            // Vestel ve UPnP standart portlarını yokla
            for port in [8080, 2869, 80] {
                if let url = URL(string: "http://\(targetIP):\(port)/description.xml") {
                    probeHTTP(url, ip: targetIP)
                }
            }
        }
    }

    private func probeHTTP(_ url: URL, ip: String) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.2

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            if let data = data, let xml = String(data: data, encoding: .utf8), xml.contains("MediaRenderer") || xml.contains("AVTransport") || xml.contains("Vestel") {
                self?.parseDeviceXML(xml, locationURL: url)
            }
        }.resume()
    }

    private func fetchDescriptionXML(_ url: URL) {
        var req = URLRequest(url: url)
        req.timeoutInterval = 2.0
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let data = data, let xml = String(data: data, encoding: .utf8) else { return }
            self?.parseDeviceXML(xml, locationURL: url)
        }.resume()
    }

    private func parseDeviceXML(_ xml: String, locationURL: URL) {
        var friendlyName = "Akıllı TV"
        if let start = xml.range(of: "<friendlyName>"),
           let end = xml.range(of: "</friendlyName>", range: start.upperBound..<xml.endIndex) {
            friendlyName = String(xml[start.upperBound..<end.lowerBound])
        }

        var controlURL: URL?
        if let sStart = xml.range(of: "urn:schemas-upnp-org:service:AVTransport:1"),
           let cStart = xml.range(of: "<controlURL>", range: sStart.upperBound..<xml.endIndex),
           let cEnd = xml.range(of: "</controlURL>", range: cStart.upperBound..<xml.endIndex) {
            let path = String(xml[cStart.upperBound..<cEnd.lowerBound])
            if path.hasPrefix("http") {
                controlURL = URL(string: path)
            } else {
                controlURL = URL(string: path, relativeTo: locationURL)
            }
        }

        let host = locationURL.host ?? "TV"
        let device = DLNADevice(
            id: "\(host)-\(friendlyName)",
            name: friendlyName,
            ipAddress: host,
            controlURL: controlURL ?? locationURL
        )

        DispatchQueue.main.async {
            if !self.discoveredDevices.contains(where: { $0.ipAddress == device.ipAddress }) {
                self.discoveredDevices.append(device)
            }
        }
    }

    /// Kullanıcının TV'sinin IP'sini doğrudan girmesi için
    public func addManualDevice(ip: String) {
        let cleanIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanIP.isEmpty else { return }

        let device = DLNADevice(
            id: "manual-\(cleanIP)",
            name: "Vestel TV (\(cleanIP))",
            ipAddress: cleanIP,
            controlURL: URL(string: "http://\(cleanIP):2869/upnp/control/rendertransport1"),
            isManual: true
        )

        DispatchQueue.main.async {
            if !self.discoveredDevices.contains(where: { $0.ipAddress == cleanIP }) {
                self.discoveredDevices.insert(device, at: 0)
            }
        }
    }
}
