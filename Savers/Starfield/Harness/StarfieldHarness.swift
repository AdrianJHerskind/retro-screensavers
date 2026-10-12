import AppKit
import Metal
import ScreenSaver
import SceneKit

/// Hooks Starfield into the shared test harness. Extra command-line flags, for snapshots:
///
///     --warp 0.2...4   --stars 200...4000
enum HarnessSaver: HarnessSupport {
    static let thumbnailMoment: (seconds: Double, seed: UInt64) = (3, 2)

    static func makeView(frame: NSRect) -> ScreenSaverView? {
        StarfieldSaverView(frame: frame, isPreview: false)
    }

    static func renderSnapshot(size: CGSize, seconds: Double, seed: UInt64) -> CGImage? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fputs("No Metal device available\n", stderr)
            return nil
        }

        var settings = StarfieldSettings()
        // The render is shrunk about 8× for the System Settings tile, so draw fewer, bigger stars.
        let isThumbnail = argumentValue("--thumbnails") != nil
        if isThumbnail {
            settings.density = 600
        }
        if let warp = argumentValue("--warp").flatMap(Double.init) {
            settings.warpSpeed = warp.clamped(to: StarfieldSettings.warpSpeedRange)
        }
        if let stars = argumentValue("--stars").flatMap(Int.init) {
            settings.density = stars.clamped(to: StarfieldSettings.densityRange)
        }
        let starfield = StarfieldScene(settings: settings, aspect: Float(size.width / size.height), seed: seed, starScale: isThumbnail ? 5 : 1)
        let frameTime: Float = 1 / 60
        for _ in 0..<Int(seconds * 60) {
            starfield.step(by: frameTime)
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = starfield.scene
        renderer.pointOfView = starfield.cameraNode
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            .cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
