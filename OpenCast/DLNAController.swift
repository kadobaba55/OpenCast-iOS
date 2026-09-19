import Foundation

/// TV'ye (Vestel vb.) doğrudan "Bu yayını aç ve oynat" komutu gönderen UPnP/DLNA kontrolcüsü.
/// Bu sayede televizyonda tarayıcı açmaya ve adres yazmaya gerek kalmaz.
public class DLNAController {
    public static let shared = DLNAController()

    private init() {}

    public func castToDevice(_ device: DLNADevice, streamURL: String, completion: @escaping (Bool) -> Void) {
        guard let controlURL = device.controlURL else {
            completion(false)
            return
        }

        // 1. Adım: TV'ye yayın adresini ayarla (SetAVTransportURI)
        setAVTransportURI(controlURL: controlURL, streamURL: streamURL) { [weak self] success in
            if success {
                // 2. Adım: TV'ye oynat komutu gönder (Play)
                self?.play(controlURL: controlURL, completion: completion)
            } else {
                completion(false)
            }
        }
    }

    private func setAVTransportURI(controlURL: URL, streamURL: String, completion: @escaping (Bool) -> Void) {
        let soapEnvelope = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
              <CurrentURI>\(streamURL)</CurrentURI>
              <CurrentURIMetaData></CurrentURIMetaData>
            </u:SetAVTransportURI>
          </s:Body>
        </s:Envelope>
        """

        sendSOAP(controlURL: controlURL, action: "SetAVTransportURI", body: soapEnvelope, completion: completion)
    }

    private func play(controlURL: URL, completion: @escaping (Bool) -> Void) {
        let soapEnvelope = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
              <Speed>1</Speed>
            </u:Play>
          </s:Body>
        </s:Envelope>
        """

        sendSOAP(controlURL: controlURL, action: "Play", body: soapEnvelope, completion: completion)
    }

    private func sendSOAP(controlURL: URL, action: String, body: String, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: controlURL)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"urn:schemas-upnp-org:service:AVTransport:1#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = 6.0

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
}
