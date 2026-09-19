import SwiftUI
import ReplayKit

/// Apple'ın RPSystemBroadcastPickerView bileşenini SwiftUI içinde kullanılabilir hale getirir.
/// Bu sayede kullanıcı Denetim Merkezi'ni aramadan tek tıkla doğrudan uygulama içinden yayını başlatabilir.
struct BroadcastPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        picker.preferredExtension = "com.opencast.app.broadcast"
        picker.showsMicrophoneButton = false
        
        // Buton içindeki simgeyi belirgin ve şık yapmak için
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.tintColor = .systemBlue
            }
        }
        
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
