import Flutter
import UIKit
import FlyersGuard

/// Method-channel bridge over the prebuilt FlyersGuard iOS SDK. Holds no
/// detection logic of its own -- calls are delegated to the vendored binary
/// XCFramework.
public class FlyersGuardPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flyers_guard", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(FlyersGuardPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getJailbreakCheckReport":
      DispatchQueue.global(qos: .userInitiated).async {
        let report = FlyersGuard.jailbreakCheckReport()
        DispatchQueue.main.async { result(report) }
      }
    case "isDeviceCompromised":
      DispatchQueue.global(qos: .userInitiated).async {
        let compromised = FlyersGuard.isDeviceCompromised()
        DispatchQueue.main.async { result(compromised) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
