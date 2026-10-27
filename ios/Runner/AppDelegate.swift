import Flutter
import UIKit
import DeviceCheck
import CryptoKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Instagram "Share to Stories": the PNG goes on the pasteboard, then Instagram opens its story composer with it.
    // No Instagram login: the person is signed in to Instagram already; `source_application` is our Meta App ID.
    let share = FlutterMethodChannel(name: "app.wehum/share", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    share.setMethodCallHandler { call, result in
      let base = URL(string: "instagram-stories://share")!
      switch call.method {
      case "instagramAvailable":
        result(UIApplication.shared.canOpenURL(base))
      case "instagramStory":
        guard let args = call.arguments as? [String: Any], let path = args["path"] as? String, let appId = args["appId"] as? String,
              let png = FileManager.default.contents(atPath: path),
              let url = URL(string: "instagram-stories://share?source_application=\(appId)") else {
          return result(FlutterError(code: "bad_args", message: "path/appId missing", details: nil))
        }
        guard UIApplication.shared.canOpenURL(base) else { return result(false) }
        UIPasteboard.general.setItems([["com.instagram.sharedSticker.backgroundImage": png]],
                                      options: [.expirationDate: Date().addingTimeInterval(5 * 60)])
        UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    // App Attest: the attestation is bound to the server's one-time challenge (clientDataHash = SHA-256(challenge)).
    let channel = FlutterMethodChannel(name: "app.wehum/attest", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "attest", let args = call.arguments as? [String: Any], let challenge = args["challenge"] as? String else {
        return result(FlutterMethodNotImplemented)
      }
      let service = DCAppAttestService.shared
      guard service.isSupported else { return result(FlutterError(code: "unsupported", message: "App Attest not supported", details: nil)) }
      service.generateKey { keyId, error in
        guard let keyId = keyId else { return result(FlutterError(code: "key_failed", message: error?.localizedDescription, details: nil)) }
        let hash = Data(SHA256.hash(data: Data(challenge.utf8)))
        service.attestKey(keyId, clientDataHash: hash) { object, error in
          guard let object = object else { return result(FlutterError(code: "attest_failed", message: error?.localizedDescription, details: nil)) }
          result(["keyId": keyId, "object": object.base64EncodedString()])
        }
      }
    }
  }
}
