import SceneKit

/// Columns of glyphs raining down the screen, like the falling code in films of the late 90s.
///
/// The whole grid is one mesh, and a shader works out every cell's brightness and glyph from a
/// clock (see `RainGrid`). So per frame the CPU only advances the clock, which reaches the shader
/// as the rain node's z position: moving a node each frame costs far less CPU than updating a
/// material's shader value.
///
/// Everything runs on SceneKit's render thread via `renderer(_:updateAtTime:)`.
final class DigitalRainScene: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let cameraNode = SCNNode()

    private let rainNode = SCNNode()
    private let material = SCNMaterial()
    private var settings: DigitalRainSettings
    private var aspect: Float
    private let seed: UInt32
    /// Overrides the rows from the glyph size; the harness uses fewer, bigger glyphs for thumbnails.
    private let rowsOverride: Int?
    /// One stream in this many spells out a word; the harness can make it every stream, to test it.
    private let eggOdds: Int
    /// Scales the rows from the glyph size, for the small preview in System Settings.
    private let rowScale: Double
    private var atlas: GlyphAtlas?
    private var atlasCharacters: RainCharacters?
    private var ticks: UInt32 = 0
    private var tickBacklog = 0.0
    private var lastUpdateTime: TimeInterval?

    private let restartLock = NSLock()
    private var pendingSettings: DigitalRainSettings?
    private var pendingAspect: Float?

    /// The rain moves in whole cell steps on this clock, which matches the 30 fps frame rate, so
    /// every step lands on a frame.
    static let tickRate = 30.0
    /// Ticks reach the shader divided by 2^24, so the node stays near z = 0 and a float still holds
    /// them exactly. They wrap after 2^24 ticks, about 6 days.
    private static let clockScale: Float = 16_777_216
    /// At speed 1, each column steps down a cell every 2 to 4 ticks (7.5 to 15 cells a second).
    private static let stepTicks = 2.0...4.0

    init(settings: DigitalRainSettings, aspect: Float, seed: UInt64, rows: Int? = nil, rowScale: Double = 1,
         eggOdds: Int = RainGrid.eggOdds) {
        self.settings = settings
        self.aspect = aspect
        self.seed = UInt32(truncatingIfNeeded: seed) & 0xFFFFFF
        rowsOverride = rows
        self.rowScale = rowScale
        self.eggOdds = max(1, eggOdds)
        super.init()
        setUpScene()
        rebuild()
    }

    /// Thread-safe: applied on the next rendered frame.
    func restart(settings: DigitalRainSettings? = nil, aspect: Float? = nil) {
        restartLock.lock()
        defer { restartLock.unlock() }
        pendingSettings = settings ?? pendingSettings
        pendingAspect = aspect ?? pendingAspect
    }

    // MARK: - SCNSceneRendererDelegate

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt = lastUpdateTime.map { Float((time - $0).clamped(to: 0...0.1)) } ?? 0
        lastUpdateTime = time
        step(by: dt)
    }

    // MARK: - Animation

    func step(by dt: Float) {
        restartLock.lock()
        let newSettings = pendingSettings
        let newAspect = pendingAspect
        pendingSettings = nil
        pendingAspect = nil
        restartLock.unlock()
        var needsRebuild = false
        if let newSettings, newSettings != settings {
            settings = newSettings
            needsRebuild = true
        }
        if let newAspect, newAspect != aspect {
            aspect = newAspect
            needsRebuild = true
        }
        if needsRebuild {
            rebuild()
        }

        // Advance by whole ticks, rounding to the nearest, so the steps stay even when frames
        // arrive a little early or late.
        tickBacklog += Double(dt) * Self.tickRate
        let advance = (tickBacklog + 0.5).rounded(.down)
        tickBacklog -= advance
        ticks = (ticks &+ UInt32(advance)) & 0xFFFFFF
        rainNode.simdPosition = [0, 0, Float(ticks) / Self.clockScale]
    }

    // MARK: - Building

    private func rebuild() {
        let atlas: GlyphAtlas
        if let current = self.atlas, atlasCharacters == settings.characters {
            atlas = current
        } else {
            atlas = GlyphAtlas(settings.characters)
            material.diffuse.contents = atlas.image
            self.atlas = atlas
            atlasCharacters = settings.characters
        }
        let rows = rowsOverride ?? max(8, Int((Double(settings.rows) * rowScale).rounded()))
        let geometry = RainGrid.geometry(rows: rows, aspect: aspect)
        geometry.materials = [material]
        rainNode.geometry = geometry

        let grid = SCNVector4(Double(rows), Double(atlas.glyphCount), Double(atlas.columns), Double(atlas.rows))
        material.setValue(NSValue(scnVector4: grid), forKey: "dr_grid")
        material.setValue(NSValue(scnVector4: SCNVector4(Double(eggOdds), Double(atlas.eggStart), 0, 0)), forKey: "dr_egg")

        // Faster means fewer ticks per step, always whole ones.
        let shortest = max(1, (Self.stepTicks.lowerBound / settings.speed).rounded())
        let longest = max(shortest, (Self.stepTicks.upperBound / settings.speed).rounded())
        // Gaps between streams of up to this many screen heights: about 15% of the cells are lit at
        // density 0, 30% at 0.5 and 40% at 1.
        let gapScale = 0.1 + 6 * (1 - settings.density) * (1 - settings.density)
        material.setValue(NSValue(scnVector4: SCNVector4(shortest, longest - shortest + 1, gapScale, Double(seed))), forKey: "dr_rain")
        let rgb = settings.color.rgb
        // The shader's colors are linear; the presets are sRGB.
        material.setValue(NSValue(scnVector4: SCNVector4(rgb.x * rgb.x, rgb.y * rgb.y, rgb.z * rgb.z, 1)), forKey: "dr_color")
    }

    // MARK: - Scene setup

    private func setUpScene() {
        scene.background.contents = NSColor.black

        material.lightingModel = .constant
        material.diffuse.mipFilter = .linear
        material.blendMode = .add
        material.isDoubleSided = true
        material.readsFromDepthBuffer = false
        material.writesToDepthBuffer = false
        material.shaderModifiers = [.geometry: RainGrid.shader]
        scene.rootNode.addChildNode(rainNode)

        // Orthographic, showing -aspect...aspect by -1...1.
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 1
        camera.zNear = 0.1
        camera.zFar = 10
        cameraNode.camera = camera
        cameraNode.simdPosition = [0, 0, 2]
        scene.rootNode.addChildNode(cameraNode)
    }
}
