import AppKit
import Metal
import ScreenSaver
import SceneKit

/// Hooks Flower Box into the shared test harness. Extra command-line flags, for snapshots:
///
///     --shape cube|tetrahedron|pyramid|cylinder|spring
///     --object-size 0.2...0.8 (share of the screen height)
enum HarnessSaver: HarnessSupport {
    /// Petals and spikes at once, the most recognisable moment.
    static let thumbnailMoment: (seconds: Double, seed: UInt64) = (5.5, 3)

    static func makeView(frame: NSRect) -> ScreenSaverView? {
        FlowerBoxSaverView(frame: frame, isPreview: false)
    }

    static func renderSnapshot(size: CGSize, seconds: Double, seed: UInt64) -> CGImage? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fputs("No Metal device available\n", stderr)
            return nil
        }

        var settings = FlowerBoxSettings()
        if let shape = argumentValue("--shape") {
            settings.shape = FlowerBoxShape.allCases.first { "\($0)" == shape } ?? settings.shape
        }
        if argumentValue("--thumbnails") != nil {
            // Fill the small System Settings tile.
            settings.size = 0.8
        }
        if let objectSize = argumentValue("--object-size").flatMap(Double.init) {
            settings.size = objectSize.clamped(to: FlowerBoxSettings.sizeRange)
        }
        let flowerBox = FlowerBoxScene(settings: settings, aspect: Float(size.width / size.height), seed: seed)
        let frameTime: Float = 1 / 60
        for _ in 0..<Int(seconds * 60) {
            flowerBox.step(by: frameTime)
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = flowerBox.scene
        renderer.pointOfView = flowerBox.cameraNode
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            .cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
