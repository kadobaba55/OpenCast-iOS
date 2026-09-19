import Foundation
import Network

/// Tüm TV ve tarayıcılara Apple'ın yerleşik Network.framework'ü ile
/// sıfır harici bağımlılıkla ve minimum RAM ile yayın yapan HTTP sunucusu.
public class StreamServer {
    public static let shared = StreamServer()

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.opencast.server.queue", qos: .userInteractive)
    private var activeConnections: [NWConnection] = []
    private var streamConnections: [NWConnection] = []
    
    public private(set) var port: UInt16 = 8080
    public private(set) var isRunning: Bool = false

    private init() {}

    public func start(onPort port: UInt16 = 8080) {
        guard !isRunning else { return }
        self.port = port

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.allowLocalEndpointReuse = true

        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("[OpenCast] Sunucu başlatılamadı: \(error)")
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                print("[OpenCast] Yayın sunucusu hazır: Port \(port)")
            case .failed(let err):
                print("[OpenCast] Sunucu hatası: \(err)")
                self?.stop()
            case .cancelled:
                self?.isRunning = false
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: queue)
    }

    public func stop() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
            self.activeConnections.forEach { $0.cancel() }
            self.streamConnections.forEach { $0.cancel() }
            self.activeConnections.removeAll()
            self.streamConnections.removeAll()
            self.isRunning = false
            print("[OpenCast] Sunucu durduruldu.")
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        activeConnections.append(connection)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                self.closeConnection(connection)
                return
            }

            guard let content = content, let requestString = String(data: content, encoding: .utf8) else {
                self.closeConnection(connection)
                return
            }

            self.routeRequest(requestString, on: connection)
        }
    }

    private func routeRequest(_ request: String, on connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            closeConnection(connection)
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            closeConnection(connection)
            return
        }

        let path = parts[1]

        if path == "/stream" || path.starts(with: "/stream?") {
            let header = "HTTP/1.1 200 OK\r\n" +
                         "Connection: close\r\n" +
                         "Server: OpenCast-Universal\r\n" +
                         "Cache-Control: no-cache, private\r\n" +
                         "Pragma: no-cache\r\n" +
                         "Access-Control-Allow-Origin: *\r\n" +
                         "Content-Type: multipart/x-mixed-replace; boundary=--opencastframe\r\n\r\n"

            if let headerData = header.data(using: .utf8) {
                connection.send(content: headerData, completion: .contentProcessed { [weak self] err in
                    if err == nil {
                        self?.streamConnections.append(connection)
                    } else {
                        self?.closeConnection(connection)
                    }
                })
            }
        } else {
            serveWebPlayer(on: connection)
        }
    }

    private func serveWebPlayer(on connection: NWConnection) {
        let htmlContent = WebViewerTemplate.html
        guard let htmlData = htmlContent.data(using: .utf8) else {
            closeConnection(connection)
            return
        }

        let response = "HTTP/1.1 200 OK\r\n" +
                       "Content-Type: text/html; charset=utf-8\r\n" +
                       "Content-Length: \(htmlData.count)\r\n" +
                       "Connection: close\r\n\r\n"

        var fullData = response.data(using: .utf8) ?? Data()
        fullData.append(htmlData)

        connection.send(content: fullData, completion: .contentProcessed { [weak self] _ in
            self?.closeConnection(connection)
        })
    }

    /// Yeni video karesini tüm bağlı TV ve tarayıcılara gönderir
    public func sendFrame(_ jpegData: Data) {
        queue.async { [weak self] in
            guard let self = self, !self.streamConnections.isEmpty else { return }

            let boundary = "\r\n--opencastframe\r\n" +
                           "Content-Type: image/jpeg\r\n" +
                           "Content-Length: \(jpegData.count)\r\n\r\n"

            guard let boundaryData = boundary.data(using: .utf8) else { return }

            var packet = boundaryData
            packet.append(jpegData)

            self.streamConnections.removeAll { conn in
                if conn.state != .ready { return true }
                conn.send(content: packet, completion: .contentProcessed { error in
                    if error != nil {
                        conn.cancel()
                    }
                })
                return false
            }
        }
    }

    private func closeConnection(_ connection: NWConnection) {
        activeConnections.removeAll { $0 === connection }
        streamConnections.removeAll { $0 === connection }
        connection.cancel()
    }
}
