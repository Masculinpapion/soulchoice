import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Bildirim tıklaması köprüsü (01.08): firebase_messaging'in tap iletimi,
  // delegate kurulumunu UIApplicationDidFinishLaunching bildirimine bağlar;
  // implicit-engine düzeninde bu zincir kopabiliyor (tıklama Dart'a hiç
  // ulaşmıyor — simülatörde ölçüldü, eşin iPhone vakası). Tıklamayı KENDİ
  // kanalımızla taşırız; Dart tarafı aynı olayı iki kaynaktan alırsa
  // rota-dedupe ile teke indirir.
  private var pushChannel: FlutterMethodChannel?
  private var launchPushJson: String?

  private static func pushJson(_ userInfo: [AnyHashable: Any]) -> String? {
    guard JSONSerialization.isValidJSONObject(userInfo),
          let data = try? JSONSerialization.data(withJSONObject: userInfo) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // APNs kaydı — firebase_messaging swizzling APNs token'ı FCM'e iletir,
    // böylece FirebaseMessaging.getToken() iOS'ta gerçek token üretir.
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    // Kapalıyken bildirime tıklanarak açıldıysa payload burada gelir;
    // Dart hazır olunca getLaunchPush ile çeker.
    if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      launchPushJson = Self.pushJson(remote)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Arka plandayken bildirime tıklama: sistemin tek güvenilir kancası.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    if let json = Self.pushJson(info) {
      if let ch = pushChannel {
        ch.invokeMethod("pushTapped", arguments: json)
      } else {
        launchPushJson = json // engine henüz yoksa açılışta teslim edilir
      }
    }
    completionHandler()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Bildirim temizliği + rozet (31.07): sohbet uygulama içinden okununca
    // teslim edilmiş bildirim kaldırılır (identifier = apns-collapse-id,
    // thread = aps thread-id — ikisi de "<tip>:<ref>" sözleşmesi).
    if let notifRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "SoulChoiceNotifications") {
      let notifChannel = FlutterMethodChannel(
        name: "com.soulchoice/notifications", binaryMessenger: notifRegistrar.messenger())
      pushChannel = notifChannel
      notifChannel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getLaunchPush":
          result(self?.launchPushJson)
          self?.launchPushJson = nil
        case "clearByKey":
          let key = call.arguments as? String ?? ""
          let center = UNUserNotificationCenter.current()
          center.getDeliveredNotifications { notes in
            let ids = notes.filter {
              $0.request.identifier == key || $0.request.content.threadIdentifier == key
            }.map { $0.request.identifier }
            if !ids.isEmpty { center.removeDeliveredNotifications(withIdentifiers: ids) }
          }
          result(nil)
        case "clearBadge":
          DispatchQueue.main.async { UIApplication.shared.applicationIconBadgeNumber = 0 }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SoulChoiceUploader") else { return }
    let channel = FlutterMethodChannel(name: "com.soulchoice/uploader", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "uploadBytes" else { result(FlutterMethodNotImplemented); return }
      guard
        let args = call.arguments as? [String: Any],
        let url = args["url"] as? String,
        let accessToken = args["accessToken"] as? String,
        let apiKey = args["apiKey"] as? String,
        let bytes = args["bytes"] as? FlutterStandardTypedData,
        let contentType = args["contentType"] as? String
      else { result(FlutterError(code: "BAD_ARGS", message: "Missing arguments", details: nil)); return }

      DispatchQueue.global(qos: .userInitiated).async {
        do {
          var uploadData = bytes.data
          var uploadCT = contentType
          // 31.07: yalnız PNG sıkıştırılıyordu; iki çağıran da JPEG etiketi
          // gönderdiği için iOS'ta HİÇBİR görsel sıkışmıyordu (crop çıktısı
          // 1-3 MB ham gidiyordu). Android tarafı tüm image/* için q82'ye
          // normalize ediyor — parite sağlandı.
          if contentType.hasPrefix("image/"), let img = UIImage(data: uploadData),
             let jpeg = img.jpegData(compressionQuality: 0.82) {
            uploadData = jpeg
            uploadCT = "image/jpeg"
          }
          try Self.tusUpload(storageUrl: url, accessToken: accessToken, apiKey: apiKey,
                             data: uploadData, contentType: uploadCT)
          DispatchQueue.main.async { result(200) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  private static func b64(_ s: String) -> String {
    Data(s.utf8).base64EncodedString()
  }

  private static func tusUpload(storageUrl: String, accessToken: String, apiKey: String,
                                 data: Data, contentType: String) throws {
    guard let uri = URLComponents(string: storageUrl),
          let host = uri.host, let scheme = uri.scheme else {
      throw NSError(domain: "Uploader", code: 0, userInfo: [NSLocalizedDescriptionKey: "Bad URL"])
    }
    let base = "\(scheme)://\(host)"
    let path = uri.path.replacingOccurrences(of: "/storage/v1/object/", with: "")
    let slash = path.firstIndex(of: "/")!
    let bucket = String(path[path.startIndex..<slash])
    let objPath = String(path[path.index(after: slash)...])

    let metadata = "bucketName \(b64(bucket)),objectName \(b64(objPath))," +
                   "contentType \(b64(contentType)),cacheControl \(b64("max-age=3600"))"

    // Step 1: TUS create
    var createReq = URLRequest(url: URL(string: "\(base)/storage/v1/upload/resumable")!)
    createReq.httpMethod = "POST"
    createReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    createReq.setValue(apiKey, forHTTPHeaderField: "apikey")
    createReq.setValue("1.0.0", forHTTPHeaderField: "Tus-Resumable")
    createReq.setValue("\(data.count)", forHTTPHeaderField: "Upload-Length")
    createReq.setValue(metadata, forHTTPHeaderField: "Upload-Metadata")
    createReq.setValue("true", forHTTPHeaderField: "x-upsert")
    createReq.setValue("0", forHTTPHeaderField: "Content-Length")

    let sem1 = DispatchSemaphore(value: 0)
    var location: String?
    var createCode = 0
    URLSession.shared.dataTask(with: createReq) { _, resp, _ in
      if let h = resp as? HTTPURLResponse {
        createCode = h.statusCode
        location = h.value(forHTTPHeaderField: "Location")
      }
      sem1.signal()
    }.resume()
    sem1.wait()

    guard createCode == 201, let loc = location else {
      throw NSError(domain: "Uploader", code: createCode,
                    userInfo: [NSLocalizedDescriptionKey: "TUS create failed: HTTP \(createCode)"])
    }

    let uploadUrl = loc.hasPrefix("http") ? URL(string: loc)! : URL(string: "\(base)\(loc)")!

    // Step 2: PATCH in 64KB chunks
    let chunk = 65536
    var offset = 0
    while offset < data.count {
      let chunkLen = min(chunk, data.count - offset)
      let chunkData = data.subdata(in: offset..<(offset + chunkLen))

      var patchReq = URLRequest(url: uploadUrl)
      patchReq.httpMethod = "PATCH"
      patchReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      patchReq.setValue(apiKey, forHTTPHeaderField: "apikey")
      patchReq.setValue("1.0.0", forHTTPHeaderField: "Tus-Resumable")
      patchReq.setValue("\(offset)", forHTTPHeaderField: "Upload-Offset")
      patchReq.setValue("application/offset+octet-stream", forHTTPHeaderField: "Content-Type")
      patchReq.httpBody = chunkData

      let sem2 = DispatchSemaphore(value: 0)
      var patchCode = 0
      URLSession.shared.dataTask(with: patchReq) { _, resp, _ in
        if let h = resp as? HTTPURLResponse { patchCode = h.statusCode }
        sem2.signal()
      }.resume()
      sem2.wait()

      guard patchCode == 204 else {
        throw NSError(domain: "Uploader", code: patchCode,
                      userInfo: [NSLocalizedDescriptionKey: "TUS PATCH failed at offset=\(offset): HTTP \(patchCode)"])
      }
      offset += chunkLen
    }
  }
}
