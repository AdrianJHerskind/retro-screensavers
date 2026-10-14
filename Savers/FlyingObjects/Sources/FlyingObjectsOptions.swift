import AppKit

/// The Flying Objects "Options…" sheet, after the original's.
final class FlyingObjectsOptions: NSObject {
    private(set) var sheet: OptionsSheet!
    private let stylePopUp: NSPopUpButton
    private let designPopUp: NSPopUpButton
    private let colorBox: NSButton

    init(settings: FlyingObjectsSettings, onSave: @escaping (FlyingObjectsSettings) -> Void) {
        stylePopUp = OptionsSheet.popUp(titles: FlyingStyle.allCases.map(\.title), selectedIndex: FlyingStyle.allCases.firstIndex(of: settings.style) ?? 0)
        designPopUp = OptionsSheet.popUp(titles: FlagDesign.allCases.map(\.title), selectedIndex: FlagDesign.allCases.firstIndex(of: settings.flagDesign) ?? 0)
        colorBox = NSButton(checkboxWithTitle: "Color-cycling", target: nil, action: nil)
        colorBox.state = settings.cyclesColors ? .on : .off
        let smoothBox = NSButton(checkboxWithTitle: "Smooth shading", target: nil, action: nil)
        smoothBox.state = settings.smoothShading ? .on : .off
        let checkboxes = NSStackView(views: [colorBox, smoothBox])
        checkboxes.orientation = .vertical
        checkboxes.alignment = .leading
        checkboxes.spacing = 6
        let resolutionSlider = OptionsSheet.slider(range: FlyingObjectsSettings.resolutionRange, value: settings.resolution)
        let sizeSlider = OptionsSheet.slider(range: FlyingObjectsSettings.sizeRange, value: settings.size)
        let speedSlider = OptionsSheet.slider(range: FlyingObjectsSettings.speedRange, value: settings.speed)
        super.init()

        stylePopUp.target = self
        stylePopUp.action = #selector(updateEnabledControls)
        updateEnabledControls()

        let stylePopUp = stylePopUp
        let designPopUp = designPopUp
        let colorBox = colorBox
        sheet = OptionsSheet(title: "Retro Flying Objects", rows: [
            ("Style:", stylePopUp),
            ("Flag design:", designPopUp),
            ("Colors:", checkboxes),
            ("Resolution:", resolutionSlider),
            ("Size:", sizeSlider),
            ("Speed:", speedSlider),
        ]) {
            var newSettings = settings
            newSettings.style = FlyingStyle.allCases[stylePopUp.indexOfSelectedItem]
            newSettings.flagDesign = FlagDesign.allCases[designPopUp.indexOfSelectedItem]
            newSettings.cyclesColors = colorBox.state == .on
            newSettings.smoothShading = smoothBox.state == .on
            newSettings.resolution = resolutionSlider.doubleValue
            newSettings.size = sizeSlider.doubleValue
            newSettings.speed = speedSlider.doubleValue
            onSave(newSettings)
        }
    }

    /// Like the original: the flag has its own picture, so colour-cycling only applies to the other styles.
    @objc private func updateEnabledControls() {
        let isFlag = FlyingStyle.allCases[stylePopUp.indexOfSelectedItem] == .flag
        designPopUp.isEnabled = isFlag
        colorBox.isEnabled = !isFlag
    }
}
