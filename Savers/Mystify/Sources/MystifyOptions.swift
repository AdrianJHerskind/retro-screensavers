import AppKit

/// The Mystify "Options…" sheet, after the original's: pick a polygon, then set whether it's
/// active, how many lines its trail has and how it's colored. Line width and speed apply to both.
final class MystifyOptions: NSObject {
    private(set) var sheet: OptionsSheet!
    private var settings: MystifySettings
    private var shownPolygon = 0

    private let polygonPopUp = OptionsSheet.popUp(titles: ["Polygon 1", "Polygon 2"], selectedIndex: 0)
    private let activeBox = NSButton(checkboxWithTitle: "Active", target: nil, action: nil)
    private let linesSlider: NSSlider
    private let colorModePopUp = OptionsSheet.popUp(titles: MystifyColorMode.allCases.map(\.title), selectedIndex: 0)
    private let firstColorPopUp = OptionsSheet.popUp(titles: MystifyColor.all.map(\.title), selectedIndex: 0)
    private let secondColorPopUp = OptionsSheet.popUp(titles: MystifyColor.all.map(\.title), selectedIndex: 0)

    init(settings: MystifySettings, onSave: @escaping (MystifySettings) -> Void) {
        self.settings = settings
        let lines = MystifyPolygonSettings.linesRange
        linesSlider = OptionsSheet.slider(range: Double(lines.lowerBound)...Double(lines.upperBound), value: 5, steps: lines.count)
        let lineWidthSlider = OptionsSheet.slider(range: MystifySettings.lineWidthRange, value: settings.lineWidth)
        let speedSlider = OptionsSheet.slider(range: MystifySettings.speedRange, value: settings.speed)
        super.init()

        polygonPopUp.target = self
        polygonPopUp.action = #selector(showSelectedPolygon)
        activeBox.target = self
        activeBox.action = #selector(updateEnabledControls)
        colorModePopUp.target = self
        colorModePopUp.action = #selector(updateEnabledControls)
        show(polygon: 0)

        let polygonRow = NSStackView(views: [polygonPopUp, activeBox])
        polygonRow.spacing = 12
        let colorsRow = NSStackView(views: [firstColorPopUp, NSTextField(labelWithString: "and"), secondColorPopUp])
        sheet = OptionsSheet(title: "Retro Mystify", rows: [
            ("Shape:", polygonRow),
            ("Lines:", linesSlider),
            ("Colors:", colorModePopUp),
            ("Two colors:", colorsRow),
            ("Line width:", lineWidthSlider),
            ("Speed:", speedSlider),
        ]) { [weak self] in
            guard let self else { return }
            store(polygon: shownPolygon)
            self.settings.lineWidth = lineWidthSlider.doubleValue
            self.settings.speed = speedSlider.doubleValue
            onSave(self.settings)
        }
    }

    /// Keeps the edits to the polygon on show, then shows the other one.
    @objc private func showSelectedPolygon() {
        store(polygon: shownPolygon)
        show(polygon: polygonPopUp.indexOfSelectedItem)
    }

    private func show(polygon index: Int) {
        shownPolygon = index
        let polygon = settings.polygons[index]
        polygonPopUp.selectItem(at: index)
        activeBox.state = polygon.isActive ? .on : .off
        linesSlider.integerValue = polygon.lines
        colorModePopUp.selectItem(at: MystifyColorMode.allCases.firstIndex(of: polygon.colorMode) ?? 0)
        firstColorPopUp.selectItem(at: polygon.firstColor)
        secondColorPopUp.selectItem(at: polygon.secondColor)
        updateEnabledControls()
    }

    private func store(polygon index: Int) {
        settings.polygons[index].isActive = activeBox.state == .on
        settings.polygons[index].lines = linesSlider.integerValue.clamped(to: MystifyPolygonSettings.linesRange)
        settings.polygons[index].colorMode = MystifyColorMode.allCases[colorModePopUp.indexOfSelectedItem]
        settings.polygons[index].firstColor = firstColorPopUp.indexOfSelectedItem
        settings.polygons[index].secondColor = secondColorPopUp.indexOfSelectedItem
    }

    @objc private func updateEnabledControls() {
        let isActive = activeBox.state == .on
        let usesTwoColors = MystifyColorMode.allCases[colorModePopUp.indexOfSelectedItem] == .twoColors
        linesSlider.isEnabled = isActive
        colorModePopUp.isEnabled = isActive
        firstColorPopUp.isEnabled = isActive && usesTwoColors
        secondColorPopUp.isEnabled = isActive && usesTwoColors
    }
}
