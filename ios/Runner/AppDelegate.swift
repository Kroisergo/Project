import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let screenProtectionChannel = "encryvault/screen_protection"
  private var protectionEnabled = false
  private var blurView: UIVisualEffectView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: screenProtectionChannel,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "state", message: "AppDelegate unavailable", details: nil))
          return
        }
        switch call.method {
        case "enableProtection":
          self.protectionEnabled = true
          result(nil)
        case "disableProtection":
          self.protectionEnabled = false
          self.hideBlurOverlay()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func handleWillResignActive() {
    guard protectionEnabled else { return }
    showBlurOverlay()
  }

  @objc private func handleDidBecomeActive() {
    hideBlurOverlay()
  }

  private func showBlurOverlay() {
    guard let window else { return }
    if blurView == nil {
      let effect = UIBlurEffect(style: .systemMaterial)
      let view = UIVisualEffectView(effect: effect)
      view.frame = window.bounds
      view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      blurView = view
    }
    if let blurView, blurView.superview == nil {
      window.addSubview(blurView)
    }
  }

  private func hideBlurOverlay() {
    blurView?.removeFromSuperview()
  }
}
