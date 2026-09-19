import SwiftUI
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @StateObject private var discovery = DLNADiscovery.shared
    @State private var ipAddress: String = NetworkUtils.getWiFiAddress() ?? "Wi-Fi Yok"
    @State private var port: String = "8080"
    @State private var isConnectingDevice: String? = nil
    @State private var connectionMessage: String? = nil
    @State private var showBrowserFallback: Bool = false

    private var streamURLString: String {
        "http://\(ipAddress):\(port)/stream"
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.08)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        // Üst Bar
                        headerView

                        // 1. Canlı Yayın Başlatıcı (ReplayKit Butonu)
                        broadcastStarterCard

                        // 2. Ana Bölüm: Ağdaki TV'leri Otomatik Tarama ve Listeleme
                        deviceScannerSection

                        // 3. İpuçları (Vestel DLNA Ayarı)
                        tvSetupTipCard

                        // 4. İsteğe Bağlı: Tarayıcı Modu (Açılır/Kapanır)
                        browserFallbackSection

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                refreshAll()
            }
        }
    }

    // MARK: - Görünüm Parçaları

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "tv.badge.wifi")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.blue)
                    Text("OpenCast")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Text("Otomatik TV Keşfi & Tek Tıkla Yansıtma")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
            Spacer()

            Button(action: refreshAll) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
        }
    }

    private var broadcastStarterCard: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [Color.blue, Color(red: 0.1, green: 0.4, blue: 0.9)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 54)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)

                HStack(spacing: 10) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 22, weight: .bold))
                    Text("1. Önce Ekran Yayınını Açın")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)

                // ReplayKit Başlatıcı (Görünmez ama tıklanabilir)
                BroadcastPickerView()
                    .frame(maxWidth: .infinity, maxHeight: 54)
                    .opacity(0.015)
            }

            Text("Ekran yayını açıkken aşağıdaki televizyonunuza tek tıkla bağlanın")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
        }
    }

    private var deviceScannerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("AĞDAKİ TELEVİZYONLAR")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                    .tracking(1)

                Spacer()

                if discovery.isScanning {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        Text("Taranıyor...")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                } else {
                    Button("Tekrar Tara", action: { discovery.startScanning() })
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }

            if discovery.discoveredDevices.isEmpty {
                emptyDevicesView
            } else {
                VStack(spacing: 12) {
                    ForEach(discovery.discoveredDevices) { device in
                        deviceCard(for: device)
                    }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.11, green: 0.11, blue: 0.14)))
    }

    private func deviceCard(for device: DLNADevice) -> some View {
        let isVestel = device.name.lowercased().contains("vestel")
        let isConnecting = isConnectingDevice == device.id

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isVestel ? Color.blue.opacity(0.2) : Color.white.opacity(0.08))
                    .frame(width: 48, height: 48)

                Image(systemName: "tv.fill")
                    .font(.system(size: 22))
                    .foregroundColor(isVestel ? .blue : .white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(device.ipAddress)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: { castTo(device) }) {
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 80, height: 36)
                } else {
                    Text("Yansıt")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.blue))
                }
            }
            .disabled(isConnecting)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.35)))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isVestel ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }

    private var emptyDevicesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tv.slash")
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.top, 10)

            Text("Ağda Henüz TV Bulunamadı")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Text("Vestel TV'niz ile iPhone'un AYNI Wi-Fi ağına bağlı olduğundan emin olun.")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            Button(action: { discovery.startScanning() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Yeniden Ara")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.blue)
                .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var tvSetupTipCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Vestel TV İçin Önemli İpucu")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Televizyonun otomatik algılanması için kumandanızdan:\nMenü > Ayarlar > Diğer Ayarlar > DLNA / AVS seçeneğini 'Etkin' yapın.")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.yellow.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
    }

    private var browserFallbackSection: some View {
        VStack(spacing: 10) {
            Button(action: { withAnimation { showBrowserFallback.toggle() } }) {
                HStack {
                    Image(systemName: "safari")
                    Text("Alternatif: TV Tarayıcısı ile Bağlan")
                    Spacer()
                    Image(systemName: showBrowserFallback ? "chevron.up" : "chevron.down")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
            }

            if showBrowserFallback {
                VStack(spacing: 10) {
                    Text("TV Tarayıcısına şu adresi yazabilirsiniz:")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    Text("http://\(ipAddress):\(port)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.09, green: 0.09, blue: 0.11)))
            }
        }
    }

    // MARK: - Eylemler

    private func refreshAll() {
        if let newIP = NetworkUtils.getWiFiAddress() {
            ipAddress = newIP
        }
        discovery.startScanning()
    }

    private func castTo(_ device: DLNADevice) {
        isConnectingDevice = device.id
        DLNAController.shared.castToDevice(device, streamURL: streamURLString) { success in
            DispatchQueue.main.async {
                isConnectingDevice = nil
            }
        }
    }
}
