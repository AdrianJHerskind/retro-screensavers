import Foundation
import ScreenSaver

enum FlyingStyle: Int, CaseIterable {
    case flag
    case explode
    case ribbon
    case twoRibbons
    case splash
    case twist

    var title: String {
        switch self {
        case .flag: return "Flag"
        case .explode: return "Explode"
        case .ribbon: return "Ribbon"
        case .twoRibbons: return "Two Ribbons"
        case .splash: return "Splash"
        case .twist: return "Twist"
        }
    }
}

enum FlagDesign: Int, CaseIterable {
    case sunset
    case checkered
    case marble
    case wood
    case granite

    var title: String {
        switch self {
        case .sunset: return "Retro sunset"
        case .checkered: return "Checkered"
        case .marble: return "Marble"
        case .wood: return "Wood"
        case .granite: return "Granite"
        }
    }
}

struct FlyingObjectsSettings: Equatable {
    var style: FlyingStyle = .flag
    var flagDesign: FlagDesign = .sunset
    /// Slowly shifts every colour around the colour wheel (not for the flag).
    var cyclesColors = false
    /// Off shows the surfaces as flat facets.
    var smoothShading = true
    /// 0 is coarse and faceted, 1 is fine and smooth.
    var resolution = 0.5
    /// The object's size as a share of the screen height.
    var size = 0.5
    /// Multiplies how fast everything moves.
    var speed = 1.0

    static let resolutionRange = 0.0...1.0
    static let sizeRange = 0.2...0.8
    static let speedRange = 0.25...2.5

    /// Settings are stored per bundle identifier, which project.yml derives from BUNDLE_ID_PREFIX.
    private static let moduleName = Bundle(for: FlyingObjectsSaverView.self).bundleIdentifier ?? "RetroFlyingObjects"

    private enum Key {
        static let style = "style"
        static let flagDesign = "flagDesign"
        static let cyclesColors = "cyclesColors"
        static let smoothShading = "smoothShading"
        static let resolution = "resolution"
        static let size = "size"
        static let speed = "speed"
    }

    private static var defaults: UserDefaults? {
        ScreenSaverDefaults(forModuleWithName: moduleName)
    }

    static func load() -> FlyingObjectsSettings {
        var settings = FlyingObjectsSettings()
        guard let defaults else { return settings }
        if let raw = defaults.object(forKey: Key.style) as? Int, let style = FlyingStyle(rawValue: raw) {
            settings.style = style
        }
        if let raw = defaults.object(forKey: Key.flagDesign) as? Int, let design = FlagDesign(rawValue: raw) {
            settings.flagDesign = design
        }
        if let cyclesColors = defaults.object(forKey: Key.cyclesColors) as? Bool {
            settings.cyclesColors = cyclesColors
        }
        if let smoothShading = defaults.object(forKey: Key.smoothShading) as? Bool {
            settings.smoothShading = smoothShading
        }
        if let resolution = defaults.object(forKey: Key.resolution) as? Double {
            settings.resolution = resolution.clamped(to: resolutionRange)
        }
        if let size = defaults.object(forKey: Key.size) as? Double {
            settings.size = size.clamped(to: sizeRange)
        }
        if let speed = defaults.object(forKey: Key.speed) as? Double {
            settings.speed = speed.clamped(to: speedRange)
        }
        return settings
    }

    func save() {
        guard let defaults = Self.defaults else { return }
        defaults.set(style.rawValue, forKey: Key.style)
        defaults.set(flagDesign.rawValue, forKey: Key.flagDesign)
        defaults.set(cyclesColors, forKey: Key.cyclesColors)
        defaults.set(smoothShading, forKey: Key.smoothShading)
        defaults.set(resolution, forKey: Key.resolution)
        defaults.set(size, forKey: Key.size)
        defaults.set(speed, forKey: Key.speed)
        defaults.synchronize()
    }
}
