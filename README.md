# retro-screensavers

A collection of macOS screen savers recreating classics from the 90s. Each one is its own `.saver` bundle, so it shows up separately in System Settings with its own thumbnail and options.

| Screen saver | |
| --- | --- |
| [Retro Pipes](Savers/Pipes/README.md) | The Windows 3D Pipes: pipes grow through a deep 3D grid with ball and elbow joints, solid or textured, and the screen dissolves to black in random blocks when it fills up. Teapot included. |

Requires macOS 14+, Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

## Usage

| Command | What it does |
| --- | --- |
| `make install` | Builds every saver (Release) and copies them to `~/Library/Screen Savers`. Then pick one in System Settings → Screen Saver. |
| `make uninstall` | Removes them again. |
| `make run SAVER=Pipes` | Opens a saver's test app, which shows it in a normal window (⌘, for options, ⌃⌘F for full screen). Saver-specific flags go in `ARGS`. |
| `make snapshot SAVER=Pipes ARGS="--time 30"` | Renders one frame offscreen to `build/snapshot.png`; also takes `--size WxH` and `--seed n`. |
| `make thumbnails SAVER=Pipes` | Regenerates the saver's System Settings tile in `Savers/<Name>/Resources`. |
| `make project` | Generates `RetroScreensavers.xcodeproj` from `project.yml`, for working in Xcode. |

`SAVER` defaults to `Pipes`.

## Layout

- `Savers/<Name>/`: one screen saver, built as `Retro<Name>.saver`.
  - `Sources/`: its code, compiled as its own Swift module, so savers can't clash with each other.
  - `Harness/`: hooks it into the shared test app (a `HarnessSaver` type conforming to `HarnessSupport`).
  - `Resources/`: thumbnails and anything else bundled with it.
  - `Info.plist`: names the principal class and the display name.
- `Shared/Common/`: compiled into every saver.
  - `RetroScreenSaverView`: the base class; handles the host quirks below.
  - `OptionsSheet`: the standard Options sheet layout.
  - Small helpers such as a seedable random number generator.
- `Shared/Harness/`: the test app and the offscreen snapshot and thumbnail renderer, compiled into each saver's harness.

## Adding a screen saver

1. Create `Savers/<Name>/` with `Sources/`, `Harness/` and an `Info.plist` (copy the one from Pipes and change `NSPrincipalClass` and the names).
2. In `Sources/`, subclass `RetroScreenSaverView` and give it a unique Objective-C name matching the plist, e.g. `@objc(RetroStarfieldSaverView)`. Override `setAnimating(_:)` to start and stop drawing.
3. In `Harness/`, add an `enum HarnessSaver: HarnessSupport`.
4. Add the targets to `project.yml`:
   ```yaml
   <Name>:
     templates: [ScreenSaver]
   <Name>Harness:
     templates: [Harness]
     templateAttributes:
       saver: <Name>
   ```
5. Run `make run SAVER=<Name>` to try it, then `make thumbnails SAVER=<Name>` and `make install`.

## macOS quirks handled

- Since Sonoma, third-party savers run inside `legacyScreenSaver`. It doesn't reliably call `stopAnimation()` and keeps old instances alive. `RetroScreenSaverView` listens for `com.apple.screensaver.willstop`, stops drawing, and quits the host process (never for the System Settings preview or the test app).
- `legacyScreenSaver` caches loaded bundles, so `make install` quits it to pick up new builds.
- System Settings can load several savers into one process, so each principal class has its own explicit Objective-C name.

## Sharing it

Local builds are ad-hoc signed, which is enough on this Mac. To give the `.saver` files to other people, sign them with a Developer ID and notarize them; otherwise Gatekeeper blocks them. Before publishing, set `BUNDLE_ID_PREFIX` in `project.yml` to a prefix you own.

## License

MIT; see [LICENSE](LICENSE).

These are independent recreations, written from scratch. Not affiliated with or endorsed by Microsoft. Windows is a trademark of Microsoft Corporation.
