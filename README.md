# retro-screensavers

A collection of macOS screen savers recreating classics from the 90s. Each one is its own `.saver` bundle, so it shows up separately in System Settings with its own thumbnail and options.

| Screen saver | |
| --- | --- |
| [Retro Pipes](Savers/Pipes/README.md) | The Windows 3D Pipes: pipes grow through a deep 3D grid with ball and elbow joints, solid or textured, and the screen dissolves to black in random blocks when it fills up. Teapot included. |

## Install

Requires macOS 14 Sonoma or later, on Apple Silicon or Intel.

1. Download a saver, e.g. `RetroPipes.saver.zip`, from the [latest release](https://github.com/AdrianJHerskind/retro-screensavers/releases/latest) and unzip it. Safari usually unzips it for you.
2. The savers aren't notarized by Apple, so macOS blocks them when they're downloaded. To allow it, run this once in Terminal (adjust the path if you unzipped it somewhere other than Downloads):
   ```bash
   xattr -dr com.apple.quarantine ~/Downloads/RetroPipes.saver
   ```
3. Double-click `RetroPipes.saver` and choose to install it.
4. Pick it in System Settings → Screen Saver. Third-party savers are listed under **Other**, at the bottom. **Options…** opens its settings.

If you installed it before step 2, run the command on the installed copy instead: `xattr -dr com.apple.quarantine ~/Library/Screen\ Savers/RetroPipes.saver`.

To uninstall, delete it from `~/Library/Screen Savers`.

## Building from source

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

| Command | What it does |
| --- | --- |
| `make install` | Builds every saver (Release) and copies them to `~/Library/Screen Savers`. Then pick one in System Settings → Screen Saver. Local builds aren't blocked, so there's no `xattr` step. |
| `make uninstall` | Removes them again. |
| `make dist` | Builds every saver and zips each one into `dist/`, ready to attach to a GitHub release. |
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

Local builds are ad-hoc signed, which is enough on this Mac. To give the `.saver` files to other people, sign them with a Developer ID and notarize them; otherwise Gatekeeper blocks them. If you publish your own fork, change `BUNDLE_ID_PREFIX` in `project.yml` to a prefix you own.

## License

MIT; see [LICENSE](LICENSE).

These are independent recreations, written from scratch. Not affiliated with or endorsed by Microsoft. Windows is a trademark of Microsoft Corporation.
