# Retro Flying Objects

A recreation of the classic Windows 3D Flying Objects. A shiny object bounces around the screen and tumbles, while it waves, twists, ripples or bursts apart.

Built with SceneKit, from scratch: no Microsoft code or artwork. The original waved the Windows logo; this one waves its own designs. Not affiliated with or endorsed by Microsoft. Windows is a trademark of Microsoft Corporation.

## Styles

- **Flag** (the default): a flag rippling in the wind. Choose a retro synthwave sunset, a checkered racing flag, or marble, wood or granite.
- **Explode**: a faceted sphere that bursts apart, its facets tumbling outwards, then pulls back together.
- **Ribbon** and **Two Ribbons**: rainbow ribbon loops twisting through space.
- **Splash**: a disc rippling outwards like water where a drop has landed.
- **Twist**: a five-pointed star column twisting back and forth.

## Options

The original's settings, plus speed:
- **Style**, and **Flag design** for the flag.
- **Color-cycling**: slowly shifts the colors around the color wheel. Like the original, it's off by default and doesn't apply to the flag.
- **Smooth shading**: turn it off to see the surfaces as flat facets.
- **Resolution**: lower is coarser and more faceted.
- **Size** and **Speed**.

## Test app flags

For snapshots, use `make snapshot SAVER=FlyingObjects ARGS="…"`:

- `--style flag|explode|ribbon|twoRibbons|splash|twist` and `--design sunset|checkered|marble|wood|granite`
- `--resolution 0…1`, `--object-size 0.2…0.8`, `--flat`, `--cycle`

## Code

- `FlyingShapes.swift`: each style's mesh, and the shader that animates it. The meshes mostly store parameters (how far along a ribbon, which facet of the sphere, how far out on the disc), and the GPU turns them into the moving shape from a shared clock. A second shader lights both sides of open surfaces like the flag and ribbons, and computes the flat facets when smooth shading is off.
- `FlagDesigns.swift`: the flag pictures. The sunset and the checkered flag are drawn in code; the rest are the shared `RetroTexture`s.
- `FlyingObjectsScene.swift`: bouncing, tumbling and the clock.
- `FlyingObjectsSaverView.swift`, `FlyingObjectsOptions.swift`, `FlyingObjectsSettings.swift`: the view, the Options sheet, and the saved settings.

All the shape animation runs on the GPU, so per frame the CPU only advances the clock and moves the object. See `make perf` for what it costs.
