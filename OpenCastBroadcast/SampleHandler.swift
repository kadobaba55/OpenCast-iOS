import ReplayKit
import CoreMedia
import CoreImage
import UIKit
import Network

class SampleHandler: RPBroadcastSampleHandler {

    private var ciContext: CIContext?
    private var lastFrameTime: TimeInterval = 0
    private let frameInterval: TimeInterval = 1.0 / 30.0 
    
    private let processingQueue = DispatchQueue(label: "com.opencast.video.processing", qos: .userInteractive)
    private var isProcessingFrame = false

    private var localConnection: NWConnection?
    private var isConnectedToMainApp = false

    override init() {
        super.init()
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        print("[OpenCast] Ekran yayını başlatıldı.")
        // Bağlantıyı arka plan kuyruğunda başlat (Sistemi asla kilitlemesin)
        processingQueue.async { [weak self] in
            self?.connectToMainAppServer()
        }
    }

    override func broadcastPaused() {
        print("[OpenCast] Yayın duraklatıldı.")
    }

    override func broadcastResumed() {
        print("[OpenCast] Yayın devam ettirildi.")
    }

    override func broadcastFinished() {
        print("[OpenCast] Yayın bitti.")
        processingQueue.async { [weak self] in
            self?.localConnection?.cancel()
            self?.localConnection = nil
            self?.isConnectedToMainApp = false
        }
    }

    private func connectToMainAppServer() {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("127.0.0.1"),
            port: NWEndpoint.Port(rawValue: 8080)!
        )

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        let params = NWParameters(tls: nil, tcp: tcpOptions)

        let connection = NWConnection(to: endpoint, using: params)
        self.localConnection = connection

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isConnectedToMainApp = true
                print("[OpenCast] Ana sunucuya bağlandı.")
                let handshake = "POST /push HTTP/1.1\r\nHost: 127.0.0.1:8080\r\n\r\n"
                if let data = handshake.data(using: .utf8) {
                    connection.send(content: data, completion: .contentProcessed { _ in })
                }
            case .failed(let err):
                print("[OpenCast] Bağlantı hatası: \(err)")
                self?.isConnectedToMainApp = false
            case .cancelled:
                self?.isConnectedToMainApp = false
            default:
                break
            }
        }

        connection.start(queue: processingQueue)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            handleVideoBuffer(sampleBuffer)
        case .audioApp, .audioMic:
            break
        @unknown default:
            break
        }
    }

    private func handleVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastFrameTime >= frameInterval else { return }
        guard !isProcessingFrame else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        lastFrameTime = currentTime
        isProcessingFrame = true

        processingQueue.async { [weak self] in
            defer { self?.isProcessingFrame = false }
            guard let self = self else { return }

            if self.ciContext == nil {
                self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
            }
            guard let context = self.ciContext else { return }

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
            
            if let jpegData = context.jpegRepresentation(
                of: ciImage,
                colorSpace: colorSpace,
                options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.65]
            ) {
                self.sendFrameToMainApp(jpegData)
            }
        }
    }

    private func sendFrameToMainApp(_ jpegData: Data) {
        guard let connection = localConnection, isConnectedToMainApp else {
            return
        }

        var length = UInt32(jpegData.count).bigEndian
        var packet = Data(bytes: &length, count: 4)
        packet.append(jpegData)

        connection.send(content: packet, completion: .contentProcessed { _ in })
    }
}
