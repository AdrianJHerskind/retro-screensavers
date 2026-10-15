# Retro Digital Rain

Columns of green glyphs raining down a black screen: the falling code made famous by the 1999 film *The Matrix*. Each stream is led by a bright, nearly white glyph and fades away behind it, while glyphs flicker and change in place.

Built with SceneKit, from scratch. The glyphs are half-width katakana, digits and symbols from Hiragino Sans, a font that comes with macOS, not the film's typeface. Not affiliated with or endorsed by Warner Bros. The Matrix is a trademark of Warner Bros. Entertainment Inc.

## Options

- **Characters**: mirrored katakana (as in the film), katakana the right way round, or binary.
- **Color**: green, cyan, blue, purple, red, amber or white.
- **Glyph size**, **Density** and **Speed**.

The preview in System Settings shows fewer, bigger glyphs, so they're readable at its small size.

Keep watching: now and then, a stream spells out a word on its way down.

## Test app flags

For snapshots, use `make snapshot SAVER=DigitalRain ARGS="…"`:

- `--characters mirroredKatakana|katakana|binary` and `--color Green|Cyan|Blue|Purple|Red|Amber|White`
- `--glyph-size 0…1`, or `--rows n` for an exact number of rows
- `--density 0…1` and `--rain-speed 0.5…2`
- `--egg-odds n`: one stream in n spells out a word (1024 by default). Use 1 to see the words everywhere.

## Code

- `RainGrid.swift`: the grid of glyph cells as one mesh, and the shader that lights them. The glyphs don't move. Each column's stream is a lit stretch of cells whose head steps down one cell at a time, and each cell's glyph changes now and then.
- `GlyphAtlas.swift`: draws the glyphs once into a texture, white with a soft glow baked in, so the glow costs nothing while the rain runs.
- `DigitalRainScene.swift`: the clock and the settings.
- `DigitalRainSaverView.swift`, `DigitalRainOptions.swift`, `DigitalRainSettings.swift`: the view, the Options sheet, and the saved settings.

The rain moves in whole cell steps on a 30 Hz clock, so it runs at 30 fps, and every step lands on a frame. Per frame, the CPU only advances the clock, which reaches the shader as a node's position. See `make perf` for what it costs.
