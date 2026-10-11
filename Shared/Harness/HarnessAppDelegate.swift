import AppKit
import ScreenSaver

/// Hosts a saver's view in an ordinary window, so it can be run and debugged from Xcode
/// without installing it.
final class HarnessAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var saverView: ScreenSaverView!

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ProcessInfo.processInfo.processName
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        let frame = NSRect(x: 0, y: 0, width: 1280, height: 800)
        window = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = appName
        window.collectionBehavior = .fullScreenPrimary
        saverView = HarnessSaver.makeView(frame: frame)
        window.contentView = saverView
        window.center()
        window.makeKeyAndOrderFront(nil)
        saverView.startAnimation()
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func showOptions(_ sender: Any?) {
        guard window.attachedSheet == nil, saverView.hasConfigureSheet, let sheet = saverView.configureSheet else { return }
        window.beginSheet(sheet)
    }

    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Options…", action: #selector(showOptions), keyEquivalent: ",").target = self
        appMenu.addItem(withTitle: "Toggle Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
            .keyEquivalentModifierMask = [.control, .command]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appItem)
        return mainMenu
    }
}
