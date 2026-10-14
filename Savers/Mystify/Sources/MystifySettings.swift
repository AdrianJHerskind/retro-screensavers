import Foundation
import ScreenSaver

/// A color for the "Two colors" mode: bright, like the original's.
struct MystifyColor {
    let title: String
    /// sRGB components.
    let rgb: SIMD3<Double>

    static let all = [
        MystifyColor(title: "Red", rgb: [1, 0.16, 0.12]),
        MystifyColor(title: "Orange", rgb: [1, 0.55, 0.08]),
        MystifyColor(title: "Yellow", rgb: [1, 0.92, 0.15]),
        MystifyColor(title: "Lime", rgb: [0.68, 1, 0.12]),
        MystifyColor(title: "Green", rgb: [0.15, 0.88, 0.3]),
        MystifyColor(title: "Cyan", rgb: [0.15, 0.9, 1]),
        MystifyColor(title: "Blue", rgb: [0.25, 0.32, 1]),
        MystifyColor(title: "Purple", rgb: [0.58, 0.25, 1]),
        MystifyColor(title: "Magenta", rgb: [1, 0.25, 0.85]),
        MystifyColor(title: "White", rgb: [1, 1, 1]),
    ]

    static func index(of title: String) -> Int {
        all.firstIndex { $0.title == title } ?? 0
    }
}

enum MystifyColorMode: Int, CaseIterable {
    /// Each polygon drifts from one random color to the next.
    case random
    /// Each polygon fades back and forth between two chosen colors.
    case twoColors

    var title: String {
        switch self {
        case .random: return "Multiple random colors"
        case .twoColors: return "Two colors"
        }
    }
}

/// One polygon's settings, like the original's per-polygon options.
struct MystifyPolygonSettings: Equatable {
    var isActive = true
    /// How many copies of the polygon make up its trail.
    var lines = 5
    var colorMode = MystifyColorMode.random
    /// Indices into `MystifyColor.all`.
    var firstColor = 0
    var secondColor = 0

    static let linesRange = 1...15
}

struct MystifySettings: Equatable {
    /// A blue polygon and a green one, as most people remember it.
    var polygons = [
        MystifyPolygonSettings(colorMode: .twoColors, firstColor: MystifyColor.index(of: "Blue"), secondColor: MystifyColor.index(of: "Purple")),
        MystifyPolygonSettings(colorMode: .twoColors, firstColor: MystifyColor.index(of: "Lime"), secondColor: MystifyColor.index(of: "Green")),
    ]
    /// Line width in points.
    var lineWidth = 1.5
    /// Multiplies how fast everything moves.
    var speed = 1.0

    static let lineWidthRange = 1.0...4.0
    static let speedRange = 0.25...2.5

    /// Settings are stored per bundle identifier, which project.yml derives from BUNDLE_ID_PREFIX.
    private static let moduleName = Bundle(for: MystifySaverView.self).bundleIdentifier ?? "RetroMystify"

    private enum Key {
        static let lineWidth = "lineWidth"
        static let speed = "speed"

        static func polygon(_ index: Int, _ name: String) -> String {
            "polygon\(index + 1).\(name)"
        }
    }

    private static var defaults: UserDefaults? {
        ScreenSaverDefaults(forModuleWithName: moduleName)
    }

    static func load() -> MystifySettings {
        var settings = MystifySettings()
        guard let defaults else { return settings }
        let colors = 0...(MystifyColor.all.count - 1)
        for index in settings.polygons.indices {
            if let isActive = defaults.object(forKey: Key.polygon(index, "active")) as? Bool {
                settings.polygons[index].isActive = isActive
            }
            if let lines = defaults.object(forKey: Key.polygon(index, "lines")) as? Int {
                settings.polygons[index].lines = lines.clamped(to: MystifyPolygonSettings.linesRange)
            }
            if let raw = defaults.object(forKey: Key.polygon(index, "colorMode")) as? Int, let mode = MystifyColorMode(rawValue: raw) {
                settings.polygons[index].colorMode = mode
            }
            if let color = defaults.object(forKey: Key.polygon(index, "firstColor")) as? Int {
                settings.polygons[index].firstColor = color.clamped(to: colors)
            }
            if let color = defaults.object(forKey: Key.polygon(index, "secondColor")) as? Int {
                settings.polygons[index].secondColor = color.clamped(to: colors)
            }
        }
        if let lineWidth = defaults.object(forKey: Key.lineWidth) as? Double {
            settings.lineWidth = lineWidth.clamped(to: lineWidthRange)
        }
        if let speed = defaults.object(forKey: Key.speed) as? Double {
            settings.speed = speed.clamped(to: speedRange)
        }
        return settings
    }

    func save() {
        guard let defaults = Self.defaults else { return }
        for (index, polygon) in polygons.enumerated() {
            defaults.set(polygon.isActive, forKey: Key.polygon(index, "active"))
            defaults.set(polygon.lines, forKey: Key.polygon(index, "lines"))
            defaults.set(polygon.colorMode.rawValue, forKey: Key.polygon(index, "colorMode"))
            defaults.set(polygon.firstColor, forKey: Key.polygon(index, "firstColor"))
            defaults.set(polygon.secondColor, forKey: Key.polygon(index, "secondColor"))
        }
        defaults.set(lineWidth, forKey: Key.lineWidth)
        defaults.set(speed, forKey: Key.speed)
        defaults.synchronize()
    }
}
