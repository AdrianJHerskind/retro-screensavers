import AppKit
import Metal
import ScreenSaver
import SceneKit

/// Hooks Flying Objects into the shared test harness. Extra command-line flags, for snapshots:
///
///     --style flag|explode|ribbon|twoRibbons|splash|twist
///     --design sunset|checkered|marble|wood|granite
///     --resolution 0...1   --object-size 0.2...0.8   --flat   --cycle
enum HarnessSaver: HarnessSupport {
    static let thumbnailMoment: (seconds: Double, seed: UInt64) = (0.4, 9)

    static func makeView(frame: NSRect) -> ScreenSaverView? {
        FlyingObjectsSaverView(frame: frame, isPreview: false)
    }

    static func renderSnapshot(size: CGSize, seconds: Double, seed: UInt64) -> CGImage? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fputs("No Metal device available\n", stderr)
            return nil
        }

        var settings = FlyingObjectsSettings()
        if let style = argumentValue("--style") {
            settings.style = FlyingStyle.allCases.first { "\($0)" == style } ?? settings.style
        }
        if let design = argumentValue("--design") {
            settings.flagDesign = FlagDesign.allCases.first { "\($0)" == design } ?? settings.flagDesign
        }
        if let resolution = argumentValue("--resolution").flatMap(Double.init) {
            settings.resolution = resolution.clamped(to: FlyingObjectsSettings.resolutionRange)
        }
        if argumentValue("--thumbnails") != nil {
            // Fill the small System Settings tile.
            settings.size = 0.75
        }
        if let objectSize = argumentValue("--object-size").flatMap(Double.init) {
            settings.size = objectSize.clamped(to: FlyingObjectsSettings.sizeRange)
        }
        settings.smoothShading = !CommandLine.arguments.contains("--flat")
        settings.cyclesColors = CommandLine.arguments.contains("--cycle")

        let flyingObjects = FlyingObjectsScene(settings: settings, aspect: Float(size.width / size.height), seed: seed)
        let frameTime: Float = 1 / 60
        for _ in 0..<Int(seconds * 60) {
            flyingObjects.step(by: frameTime)
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = flyingObjects.scene
        renderer.pointOfView = flyingObjects.cameraNode
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            .cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
