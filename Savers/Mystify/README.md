# Retro Mystify

A recreation of the classic Windows Mystify Your Mind. Two four-cornered polygons bounce around a black screen, each trailed by copies of itself, changing shape and color as they go.

Built with SceneKit, from scratch: no Microsoft code or artwork. Not affiliated with or endorsed by Microsoft. Windows is a trademark of Microsoft Corporation.

## Options

Like the original, each polygon has its own settings. Choose Polygon 1 or Polygon 2 next to **Shape**, then set:
- **Active**: show or hide it.
- **Lines**: how many copies make up its trail, from 1 to 15. The default is 5, as in the original.
- **Colors**: either two colors it fades between, or multiple random colors. The default pairs are blue and purple, and lime and green.

**Line width** and **Speed** apply to both polygons.

## Test app flags

For snapshots, use `make snapshot SAVER=Mystify ARGS="…"`:

- `--lines 1…15`, `--line-width 1…4` and `--random-colors`.
- `--points-scale n`: how many pixels make a point. The default is 2, as on a Retina screen. It sets how thick the lines come out.
- `--line-scale n` and `--spacing-scale n`: thicker lines and copies spaced further apart, as for the thumbnail.

## Code

- `MystifyLines.swift`: the mesh and the shader. The mesh holds one thin quad per edge of each copy. The shader works out where each copy's corners are, and its color, from a clock.
- `MystifyScene.swift`: the motion and the clock. Each corner bounces off the edges at its own speed, which slowly speeds up and slows down.
- `MystifySaverView.swift`, `MystifyOptions.swift`, `MystifySettings.swift`: the view, the Options sheet, and the saved settings.

Per frame, the CPU only advances the clock. It hands the clock to the shader as a node's position, because updating a material's shader value every frame cost about 7% more of one CPU core.

The clock loops every hour, which keeps the shader's maths precise. Every speed is rounded so that the corners and colors are back where they started at the end of the hour, so the loop is seamless. See `make perf` for what it costs.
