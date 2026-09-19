import SwiftUI
import ReplayKit

/// Apple'ın RPSystemBroadcastPickerView bileşenini tam tıklanabilir ve görünür şekilde SwiftUI'a aktarır.
struct BroadcastPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        picker.preferredExtension = "com.opencast.app.broadcast"
        picker.showsMicrophoneButton = false
        
        // Simge rengini beyaz yap
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.tintColor = .white
                button.imageView?.tintColor = .white
            }
        }
        
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
