import Foundation
import Network

public struct DLNADevice: Identifiable, Hashable {
    public let id: String // UDN veya IP
    public let name: String // Örn: "Vestel 50U9500"
    public let ipAddress: String
    public let controlURL: URL?
    public let iconURL: URL?

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: DLNADevice, rhs: DLNADevice) -> Bool {
        lhs.id == rhs.id
    }
}

/// SSDP (Simple Service Discovery Protocol) ile yerel ağdaki
/// Vestel, Samsung, LG, Philips vb. tüm DLNA destekli televizyonları otomatik tarar.
public class DLNADiscovery: ObservableObject {
    public static let shared = DLNADiscovery()

    @Published public var discoveredDevices: [DLNADevice] = []
    @Published public var isScanning: Bool = false

    private var udpSocket: NWConnection?
    private let multicastGroup = "239.255.255.250"
    private let multicastPort: UInt16 = 1900
    private let queue = DispatchQueue(label: "com.opencast.ssdp.discovery", qos: .userInitiated)

    public init() {}

    public func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        discoveredDevices.removeAll()

        sendSSDPMsearch()

        // 6 saniye sonra taramayı tamamlandı durumuna al
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.isScanning = false
        }
    }

    private func sendSSDPMsearch() {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(multicastGroup),
            port: NWEndpoint.Port(rawValue: multicastPort)!
        )

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        udpSocket = NWConnection(to: endpoint, using: params)
        udpSocket?.stateUpdateHandler = { [weak self] state in
            if state == .ready {
                self?.sendSearchPackets()
                self?.listenForResponses()
            }
        }
        udpSocket?.start(queue: queue)
    }

    private func sendSearchPackets() {
        let searchQueries = [
            "urn:schemas-upnp-org:device:MediaRenderer:1",
            "urn:schemas-upnp-org:service:AVTransport:1",
            "ssdp:all"
        ]

        for target in searchQueries {
            let message = "M-SEARCH * HTTP/1.1\r\n" +
                          "HOST: 239.255.255.250:1900\r\n" +
                          "MAN: \"ssdp:discover\"\r\n" +
                          "MX: 3\r\n" +
                          "ST: \(target)\r\n\r\n"

            if let data = message.data(using: .utf8) {
                udpSocket?.send(content: data, completion: .contentProcessed { _ in })
            }
        }
    }

    private func listenForResponses() {
        udpSocket?.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let content = content, let response = String(data: content, encoding: .utf8) {
                self.parseSSDPResponse(response)
            }

            if error == nil && !isComplete && self.isScanning {
                self.listenForResponses()
            }
        }
    }

    private func parseSSDPResponse(_ response: String) {
        let lines = response.components(separatedBy: "\r\n")
        var locationURL: URL?

        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix("location:") {
                let urlString = line.dropFirst(9).trimmingCharacters(in: .whitespaces)
                locationURL = URL(string: urlString)
                break
            }
        }

        guard let location = locationURL else { return }

        // TV'nin XML açıklama dosyasını çekip marka/model adını ve AVTransport adresini al
        URLSession.shared.dataTask(with: location) { [weak self] data, _, error in
            guard let data = data, let xml = String(data: data, encoding: .utf8) else { return }
            self?.parseDeviceXML(xml, locationURL: location)
        }.resume()
    }

    private func parseDeviceXML(_ xml: String, locationURL: URL) {
        // XML'den friendlyName (Örn: Vestel 50U9500) çek
        var friendlyName = "Akıllı TV"
        if let nameRange = xml.range(of: "<friendlyName>"),
           let endRange = xml.range(of: "</friendlyName>", range: nameRange.upperBound..<xml.endIndex) {
            friendlyName = String(xml[nameRange.upperBound..<endRange.lowerBound])
        }

        // AVTransport kontrol URL'sini bul
        var controlURL: URL?
        if xml.contains("urn:schemas-upnp-org:service:AVTransport:1") {
            if let serviceRange = xml.range(of: "urn:schemas-upnp-org:service:AVTransport:1"),
               let controlRange = xml.range(of: "<controlURL>", range: serviceRange.upperBound..<xml.endIndex),
               let endControl = xml.range(of: "</controlURL>", range: controlRange.upperBound..<xml.endIndex) {
                let controlPath = String(xml[controlRange.upperBound..<endControl.lowerBound])
                if controlPath.hasPrefix("http") {
                    controlURL = URL(string: controlPath)
                } else if let base = URL(string: "/", relativeTo: locationURL) {
                    controlURL = URL(string: controlPath, relativeTo: base)
                }
            }
        }

        let host = locationURL.host ?? "Bilinmeyen IP"
        let device = DLNADevice(
            id: "\(host)-\(friendlyName)",
            name: friendlyName,
            ipAddress: host,
            controlURL: controlURL ?? locationURL,
            iconURL: nil
        )

        DispatchQueue.main.async {
            if !self.discoveredDevices.contains(where: { $0.ipAddress == device.ipAddress }) {
                self.discoveredDevices.append(device)
            }
        }
    }
}
