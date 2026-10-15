import Foundation
import ScreenSaver

/// Which glyphs rain down.
enum RainCharacters: Int, CaseIterable {
    /// Half-width katakana, digits and a few Latin letters and symbols, mirrored, as in the film.
    case mirroredKatakana
    /// The same, the right way round.
    case katakana
    /// Zeros and ones.
    case binary

    var title: String {
        switch self {
        case .mirroredKatakana: return "Mirrored katakana"
        case .katakana: return "Katakana"
        case .binary: return "Binary"
        }
    }

    var glyphs: String {
        switch self {
        case .mirroredKatakana, .katakana:
            return "ｦｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789Z:.=*+-<>|"
        case .binary:
            return "01"
        }
    }

    var isMirrored: Bool { self == .mirroredKatakana }
}

/// The rain's color. The leading glyph of each stream is always nearly white.
struct RainColor {
    let title: String
    /// sRGB components.
    let rgb: SIMD3<Double>

    static let all = [
        RainColor(title: "Green", rgb: [0.1, 1, 0.3]),
        RainColor(title: "Cyan", rgb: [0.1, 0.85, 1]),
        RainColor(title: "Blue", rgb: [0.25, 0.45, 1]),
        RainColor(title: "Purple", rgb: [0.65, 0.35, 1]),
        RainColor(title: "Red", rgb: [1, 0.2, 0.15]),
        RainColor(title: "Amber", rgb: [1, 0.65, 0.1]),
        RainColor(title: "White", rgb: [0.9, 0.9, 0.9]),
    ]
}

struct DigitalRainSettings: Equatable {
    var characters = RainCharacters.mirroredKatakana
    /// Index into `RainColor.all`.
    var colorIndex = 0
    /// 0 is small glyphs (many rows), 1 is large ones.
    var glyphSize = 0.5
    /// 0 is a few streams with long gaps, 1 is streams almost everywhere.
    var density = 0.5
    /// Multiplies how fast the streams fall.
    var speed = 1.0

    static let glyphSizeRange = 0.0...1.0
    static let densityRange = 0.0...1.0
    static let speedRange = 0.5...2.0

    /// Rows of glyphs on screen, from the glyph size.
    var rows: Int {
        Int((80 - 56 * glyphSize.clamped(to: Self.glyphSizeRange)).rounded())
    }

    var color: RainColor { RainColor.all[colorIndex.clamped(to: 0...(RainColor.all.count - 1))] }

    /// Settings are stored per bundle identifier, which project.yml derives from BUNDLE_ID_PREFIX.
    private static let moduleName = Bundle(for: DigitalRainSaverView.self).bundleIdentifier ?? "RetroDigitalRain"

    private enum Key {
        static let characters = "characters"
        static let color = "color"
        static let glyphSize = "glyphSize"
        static let density = "density"
        static let speed = "speed"
    }

    private static var defaults: UserDefaults? {
        ScreenSaverDefaults(forModuleWithName: moduleName)
    }

    static func load() -> DigitalRainSettings {
        var settings = DigitalRainSettings()
        guard let defaults else { return settings }
        if let raw = defaults.object(forKey: Key.characters) as? Int, let characters = RainCharacters(rawValue: raw) {
            settings.characters = characters
        }
        if let color = defaults.object(forKey: Key.color) as? Int {
            settings.colorIndex = color.clamped(to: 0...(RainColor.all.count - 1))
        }
        if let glyphSize = defaults.object(forKey: Key.glyphSize) as? Double {
            settings.glyphSize = glyphSize.clamped(to: glyphSizeRange)
        }
        if let density = defaults.object(forKey: Key.density) as? Double {
            settings.density = density.clamped(to: densityRange)
        }
        if let speed = defaults.object(forKey: Key.speed) as? Double {
            settings.speed = speed.clamped(to: speedRange)
        }
        return settings
    }

    func save() {
        guard let defaults = Self.defaults else { return }
        defaults.set(characters.rawValue, forKey: Key.characters)
        defaults.set(colorIndex, forKey: Key.color)
        defaults.set(glyphSize, forKey: Key.glyphSize)
        defaults.set(density, forKey: Key.density)
        defaults.set(speed, forKey: Key.speed)
        defaults.synchronize()
    }
}
