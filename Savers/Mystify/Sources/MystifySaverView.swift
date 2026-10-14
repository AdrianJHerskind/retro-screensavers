import ScreenSaver
import SceneKit

/// The screen saver's principal class (NSPrincipalClass in Savers/Mystify/Info.plist). The
/// explicit Objective-C name must be unique across the collection, since System Settings can load
/// several savers into one process.
@objc(RetroMystifySaverView)
final class MystifySaverView: RetroScreenSaverView {
    private let sceneView: SCNView
    private let mystify: MystifyScene
    private var options: MystifyOptions?

    override init?(frame: NSRect, isPreview: Bool) {
        sceneView = SCNView(frame: NSRect(origin: .zero, size: frame.size))
        mystify = MystifyScene(settings: .load(), viewSize: frame.size, seed: .random(in: .min ... .max))
        super.init(frame: frame, isPreview: isPreview)

        sceneView.autoresizingMask = [.width, .height]
        sceneView.backgroundColor = .black
        sceneView.antialiasingMode = .multisampling4X
        sceneView.scene = mystify.scene
        sceneView.pointOfView = mystify.cameraNode
        sceneView.delegate = mystify
        addSubview(sceneView)
        // The lines glide continuously, so it stays at 60 fps unless the Mac is saving power.
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
        mystify.restart(viewSize: bounds.size)
    }

    override func animateOneFrame() {
        // SceneKit drives its own render loop; see MystifyScene.renderer(_:updateAtTime:).
    }

    // MARK: - Options

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        let options = MystifyOptions(settings: .load()) { [weak self] settings in
            settings.save()
            self?.mystify.restart(settings: settings)
        }
        self.options = options
        return options.sheet.window
    }
}
