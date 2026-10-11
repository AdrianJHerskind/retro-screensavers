import AppKit
import Metal
import ScreenSaver
import SceneKit

/// Hooks Pipes into the shared test harness. Extra command-line flags:
///
///     --joints elbow|ball|mixed     --surface solid|marble|wood|granite|mixedTextures
///     --teapot-chance 0...1         --dissolve 0...1 (snapshots only: the wipe part-way through)
enum HarnessSaver: HarnessSupport {
    static let thumbnailMoment: (seconds: Double, seed: UInt64) = (45, 9)

    static func makeView(frame: NSRect) -> ScreenSaverView? {
        let view = PipesSaverView(frame: frame, isPreview: false)
        if let chance = argumentValue("--teapot-chance").flatMap(Float.init) {
            view?.teapotChance = chance
        }
        return view
    }

    static func renderSnapshot(size: CGSize, seconds: Double, seed: UInt64) -> CGImage? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fputs("No Metal device available\n", stderr)
            return nil
        }

        var settings = PipesSettings()
        if let joints = argumentValue("--joints") {
            settings.jointStyle = JointStyle.allCases.first { "\($0)" == joints } ?? settings.jointStyle
        }
        if let surface = argumentValue("--surface") {
            settings.surface = Surface.allCases.first { "\($0)" == surface } ?? settings.surface
        }
        let pipes = PipesScene(settings: settings, aspect: Float(size.width / size.height), seed: seed)
        if let chance = argumentValue("--teapot-chance").flatMap(Float.init) {
            pipes.teapotChance = chance
        }
        let frameTime: Float = 1 / 60
        for _ in 0..<Int(seconds * 60) {
            pipes.step(by: frameTime)
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = pipes.scene
        renderer.pointOfView = pipes.cameraNode
        if let dissolve = argumentValue("--dissolve").flatMap(Double.init) {
            pipes.overlay.size = size
            pipes.overlay.progress = dissolve
            renderer.overlaySKScene = pipes.overlay
        }
        print("After \(seconds)s: \(pipes.statusLine)")
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            .cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
