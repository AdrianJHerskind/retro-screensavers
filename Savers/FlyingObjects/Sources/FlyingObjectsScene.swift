import SceneKit

/// One of the Flying Objects styles bouncing around the screen and tumbling, while a shader on
/// the GPU animates its shape (see `FlyingShapes`).
///
/// Everything runs on SceneKit's render thread via `renderer(_:updateAtTime:)`.
final class FlyingObjectsScene: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let cameraNode = SCNNode()

    private let objectNode = SCNNode()
    private let shapeNode = SCNNode()
    private var material = SCNMaterial()
    private var settings: FlyingObjectsSettings
    private var aspect: Float
    private var rng: SplitMix64
    private var extent: Float = 1
    private var time: Float = 0
    private var hueShift: Float = 0
    private var position = SIMD2<Float>(0, 0)
    private var velocity = SIMD2<Float>(0, 0)
    private var spinAxis = SIMD3<Float>(0, 1, 0)
    private var lastUpdateTime: TimeInterval?

    private let restartLock = NSLock()
    private var pendingSettings: FlyingObjectsSettings?
    private var pendingAspect: Float?

    private static let fieldOfView: Float = 40
    private static let cameraDistance: Float = 6
    private static let halfHeight = cameraDistance * tan(fieldOfView / 2 * .pi / 180)
    /// Floating speed in screen heights per second, and tumbling speed in radians per second.
    private static let floatSpeed: Float = 0.15
    private static let spinSpeed: Float = 0.6
    /// Hue turns per second when cycling colours.
    private static let hueSpeed: Float = 0.05

    init(settings: FlyingObjectsSettings, aspect: Float, seed: UInt64) {
        self.settings = settings
        self.aspect = aspect
        rng = SplitMix64(seed: seed)
        super.init()
        setUpScene()
        rebuild()
    }

    /// Thread-safe: applied on the next rendered frame.
    func restart(settings: FlyingObjectsSettings? = nil, aspect: Float? = nil) {
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
        if let newAspect {
            aspect = newAspect
        }
        if let newSettings, newSettings != settings {
            settings = newSettings
            rebuild()
        }

        let dt = dt * Float(settings.speed)
        // Kept small so the shaders' float maths stays precise however long it runs.
        time = (time + dt).truncatingRemainder(dividingBy: 1000)
        material.setValue(NSNumber(value: time), forKey: "fo_time")
        if settings.cyclesColors, settings.style != .flag {
            hueShift = (hueShift + dt * Self.hueSpeed).truncatingRemainder(dividingBy: 1)
            material.setValue(NSNumber(value: hueShift), forKey: "fo_hue_shift")
        }

        let nudge = SIMD3(Float.random(in: -1...1, using: &rng), Float.random(in: -1...1, using: &rng), Float.random(in: -1...1, using: &rng))
        spinAxis = simd_normalize(spinAxis + nudge * dt * 0.3)
        objectNode.simdOrientation = simd_quatf(angle: Self.spinSpeed * dt, axis: spinAxis) * objectNode.simdOrientation

        let reach = extent * objectNode.simdScale.x
        let limit = simd_max(SIMD2(Self.halfHeight * aspect, Self.halfHeight) - reach, .zero)
        position += velocity * dt
        for axis in 0..<2 {
            if position[axis] > limit[axis] {
                position[axis] = limit[axis]
                velocity[axis] = -abs(velocity[axis])
            } else if position[axis] < -limit[axis] {
                position[axis] = -limit[axis]
                velocity[axis] = abs(velocity[axis])
            }
        }
        objectNode.simdPosition = [position.x, position.y, 0]
    }

    private func rebuild() {
        let shape = FlyingShapes.make(settings.style, resolution: settings.resolution)
        extent = shape.extent

        material = SCNMaterial()
        material.lightingModel = .phong
        material.specular.contents = NSColor(white: 0.7, alpha: 1)
        material.shininess = 0.4
        material.locksAmbientWithDiffuse = true
        material.isDoubleSided = true
        if settings.style == .flag {
            material.diffuse.contents = FlagDesigns.image(settings.flagDesign)
            material.diffuse.mipFilter = .linear
        } else {
            material.diffuse.contents = NSColor.white
        }
        material.shaderModifiers = [.geometry: shape.shader, .surface: FlyingShapes.surfaceShader]
        material.setValue(NSNumber(value: time), forKey: "fo_time")
        material.setValue(NSNumber(value: hueShift), forKey: "fo_hue_shift")
        material.setValue(NSNumber(value: settings.smoothShading ? 0 : 1), forKey: "fo_flat")
        shape.geometry.materials = [material]
        shapeNode.geometry = shape.geometry

        objectNode.simdScale = SIMD3(repeating: Float(settings.size) * Self.halfHeight / extent)
        let angle = Float.random(in: 0..<(2 * .pi), using: &rng)
        velocity = SIMD2(cos(angle), sin(angle)) * Self.floatSpeed * 2 * Self.halfHeight
        spinAxis = simd_normalize(SIMD3(Float.random(in: -1...1, using: &rng), 1, Float.random(in: -1...1, using: &rng)))
    }

    // MARK: - Scene setup

    private func setUpScene() {
        scene.background.contents = NSColor.black
        scene.rootNode.addChildNode(objectNode)
        objectNode.addChildNode(shapeNode)

        let camera = SCNCamera()
        camera.fieldOfView = CGFloat(Self.fieldOfView)
        camera.zNear = 0.1
        camera.zFar = 50
        cameraNode.camera = camera
        cameraNode.simdPosition = [0, 0, Self.cameraDistance]
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(white: 0.28, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 950
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.simdPosition = [-6, 8, 10]
        keyNode.simdLook(at: .zero)
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 300
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.simdPosition = [8, -4, 6]
        fillNode.simdLook(at: .zero)
        scene.rootNode.addChildNode(fillNode)
    }
}
