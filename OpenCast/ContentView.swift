import SwiftUI
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @State private var ipAddress: String = NetworkUtils.getWiFiAddress() ?? "Wi-Fi Bağlantısı Yok"
    @State private var port: String = "8080"
    @State private var isCopied: Bool = false
    
    private var streamURLString: String {
        if ipAddress.contains(".") {
            return "http://\(ipAddress):\(port)"
        }
        return "Wi-Fi'a bağlanın"
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Üst Başlık & Logo
                        headerView

                        // TV Bağlantı Kartı (URL + QR Kod)
                        tvConnectionCard

                        // Yayını Başlat Butonu Alanı
                        broadcastSection

                        // Adım Adım Talimatlar
                        instructionsCard

                        // Uyumlu Cihaz Rozetleri
                        compatibleDevicesView

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Bileşenler

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "tv.badge.wifi")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.blue)
                    Text("OpenCast")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Text("Evrensel & Reklamsız TV Ekran Yansıtıcı")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
            Spacer()
            
            Button(action: refreshIP) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
        }
    }

    private var tvConnectionCard: some View {
        VStack(spacing: 16) {
            Text("TELEVİZYONUNUZDAN BU ADRESE GİRİN")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.blue)
                .tracking(1)

            // URL Kutusu
            HStack {
                Text(streamURLString)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Button(action: copyToClipboard) {
                    Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 18))
                        .foregroundColor(isCopied ? .green : .white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.5)))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            // QR Kod (Mobil ve tabletler için)
            if let qrImage = generateQRCode(from: streamURLString) {
                VStack(spacing: 8) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(12)

                    Text("Kamerayla veya başka cihazla taratabilirsiniz")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
    }

    private var broadcastSection: some View {
        VStack(spacing: 12) {
            Text("YAYINI BAŞLATIN")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue)
                    .frame(height: 56)

                HStack(spacing: 12) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 20, weight: .bold))
                    Text("Ekran Yansıtmayı Başlat")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)

                // Apple'ın yerleşik başlatıcı butonunu üzerine tam oturtuyoruz
                BroadcastPickerView()
                    .frame(maxWidth: .infinity, maxHeight: 56)
                    .opacity(0.015) // Görünmez ama tıklanabilir
            }
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nasıl Kullanılır?")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            instructionRow(step: "1", title: "Aynı Wi-Fi Ağı", desc: "iPhone 13 ve Vestel televizyonunuzun aynı Wi-Fi'a bağlı olduğundan emin olun.")
            instructionRow(step: "2", title: "TV'den Tarayıcıyı Açın", desc: "Vestel kumandasından İnternet/Web Tarayıcısını açıp yukarıdaki adresi yazın.")
            instructionRow(step: "3", title: "Yayını Başlatın", desc: "Yukarıdaki butona basıp 'Yayını Başlat'ı seçin. Ekranınız TV'ye akacaktır.")
            instructionRow(step: "4", title: "Tam Ekran Yapın", desc: "Vestel kumandasından OK (Enter) tuşuna basarak görüntüyü tam ekran yapın.")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.13))
        )
    }

    private func instructionRow(step: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(step)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineSpacing(2)
            }
        }
    }

    private var compatibleDevicesView: some View {
        VStack(spacing: 8) {
            Text("TÜM CİHAZLARLA EVRENSEL UYUMLU")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray.opacity(0.8))

            HStack(spacing: 8) {
                badge(text: "Vestel TV")
                badge(text: "LG webOS")
                badge(text: "Samsung")
                badge(text: "Android TV")
                badge(text: "PC / Mac")
            }
        }
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    // MARK: - Yardımcı Fonksiyonlar

    private func refreshIP() {
        if let newIP = NetworkUtils.getWiFiAddress() {
            ipAddress = newIP
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = streamURLString
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 8, y: 8)
            let scaledImage = outputImage.transformed(by: transform)
            let context = CIContext()
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
}
