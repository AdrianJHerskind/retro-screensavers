import AppKit
import Metal
import ScreenSaver
import SceneKit

/// Hooks Mystify into the shared test harness. Extra command-line flags, for snapshots:
///
///     --lines 1...15   --line-width 1...4   --random-colors   --points-scale n (pixels per point, default 2)
///     --line-scale n   --spacing-scale n (thicker lines and wider-spaced copies, as for the thumbnail)
enum HarnessSaver: HarnessSupport {
    static let thumbnailMoment: (seconds: Double, seed: UInt64) = (7, 5)

    static func makeView(frame: NSRect) -> ScreenSaverView? {
        MystifySaverView(frame: frame, isPreview: false)
    }

    static func renderSnapshot(size: CGSize, seconds: Double, seed: UInt64) -> CGImage? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fputs("No Metal device available\n", stderr)
            return nil
        }

        var settings = MystifySettings()
        if let lines = argumentValue("--lines").flatMap(Int.init) {
            for index in settings.polygons.indices {
                settings.polygons[index].lines = lines.clamped(to: MystifyPolygonSettings.linesRange)
            }
        }
        if let lineWidth = argumentValue("--line-width").flatMap(Double.init) {
            settings.lineWidth = lineWidth.clamped(to: MystifySettings.lineWidthRange)
        }
        if CommandLine.arguments.contains("--random-colors") {
            for index in settings.polygons.indices {
                settings.polygons[index].colorMode = .random
            }
        }
        // Snapshots are in pixels; treat them as a Retina screen's points unless told otherwise.
        let pointsScale = argumentValue("--points-scale").flatMap(Double.init) ?? 2
        // The render is shrunk 8× for the System Settings tile, so draw thicker lines, further apart.
        let isThumbnail = argumentValue("--thumbnails") != nil
        let lineScale = argumentValue("--line-scale").flatMap(Double.init) ?? (isThumbnail ? 2.5 : 1)
        let spacingScale = argumentValue("--spacing-scale").flatMap(Double.init) ?? (isThumbnail ? 2.5 : 1)
        let viewSize = CGSize(width: size.width / pointsScale, height: size.height / pointsScale)

        let mystify = MystifyScene(settings: settings, viewSize: viewSize, seed: seed, lineScale: lineScale, spacingScale: spacingScale)
        let frameTime: Float = 1 / 60
        for _ in 0..<Int(seconds * 60) {
            mystify.step(by: frameTime)
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = mystify.scene
        renderer.pointOfView = mystify.cameraNode
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            .cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
