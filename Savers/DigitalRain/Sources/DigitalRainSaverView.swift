import ScreenSaver
import SceneKit

/// The screen saver's principal class (NSPrincipalClass in Savers/DigitalRain/Info.plist). The
/// explicit Objective-C name must be unique across the collection, since System Settings can load
/// several savers into one process.
@objc(RetroDigitalRainSaverView)
final class DigitalRainSaverView: RetroScreenSaverView {
    private let sceneView: SCNView
    private let rain: DigitalRainScene
    private var options: DigitalRainOptions?

    override init?(frame: NSRect, isPreview: Bool) {
        sceneView = SCNView(frame: NSRect(origin: .zero, size: frame.size))
        // The preview in System Settings is small, so it shows fewer, bigger glyphs.
        rain = DigitalRainScene(settings: .load(), aspect: Self.aspect(of: frame.size), seed: .random(in: .min ... .max),
                                rowScale: isPreview ? 0.35 : 1)
        super.init(frame: frame, isPreview: isPreview)

        sceneView.autoresizingMask = [.width, .height]
        sceneView.backgroundColor = .black
        sceneView.antialiasingMode = .multisampling4X
        sceneView.scene = rain.scene
        sceneView.pointOfView = rain.cameraNode
        sceneView.delegate = rain
        addSubview(sceneView)
        // The rain moves in whole cell steps on a 30 Hz clock, so 30 fps shows every step.
        fullFrameRate = Int(DigitalRainScene.tickRate)
        frameRateDidChange()
        setAnimating(true)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func frameRateDidChange() {
        sceneView.preferredFramesPerSecond = frameRate
    }

    override func setAnimating(_ isAnimating: Bool) {
        sceneView.rendersContinuously = isAnimating
        sceneView.isPlaying = isAnimating
    }

    override func sizeDidSettle() {
        rain.restart(aspect: Self.aspect(of: bounds.size))
    }

    override func animateOneFrame() {
        // SceneKit drives its own render loop; see DigitalRainScene.renderer(_:updateAtTime:).
    }

    // MARK: - Options

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        let options = DigitalRainOptions(settings: .load()) { [weak self] settings in
            settings.save()
            self?.rain.restart(settings: settings)
        }
        self.options = options
        return options.sheet.window
    }

    private static func aspect(of size: NSSize) -> Float {
        size.height > 0 ? Float(size.width / size.height) : 1.6
    }
}
