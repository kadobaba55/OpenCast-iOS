import SwiftUI

struct ContentView: View {
    @StateObject private var discovery = DLNADiscovery.shared
    @State private var ipAddress: String = NetworkUtils.getWiFiAddress() ?? "Wi-Fi Yok"
    @State private var port: String = "8080"
    @State private var isConnectingDevice: String? = nil
    @State private var manualIP: String = ""
    @State private var showManualSheet: Bool = false
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
                    VStack(spacing: 20) {
                        // Üst Bar
                        headerView

                        // 1. Ekran Yayını Başlatıcı Buton
                        broadcastStarterCard

                        // 2. Ağdaki TV'ler Listesi
                        deviceScannerSection

                        // 3. Manuel TV IP Ekleme Kartı (Hızlı Çözüm)
                        manualIPCard

                        // 4. Vestel ve Ağ Ayar Kontrol Listesi
                        troubleshootCard

                        // 5. İsteğe Bağlı: Tarayıcı Modu
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

    // MARK: - Bileşenler

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
                Text("IP: \(ipAddress)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
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
            HStack(spacing: 16) {
                // Apple'ın resmi ve doğrudan tıklanabilir yayın başlatıcı butonu
                BroadcastPickerView()
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color.blue))
                    .shadow(color: Color.blue.opacity(0.4), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text("1. Ekran Yayınını Başlat")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Soldaki butona dokunun ve 'Yayını Başlat'ı seçin")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.12, green: 0.12, blue: 0.16)))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )

            Text("İpucu: iPhone Denetim Merkezi'nden 'Ekran Kaydı'na basılı tutarak da OpenCast'i seçebilirsiniz.")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var deviceScannerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("BULUNAN TELEVİZYONLAR")
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
                    Button("Yeniden Tara", action: { discovery.startScanning() })
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
        let isConnecting = isConnectingDevice == device.id

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: "tv.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(device.ipAddress)
                    .font(.system(size: 12, design: .monospaced))
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
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.4)))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private var emptyDevicesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tv.slash")
                .font(.system(size: 34))
                .foregroundColor(.gray.opacity(0.4))
                .padding(.top, 8)

            Text("Ağda Otomatik TV Bulunamadı")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text("Modeminizin Wi-Fi izolasyonu taramayı engelliyor olabilir. Aşağıdan TV IP'nizi yazarak doğrudan bağlanabilirsiniz.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private var manualIPCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "keyboard")
                    .foregroundColor(.blue)
                Text("TV'nin IP Adresiyle Doğrudan Bağlan")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Vestel Kumandası: Menü > Ayarlar > Ağ Ayarları kısmındaki IP'yi yazın:")
                .font(.system(size: 11))
                .foregroundColor(.gray)

            HStack {
                TextField("Örn: 192.168.1.35", text: $manualIP)
                    .keyboardType(.numbersAndPunctuation)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                    .foregroundColor(.white)
                    .font(.system(size: 14, design: .monospaced))

                Button(action: addManualIP) {
                    Text("Ekle & Bağlan")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.10, green: 0.10, blue: 0.13)))
    }

    private var troubleshootCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("Cihaz Bulunamazsa Bu 2 Ayarı Kontrol Edin")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("1. iPhone: Ayarlar > OpenCast > 'Yerel Ağ' izni AÇIK olmalı.\n2. Vestel: Menü > Ayarlar > Diğer Ayarlar > DLNA/AVS seçeneği 'Etkin' olmalı.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.yellow.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.18), lineWidth: 1))
    }

    private var browserFallbackSection: some View {
        VStack(spacing: 10) {
            Button(action: { withAnimation { showBrowserFallback.toggle() } }) {
                HStack {
                    Image(systemName: "safari")
                    Text("Yedek Yöntem: TV Tarayıcısı")
                    Spacer()
                    Image(systemName: showBrowserFallback ? "chevron.up" : "chevron.down")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
            }

            if showBrowserFallback {
                VStack(spacing: 8) {
                    Text("TV Tarayıcısına şu adresi yazabilirsiniz:")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)

                    Text("http://\(ipAddress):\(port)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.5)))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.09, green: 0.09, blue: 0.11)))
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

    private func addManualIP() {
        let clean = manualIP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        discovery.addManualDevice(ip: clean)
        manualIP = ""
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
