import AppKit
import Metal
import ScreenSaver
import SceneKit

/// Hooks 3D Text into the shared test harness. Extra command-line flags, for snapshots:
///
///     --text "Hello"   --clock (show the time)   --font <index>
///     --rotation none|spin|seeSaw|wobble|tumble
///     --surface solid|chrome|marble|wood|granite   --color <index>
enum HarnessSaver: HarnessSupport {
    static let thumbnailMoment: (seconds: Double, seed: UInt64) = (2.5, 1)

    static func makeView(frame: NSRect) -> ScreenSaverView? {
        Text3DSaverView(frame: frame, isPreview: false)
    }

    static func renderSnapshot(size: CGSize, seconds: Double, seed: UInt64) -> CGImage? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fputs("No Metal device available\n", stderr)
            return nil
        }

        var settings = Text3DSettings()
        if argumentValue("--thumbnails") != nil {
            settings.text = "3D Text"
        }
        if let text = argumentValue("--text") {
            settings.text = text
        }
        if CommandLine.arguments.contains("--clock") {
            settings.content = .time
        }
        if let index = argumentValue("--font").flatMap(Int.init) {
            settings.fontIndex = index.clamped(to: 0...(TextFont.all.count - 1))
        }
        if let rotation = argumentValue("--rotation") {
            settings.rotation = RotationStyle.allCases.first { "\($0)" == rotation } ?? settings.rotation
        }
        if let surface = argumentValue("--surface") {
            settings.surface = TextSurface.allCases.first { "\($0)" == surface } ?? settings.surface
        }
        if let index = argumentValue("--color").flatMap(Int.init) {
            settings.colorIndex = index.clamped(to: 0...(TextColor.all.count - 1))
        }

        let text3D = Text3DScene(settings: settings, aspect: Float(size.width / size.height), seed: seed)
        let frameTime: Float = 1 / 60
        for _ in 0..<Int(seconds * 60) {
            text3D.step(by: frameTime)
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = text3D.scene
        renderer.pointOfView = text3D.cameraNode
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            .cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
