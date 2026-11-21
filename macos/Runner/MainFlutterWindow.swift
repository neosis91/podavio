import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let audioRegistrar = flutterViewController.registrar(forPlugin: "AudioDecodePlugin")
    AudioDecodePlugin.register(messenger: audioRegistrar.messenger)

    super.awakeFromNib()
  }
}
