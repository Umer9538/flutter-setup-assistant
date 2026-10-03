import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Comfortable default size for the step-by-step layout.
    let size = NSSize(width: 1160, height: 780)
    var frame = self.frame
    frame.size = size
    if let screen = NSScreen.main?.visibleFrame {
      frame.origin.x = screen.midX - size.width / 2
      frame.origin.y = screen.midY - size.height / 2
    }
    self.setFrame(frame, display: true)
    self.minSize = NSSize(width: 900, height: 620)
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    self.title = "Flutter Environment Setup Assistant"
  }
}
