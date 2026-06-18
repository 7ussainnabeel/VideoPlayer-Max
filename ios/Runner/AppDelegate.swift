import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  static var shared: AppDelegate?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    AppDelegate.shared = self
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    if let controller = window?.rootViewController as? FlutterViewController {
      let converterChannel = FlutterMethodChannel(name: "com.videoplayermax.media/converter",
                                                binaryMessenger: controller.binaryMessenger)
      converterChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "extractAudio" {
          guard let args = call.arguments as? [String: Any],
                let inputPath = args["inputPath"] as? String,
                let outputPath = args["outputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
          }
          self?.extractAudio(inputPath: inputPath, outputPath: outputPath, result: result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }
    
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func extractAudio(inputPath: String, outputPath: String, result: @escaping FlutterResult) {
    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    
    // Delete existing output file if any
    try? FileManager.default.removeItem(at: outputURL)
    
    let asset = AVAsset(url: inputURL)
    
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
      result(FlutterError(code: "EXPORT_SESSION_CREATION_FAILED", message: "Failed to create AVAssetExportSession", details: nil))
      return
    }
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a
    exportSession.shouldOptimizeForNetworkUse = true
    
    exportSession.exportAsynchronously {
      DispatchQueue.main.async {
        switch exportSession.status {
        case .completed:
          result(outputPath)
        case .failed:
          let errorMsg = exportSession.error?.localizedDescription ?? "Unknown export error"
          result(FlutterError(code: "EXPORT_FAILED", message: errorMsg, details: nil))
        case .cancelled:
          result(FlutterError(code: "EXPORT_CANCELLED", message: "Export cancelled", details: nil))
        default:
          result(FlutterError(code: "EXPORT_UNKNOWN", message: "Export status: \(exportSession.status.rawValue)", details: nil))
        }
      }
    }
  }
}
