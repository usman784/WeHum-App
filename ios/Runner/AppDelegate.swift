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
