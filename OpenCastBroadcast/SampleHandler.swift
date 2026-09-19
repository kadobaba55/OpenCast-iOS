import ReplayKit
import CoreMedia
import CoreImage
import UIKit
import Network

@objc(SampleHandler)
public class SampleHandler: RPBroadcastSampleHandler {

    private lazy var ciContext: CIContext = {
        CIContext(options: [
            .useSoftwareRenderer: false,
            .priorityRequestLow: false
        ])
    }()
    
    private var lastFrameTime: TimeInterval = 0
    private let frameInterval: TimeInterval = 1.0 / 30.0 
    
    private let processingQueue = DispatchQueue(label: "com.opencast.video.processing", qos: .userInteractive)
    private var isProcessingFrame = false

    // Ana uygulamadaki StreamServer'a (127.0.0.1:8080) canlı kare aktaran yerel soket
    private var localConnection: NWConnection?
    private var isConnectedToMainApp = false

    public override init() {
        super.init()
    }

    public override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        print("[OpenCast] Ekran kaydı ve yayın başladı.")
        connectToMainAppServer()
    }

    public override func broadcastPaused() {
        print("[OpenCast] Yayın duraklatıldı.")
    }

    public override func broadcastResumed() {
        print("[OpenCast] Yayın devam ettirildi.")
    }

    public override func broadcastFinished() {
        print("[OpenCast] Ekran kaydı bitti.")
        localConnection?.cancel()
        localConnection = nil
        isConnectedToMainApp = false
    }

    private func connectToMainAppServer() {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("127.0.0.1"),
            port: NWEndpoint.Port(rawValue: 8080)!
        )

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        let params = NWParameters(tls: nil, tcp: tcpOptions)

        localConnection = NWConnection(to: endpoint, using: params)
        localConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isConnectedToMainApp = true
                print("[OpenCast] Ana uygulamaya yerel olarak bağlandı.")
                // El sıkışma isteği gönder
                let handshake = "POST /push HTTP/1.1\r\nHost: 127.0.0.1:8080\r\n\r\n"
                if let data = handshake.data(using: .utf8) {
                    self?.localConnection?.send(content: data, completion: .contentProcessed { _ in })
                }
            case .failed(let err):
                print("[OpenCast] Ana uygulamaya bağlanamadı: \(err)")
                self?.isConnectedToMainApp = false
            case .cancelled:
                self?.isConnectedToMainApp = false
            default:
                break
            }
        }

        localConnection?.start(queue: processingQueue)
    }

    public override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
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

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
            
            // Full HD kalitesinde (%70) GPU JPEG sıkıştırması
            if let jpegData = self.ciContext.jpegRepresentation(
                of: ciImage,
                colorSpace: colorSpace,
                options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.70]
            ) {
                self.sendFrameToMainApp(jpegData)
            }
        }
    }

    private func sendFrameToMainApp(_ jpegData: Data) {
        guard let connection = localConnection, isConnectedToMainApp else {
            // Eğer bağlantı koptuysa yeniden bağlanmayı dene
            connectToMainAppServer()
            return
        }

        // [4 Bayt BigEndian Uzunluk] + [JPEG Verisi]
        var length = UInt32(jpegData.count).bigEndian
        var packet = Data(bytes: &length, count: 4)
        packet.append(jpegData)

        connection.send(content: packet, completion: .contentProcessed { error in
            if error != nil {
                print("[OpenCast] Kare gönderme hatası: \(String(describing: error))")
            }
        })
    }
}
