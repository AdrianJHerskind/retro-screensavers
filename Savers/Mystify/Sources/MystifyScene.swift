import SceneKit

/// Two polygons bouncing around the screen, each trailed by copies of itself.
///
/// Every corner moves on its own and bounces off the edges, so the polygons keep changing shape.
/// Where each corner is, and each copy's color, are functions of one clock, worked out by the
/// shader in `MystifyLines`. So per frame the CPU only advances the clock.
///
/// Everything runs on SceneKit's render thread via `renderer(_:updateAtTime:)`.
final class MystifyScene: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let cameraNode = SCNNode()

    private var settings: MystifySettings
    private var viewSize: CGSize
    private let lineScale: Double
    private let spacingScale: Double
    private var rng: SplitMix64
    /// Carries the clock to the shader in its z position. Moving a node each frame costs far less
    /// CPU than updating a material's shader value (about 1 against 7 percent of a core, measured).
    private let clockNode = SCNNode()
    private var clock = 0.0
    private var polygons: [Polygon] = []
    private var lastUpdateTime: TimeInterval?

    private let restartLock = NSLock()
    private var pendingSettings: MystifySettings?
    private var pendingViewSize: CGSize?

    /// The clock runs from 0 to this many seconds, then starts over, which keeps the shader's
    /// float maths precise. Every speed and rate is rounded so that the motion and colors repeat
    /// exactly after it, which makes the loop seamless.
    static let loopLength = 3600.0
    /// Time between one copy and the next, in seconds at speed 1, like the original's timer ticks.
    private static let copySpacing = 0.05
    /// How fast the corners move, in screen heights per second.
    private static let cornerSpeeds = 0.15...0.4
    /// How fast the corners' speed wobbles (radians per second), and how far: up to this share
    /// faster or slower than their steady speed.
    private static let wobbleRates = 0.15...0.5
    private static let wobbleDepth = 0.6
    /// Seconds per random color, and per round trip between the two colors. Both divide `loopLength`.
    private static let randomColorPeriod = 4.0
    private static let twoColorPeriod = 8.0

    /// One polygon's node and motion. Phases count screen crossings, see `MystifyLines.shader`.
    private struct Polygon {
        let node = SCNNode()
        let material = SCNMaterial()
        /// Where along their bounce, and their wobble, the corners start.
        let phase: (x: SIMD4<Double>, y: SIMD4<Double>)
        let angle: (x: SIMD4<Double>, y: SIMD4<Double>)
        /// Screen heights per second.
        let cornerSpeed: (x: SIMD4<Double>, y: SIMD4<Double>)
        /// Radians per second.
        let rate: (x: SIMD4<Double>, y: SIMD4<Double>)
        let colorSeed: Double
    }

    /// `viewSize` is in points. For small thumbnails, `lineScale` thickens the lines and
    /// `spacingScale` spreads the copies further apart, so they don't blur together.
    init(settings: MystifySettings, viewSize: CGSize, seed: UInt64, lineScale: Double = 1, spacingScale: Double = 1) {
        self.settings = settings
        self.viewSize = viewSize
        self.lineScale = lineScale
        self.spacingScale = spacingScale
        rng = SplitMix64(seed: seed)
        super.init()
        setUpScene()
        rebuild()
    }

    /// Thread-safe: applied on the next rendered frame.
    func restart(settings: MystifySettings? = nil, viewSize: CGSize? = nil) {
        restartLock.lock()
        defer { restartLock.unlock() }
        pendingSettings = settings ?? pendingSettings
        pendingViewSize = viewSize ?? pendingViewSize
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
        let newViewSize = pendingViewSize
        pendingSettings = nil
        pendingViewSize = nil
        restartLock.unlock()
        var needsRebuild = false
        if let newSettings, newSettings != settings {
            settings = newSettings
            needsRebuild = true
        }
        if let newViewSize, newViewSize != viewSize, newViewSize.width > 0, newViewSize.height > 0 {
            viewSize = newViewSize
            needsRebuild = true
        }
        if needsRebuild {
            rebuild()
        }

        clock = (clock + Double(dt) * settings.speed).truncatingRemainder(dividingBy: Self.loopLength)
        clockNode.simdPosition = [0, 0, Float(clock)]
    }

    private var aspect: Double {
        viewSize.height > 0 ? viewSize.width / viewSize.height : 1.6
    }

    // MARK: - Building

    private func rebuild() {
        let aspect = self.aspect
        let halfLineWidth = settings.lineWidth * lineScale / max(viewSize.height, 1)
        for (index, polygonSettings) in settings.polygons.enumerated() {
            let polygon = polygons[index]
            polygon.node.isHidden = !polygonSettings.isActive
            let geometry = MystifyLines.geometry(copies: polygonSettings.lines, aspect: Float(aspect))
            geometry.materials = [polygon.material]
            polygon.node.geometry = geometry

            // Phases count screen crossings, so a crossing of the wider x takes longer. A round
            // trip is 2 crossings, so a whole number of them per loop needs a multiple of 2 / loop.
            let speed = (x: Self.looping(polygon.cornerSpeed.x / aspect, step: 2), y: Self.looping(polygon.cornerSpeed.y, step: 2))
            let rate = (x: Self.looping(polygon.rate.x, step: 2 * .pi), y: Self.looping(polygon.rate.y, step: 2 * .pi))
            let material = polygon.material
            material.setValue(Self.vector(polygon.phase.x), forKey: "my_phase_x")
            material.setValue(Self.vector(polygon.phase.y), forKey: "my_phase_y")
            material.setValue(Self.vector(polygon.angle.x), forKey: "my_angle_x")
            material.setValue(Self.vector(polygon.angle.y), forKey: "my_angle_y")
            material.setValue(Self.vector(speed.x), forKey: "my_speed_x")
            material.setValue(Self.vector(speed.y), forKey: "my_speed_y")
            material.setValue(Self.vector(rate.x), forKey: "my_rate_x")
            material.setValue(Self.vector(rate.y), forKey: "my_rate_y")
            // The wobble's own speed is its size times its rate; keep it below the steady speed,
            // so the corners never stop or turn back between edges.
            material.setValue(Self.vector(Self.wobbleDepth * speed.x / rate.x), forKey: "my_wobble_x")
            material.setValue(Self.vector(Self.wobbleDepth * speed.y / rate.y), forKey: "my_wobble_y")

            let colorPeriod = polygonSettings.colorMode == .random ? Self.randomColorPeriod : Self.twoColorPeriod
            material.setValue(NSValue(scnVector4: SCNVector4(aspect, halfLineWidth, Self.copySpacing * spacingScale, 1 / colorPeriod)), forKey: "my_field")
            let first = Self.linear(MystifyColor.all[polygonSettings.firstColor].rgb)
            let second = Self.linear(MystifyColor.all[polygonSettings.secondColor].rgb)
            let mode = polygonSettings.colorMode == .twoColors ? 1.0 : 0.0
            material.setValue(NSValue(scnVector4: SCNVector4(first.x, first.y, first.z, mode)), forKey: "my_color_a")
            material.setValue(NSValue(scnVector4: SCNVector4(second.x, second.y, second.z, polygon.colorSeed)), forKey: "my_color_b")
        }
    }

    /// Rounds per-second values to whole multiples of `step` per loop (at least one).
    private static func looping(_ value: SIMD4<Double>, step: Double) -> SIMD4<Double> {
        let quantum = step / loopLength
        return quantum * simd_max((value / quantum).rounded(.toNearestOrAwayFromZero), SIMD4(repeating: 1))
    }

    private static func vector(_ value: SIMD4<Double>) -> NSValue {
        NSValue(scnVector4: SCNVector4(value.x, value.y, value.z, value.w))
    }

    /// The shader's colors are linear; the presets are sRGB.
    private static func linear(_ rgb: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(rgb.x * rgb.x, rgb.y * rgb.y, rgb.z * rgb.z)
    }

    // MARK: - Scene setup

    private func setUpScene() {
        scene.background.contents = NSColor.black
        scene.rootNode.addChildNode(clockNode)

        for index in settings.polygons.indices {
            let polygon = Polygon(
                phase: (randomVector(in: 0..<2), randomVector(in: 0..<2)),
                angle: (randomVector(in: 0..<(2 * .pi)), randomVector(in: 0..<(2 * .pi))),
                cornerSpeed: (randomVector(in: Self.cornerSpeeds), randomVector(in: Self.cornerSpeeds)),
                rate: (randomVector(in: Self.wobbleRates), randomVector(in: Self.wobbleRates)),
                colorSeed: Double(Int.random(in: 0..<1_000_000, using: &rng))
            )
            let material = polygon.material
            material.lightingModel = .constant
            material.diffuse.contents = NSColor.white
            material.isDoubleSided = true
            material.readsFromDepthBuffer = false
            material.writesToDepthBuffer = false
            material.shaderModifiers = [.geometry: MystifyLines.shader]
            // The second polygon draws over the first.
            polygon.node.renderingOrder = index
            clockNode.addChildNode(polygon.node)
            polygons.append(polygon)
        }

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

    private func randomVector(in range: Range<Double>) -> SIMD4<Double> {
        SIMD4((0..<4).map { _ in Double.random(in: range, using: &rng) })
    }

    private func randomVector(in range: ClosedRange<Double>) -> SIMD4<Double> {
        SIMD4((0..<4).map { _ in Double.random(in: range, using: &rng) })
    }
}
