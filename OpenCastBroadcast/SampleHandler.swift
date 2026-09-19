import ReplayKit
import CoreMedia
import CoreImage
import UIKit

class SampleHandler: RPBroadcastSampleHandler {

    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false, // GPU / Metal donanım hızlandırmasını kullan
        .priorityRequestLow: false
    ])
    
    // Akıllı TV tarayıcılarını yormamak ve stabil Full HD akış için saniyede 30 kare sınırı
    private var lastFrameTime: TimeInterval = 0
    private let frameInterval: TimeInterval = 1.0 / 30.0 
    
    // Bellek tasarrufu için eşzamanlı video işleme kuyruğu
    private let processingQueue = DispatchQueue(label: "com.opencast.video.processing", qos: .userInteractive)
    private var isProcessingFrame = false

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        print("[OpenCast] Ekran kaydı ve yayın başlatıldı.")
        StreamServer.shared.start(onPort: 8080)
    }

    override func broadcastPaused() {
        print("[OpenCast] Yayın duraklatıldı.")
    }

    override func broadcastResumed() {
        print("[OpenCast] Yayın devam ettirildi.")
    }

    override func broadcastFinished() {
        print("[OpenCast] Ekran kaydı bitti.")
        StreamServer.shared.stop()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            handleVideoBuffer(sampleBuffer)
        case .audioApp, .audioMic:
            // Gelecek aşamada ses aktarımı için genişletilebilir
            break
        @unknown default:
            break
        }
    }

    private func handleVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastFrameTime >= frameInterval else { return }
        
        guard !isProcessingFrame else { return } // Önceki kare bitmediyse atla (Lag önleyici)
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        lastFrameTime = currentTime
        isProcessingFrame = true

        processingQueue.async { [weak self] in
            defer { self?.isProcessingFrame = false }
            guard let self = self else { return }

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            // Full HD 1080p kalitesinde ve düşük dosya boyutunda JPEG sıkıştırması (%72 kalite)
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
            
            if let jpegData = self.ciContext.jpegRepresentation(
                of: ciImage,
                colorSpace: colorSpace,
                options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.72]
            ) {
                StreamServer.shared.sendFrame(jpegData)
            }
        }
    }
}
