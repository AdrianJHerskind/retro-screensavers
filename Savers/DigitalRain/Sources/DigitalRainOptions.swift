import AppKit

/// The Digital Rain "Options…" sheet.
final class DigitalRainOptions: NSObject {
    private(set) var sheet: OptionsSheet!

    init(settings: DigitalRainSettings, onSave: @escaping (DigitalRainSettings) -> Void) {
        let charactersPopUp = OptionsSheet.popUp(titles: RainCharacters.allCases.map(\.title),
                                                 selectedIndex: RainCharacters.allCases.firstIndex(of: settings.characters) ?? 0)
        let colorPopUp = OptionsSheet.popUp(titles: RainColor.all.map(\.title), selectedIndex: settings.colorIndex)
        let glyphSizeSlider = OptionsSheet.slider(range: DigitalRainSettings.glyphSizeRange, value: settings.glyphSize)
        let densitySlider = OptionsSheet.slider(range: DigitalRainSettings.densityRange, value: settings.density)
        let speedSlider = OptionsSheet.slider(range: DigitalRainSettings.speedRange, value: settings.speed)
        super.init()

        sheet = OptionsSheet(title: "Retro Digital Rain", rows: [
            ("Characters:", charactersPopUp),
            ("Color:", colorPopUp),
            ("Glyph size:", glyphSizeSlider),
            ("Density:", densitySlider),
            ("Speed:", speedSlider),
        ]) {
            var newSettings = settings
            newSettings.characters = RainCharacters.allCases[charactersPopUp.indexOfSelectedItem]
            newSettings.colorIndex = colorPopUp.indexOfSelectedItem
            newSettings.glyphSize = glyphSizeSlider.doubleValue
            newSettings.density = densitySlider.doubleValue
            newSettings.speed = speedSlider.doubleValue
            onSave(newSettings)
        }
    }
}
