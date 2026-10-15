import AppKit
import Metal
import ScreenSaver
import SceneKit

/// Hooks Digital Rain into the shared test harness. Extra command-line flags, for snapshots:
///
///     --characters mirroredKatakana|katakana|binary   --color Green|Cyan|Blue|Purple|Red|Amber|White
///     --glyph-size 0...1   --rows n   --density 0...1   --rain-speed 0.5...2
///     --egg-odds n (one stream in n spells out a word; 1 shows them everywhere)
enum HarnessSaver: HarnessSupport {
    static let thumbnailMoment: (seconds: Double, seed: UInt64) = (7, 12)

    static func makeView(frame: NSRect) -> ScreenSaverView? {
        DigitalRainSaverView(frame: frame, isPreview: false)
    }

    static func renderSnapshot(size: CGSize, seconds: Double, seed: UInt64) -> CGImage? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fputs("No Metal device available\n", stderr)
            return nil
        }

        var settings = DigitalRainSettings()
        if let characters = argumentValue("--characters") {
            settings.characters = RainCharacters.allCases.first { "\($0)" == characters } ?? settings.characters
        }
        if let color = argumentValue("--color") {
            settings.colorIndex = RainColor.all.firstIndex { $0.title == color } ?? settings.colorIndex
        }
        if let glyphSize = argumentValue("--glyph-size").flatMap(Double.init) {
            settings.glyphSize = glyphSize.clamped(to: DigitalRainSettings.glyphSizeRange)
        }
        if let density = argumentValue("--density").flatMap(Double.init) {
            settings.density = density.clamped(to: DigitalRainSettings.densityRange)
        }
        if let speed = argumentValue("--rain-speed").flatMap(Double.init) {
            settings.speed = speed.clamped(to: DigitalRainSettings.speedRange)
        }
        // The render is shrunk 8× for the System Settings tile, so use fewer, bigger glyphs.
        let rows = argumentValue("--rows").flatMap(Int.init) ?? (argumentValue("--thumbnails") != nil ? 14 : nil)

        let eggOdds = argumentValue("--egg-odds").flatMap(Int.init) ?? RainGrid.eggOdds
        let rain = DigitalRainScene(settings: settings, aspect: Float(size.width / size.height), seed: seed, rows: rows, eggOdds: eggOdds)
        let frameTime: Float = 1 / 60
        for _ in 0..<Int(seconds * 60) {
            rain.step(by: frameTime)
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = rain.scene
        renderer.pointOfView = rain.cameraNode
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            .cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
