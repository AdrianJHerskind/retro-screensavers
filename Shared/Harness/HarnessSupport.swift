import AppKit
import ScreenSaver

/// What the shared test harness needs from a screen saver. Each saver's `Harness` folder defines
/// a `HarnessSaver` type conforming to this. Saver-specific command-line flags can be read with
/// `argumentValue(_:)`.
protocol HarnessSupport {
    /// The view shown in the harness window.
    static func makeView(frame: NSRect) -> ScreenSaverView?
    /// Runs the saver headless for `seconds` and renders one frame, for `--snapshot` and `--thumbnails`.
    static func renderSnapshot(size: CGSize, seconds: Double, seed: UInt64) -> CGImage?
    /// When to capture the System Settings thumbnail: something representative, not an empty screen.
    static var thumbnailMoment: (seconds: Double, seed: UInt64) { get }
}

/// The value following `flag` on the command line, e.g. `--time 20`.
func argumentValue(_ flag: String) -> String? {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}
