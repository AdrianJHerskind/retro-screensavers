import AppKit
import Metal
import ScreenSaver
import SceneKit

/// Hooks 3D Maze into the shared test harness. Extra command-line flags, for snapshots:
///
///     --maze small|medium|large   --rats 0...6   --flippers 0...10   --map
///     --overview (look down on the whole maze, to check where things are)
enum HarnessSaver: HarnessSupport {
    static let thumbnailMoment: (seconds: Double, seed: UInt64) = (9, 5)

    static func makeView(frame: NSRect) -> ScreenSaverView? {
        MazeSaverView(frame: frame, isPreview: false)
    }

    static func renderSnapshot(size: CGSize, seconds: Double, seed: UInt64) -> CGImage? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fputs("No Metal device available\n", stderr)
            return nil
        }

        var settings = MazeSettings()
        if let maze = argumentValue("--maze") {
            settings.size = MazeSize.allCases.first { "\($0)" == maze } ?? settings.size
        }
        if let rats = argumentValue("--rats").flatMap(Int.init) {
            settings.rats = rats.clamped(to: MazeSettings.ratsRange)
        }
        if let flippers = argumentValue("--flippers").flatMap(Int.init) {
            settings.flippers = flippers.clamped(to: MazeSettings.flippersRange)
        }
        settings.showsMap = CommandLine.arguments.contains("--map")

        let maze = MazeScene(settings: settings, seed: seed)
        let frameTime: Float = 1 / 60
        for _ in 0..<Int(seconds * 60) {
            maze.step(by: frameTime)
        }

        print("After \(seconds)s: \(maze.completedMazes) maze(s) finished")
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = maze.scene
        renderer.pointOfView = CommandLine.arguments.contains("--overview") ? maze.overviewCamera() : maze.cameraNode
        if settings.showsMap {
            maze.map.size = size
            renderer.overlaySKScene = maze.map
        }
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            .cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
