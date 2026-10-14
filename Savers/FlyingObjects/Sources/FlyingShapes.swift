import SceneKit

/// A style's mesh, and the geometry shader modifier that animates it on the GPU.
///
/// The meshes mostly store parameters rather than final positions: where along the ribbon, which
/// facet of the sphere, how far out on the disc. The shaders turn those into the moving shape from
/// the `fo_time` clock, so the CPU only advances the clock each frame (see `animated`).
struct FlyingShape {
    let geometry: SCNGeometry
    let shader: String
    /// A radius that holds the shape at any moment, for sizing it and bouncing it off the edges.
    let extent: Float
}

enum FlyingShapes {
    /// The clock runs from 0 to this many seconds and starts over, which keeps the shaders' float
    /// maths precise. Every rate in the shaders turns a whole number of times per loop, so the
    /// loop is seamless. The loop is 100 turns of 2π seconds, so rates in radians per second can
    /// have up to two decimals; other rates are counted per loop.
    static let loopLength: Float = 200 * .pi
    /// The clock node's z position is the clock divided by this, which keeps the offset that the
    /// shaders take back out small.
    static let clockScale: Float = 1000
    /// Explode's bursts, and the colour-cycling hue's turns, per loop (about 0.12 and 0.05 per second).
    private static let burstsPerLoop: Float = 75
    private static let hueTurnsPerLoop: Float = 31

    static func make(_ style: FlyingStyle, resolution: Double) -> FlyingShape {
        let r = Float(resolution.clamped(to: 0...1))
        switch style {
        case .flag: return flag(columns: 8 + Int(40 * r), rows: 6 + Int(24 * r))
        case .explode: return explode(latitudes: 8 + Int(14 * r), longitudes: 12 + Int(22 * r))
        case .ribbon: return ribbons(count: 1, samples: 60 + Int(240 * r))
        case .twoRibbons: return ribbons(count: 2, samples: 60 + Int(240 * r))
        case .splash: return splash(rings: 8 + Int(32 * r), sectors: 16 + Int(64 * r))
        case .twist: return twist(segments: 6 + Int(34 * r))
        }
    }

    /// Lights both sides of open surfaces like the flag and ribbons, and computes flat facets
    /// from screen-space derivatives when smooth shading is off.
    static let surfaceShader = """
        #pragma arguments
        float fo_flat;
        #pragma body
        float3 n = _surface.normal;
        if (fo_flat > 0.5) {
            n = normalize(cross(dfdx(_surface.position), dfdy(_surface.position)));
        }
        if (dot(n, _surface.position) > 0.0) {
            n = -n;
        }
        _surface.normal = n;
        """

    /// A style's geometry shader modifier, around its `body`. The clock reaches the shader as the
    /// z position of the object's parent node (see `FlyingObjectsScene`), because moving a node each
    /// frame costs far less CPU than updating a material's shader value. The body gets the clock
    /// as `fo_time` and the colour-cycling hue as `fo_hue_shift`. Afterwards, the node's offset is
    /// taken back out of the position.
    private static func animated(functions: String = "", body: String) -> String {
        """
        \(functions)
        #pragma arguments
        float fo_cycle;
        #pragma body
        float fo_offset = scn_node.modelTransform[3].z;
        float fo_time = fo_offset * \(clockScale);
        float fo_hue_shift = fo_cycle * fract(fo_time * \(hueTurnsPerLoop / loopLength));
        \(body)
        _geometry.position.xyz -= (scn_node.inverseModelTransform * float4(0.0, 0.0, fo_offset, 0.0)).xyz;
        """
    }

    /// Hue (0...1, wrapping) to a bright colour, shared by the coloured styles.
    private static let hueFunction = """
        float3 fo_hue(float h) {
            float3 k = fract(float3(h) + float3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0;
            return mix(float3(1.0), clamp(abs(k) - 1.0, 0.0, 1.0), 0.85);
        }
        """

    // MARK: - Flag

    /// A flag rippling in the wind, waves running from the hoist (left) to the fly end.
    private static func flag(columns: Int, rows: Int) -> FlyingShape {
        var mesh = MeshBuilder()
        mesh.grid(columns: columns, rows: rows) { u, v in
            (position: [-1.2 + 2.4 * u, -0.8 + 1.6 * v, 0], uv: CGPoint(x: CGFloat(u), y: CGFloat(1 - v)))
        }
        let shader = animated(body: """
            float x = _geometry.position.x;
            float y = _geometry.position.y;
            float along = (x + 1.2) / 2.4;
            float a = 0.22 * along;
            float p1 = 3.2 * x - 3.0 * fo_time;
            float p2 = 2.1 * y + 2.0 * x - 2.3 * fo_time;
            _geometry.position.z = a * sin(p1) + 0.35 * a * sin(p2);
            float dzdx = (0.22 / 2.4) * (sin(p1) + 0.35 * sin(p2)) + a * (3.2 * cos(p1) + 0.35 * 2.0 * cos(p2));
            float dzdy = 0.35 * a * 2.1 * cos(p2);
            _geometry.normal = normalize(float3(-dzdx, -dzdy, 1.0));
            """)
        return FlyingShape(geometry: mesh.geometry(extent: 1.5), shader: shader, extent: 1.5)
    }

    // MARK: - Ribbons

    /// Closed ribbon loops twisting along a slowly changing Lissajous curve, rainbow along their length.
    private static func ribbons(count: Int, samples: Int) -> FlyingShape {
        var mesh = MeshBuilder()
        for ribbon in 0..<count {
            // Position carries (how far along, which edge, which ribbon); the shader does the rest.
            mesh.grid(columns: samples, rows: 1) { u, v in
                (position: [u, v * 2 - 1, Float(ribbon)], uv: .zero)
            }
        }
        let functions = """
            \(hueFunction)
            float3 fo_curve(float s, float t, float ribbon) {
                float a = 6.2831853 * s;
                return float3(sin(2.0 * a + 0.40 * t + ribbon),
                              0.8 * sin(3.0 * a + 0.31 * t + 1.7 * ribbon),
                              0.9 * sin(a + 0.53 * t + 0.9 * ribbon) + 0.3 * cos(2.0 * a + 0.2 * t));
            }
            """
        let shader = animated(functions: functions, body: """
            float s = _geometry.position.x;
            float w = _geometry.position.y;
            float ribbon = _geometry.position.z;
            float t = fo_time + ribbon * 2.7;
            float3 center = fo_curve(s, t, ribbon);
            float3 tangent = normalize(fo_curve(s + 0.002, t, ribbon) - fo_curve(s - 0.002, t, ribbon));
            float twist = 6.2831853 * 2.0 * s + 1.3 * t;
            float3 reference = float3(cos(twist), sin(0.5 * twist + t), sin(twist));
            float3 side = normalize(cross(tangent, reference));
            _geometry.position.xyz = center + side * w * 0.16;
            _geometry.normal = normalize(cross(side, tangent));
            _geometry.color = float4(fo_hue(s + fo_hue_shift + 0.5 * ribbon), 1.0);
            """)
        return FlyingShape(geometry: mesh.geometry(extent: 1.6), shader: shader, extent: 1.6)
    }

    // MARK: - Splash

    /// A disc rippling outwards like water where a drop has landed, in rings of colour.
    private static func splash(rings: Int, sectors: Int) -> FlyingShape {
        var mesh = MeshBuilder()
        mesh.grid(columns: sectors, rows: rings) { u, v in
            let angle = u * 2 * .pi
            return (position: [v * cos(angle), v * sin(angle), 0], uv: .zero)
        }
        let shader = animated(functions: hueFunction, body: """
            float r = length(_geometry.position.xy);
            float2 outward = r > 0.0001 ? _geometry.position.xy / r : float2(1.0, 0.0);
            float wave = 7.0 * r - 3.5 * fo_time;
            float envelope = exp(-1.6 * r);
            _geometry.position.z = 0.28 * envelope * sin(wave);
            float slope = 0.28 * envelope * (7.0 * cos(wave) - 1.6 * sin(wave));
            _geometry.normal = normalize(float3(-slope * outward, 1.0));
            _geometry.color = float4(fo_hue(0.8 * r + fo_hue_shift), 1.0);
            """)
        return FlyingShape(geometry: mesh.geometry(extent: 1.05), shader: shader, extent: 1.05)
    }

    // MARK: - Twist

    /// A five-pointed star column that twists back and forth along its length, each side its own colour.
    private static func twist(segments: Int) -> FlyingShape {
        var mesh = MeshBuilder()
        let points = 10
        let outline: [SIMD2<Float>] = (0..<points).map { k in
            let angle = Float(k) / Float(points) * 2 * .pi
            let radius: Float = k % 2 == 0 ? 0.55 : 0.25
            return [radius * cos(angle), radius * sin(angle)]
        }
        for k in 0..<points {
            let a = outline[k]
            let b = outline[(k + 1) % points]
            let edge = b - a
            let normal = simd_normalize(SIMD3<Float>(edge.y, 0, -edge.x))
            let hue = Float(k) / Float(points)
            mesh.grid(columns: 1, rows: segments, normal: normal, color: [hue, 0, 0, 1]) { u, v in
                let point = a + (b - a) * u
                return (position: [point.x, -1 + 2 * v, point.y], uv: .zero)
            }
        }
        for (y, normal) in [(Float(1), SIMD3<Float>(0, 1, 0)), (Float(-1), SIMD3<Float>(0, -1, 0))] {
            let center = mesh.add([0, y, 0], normal: normal, color: [0.55, 0, 0, 1])
            let rim = outline.map { mesh.add([$0.x, y, $0.y], normal: normal, color: [0.55, 0, 0, 1]) }
            for k in 0..<points {
                mesh.triangle(center, rim[k], rim[(k + 1) % points])
            }
        }
        let shader = animated(functions: hueFunction, body: """
            float angle = 2.4 * sin(0.7 * fo_time) * _geometry.position.y;
            float c = cos(angle);
            float s = sin(angle);
            float3 p = _geometry.position.xyz;
            _geometry.position.xyz = float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
            float3 n = _geometry.normal;
            _geometry.normal = float3(c * n.x + s * n.z, n.y, -s * n.x + c * n.z);
            _geometry.color = float4(fo_hue(_geometry.color.r + fo_hue_shift), 1.0);
            """)
        return FlyingShape(geometry: mesh.geometry(extent: 1.15), shader: shader, extent: 1.15)
    }

    // MARK: - Explode

    /// A faceted sphere that bursts apart, its facets tumbling outwards, then pulls back together.
    private static func explode(latitudes: Int, longitudes: Int) -> FlyingShape {
        var mesh = MeshBuilder()
        var rng = SplitMix64(seed: 5)
        let radius: Float = 0.8
        func point(_ latitude: Int, _ longitude: Int) -> SIMD3<Float> {
            let polar = Float(latitude) / Float(latitudes) * .pi
            let azimuth = Float(longitude) / Float(longitudes) * 2 * .pi
            return radius * SIMD3(sin(polar) * cos(azimuth), cos(polar), sin(polar) * sin(azimuth))
        }
        for latitude in 0..<latitudes {
            for longitude in 0..<longitudes {
                let corners = [point(latitude, longitude), point(latitude + 1, longitude),
                               point(latitude + 1, longitude + 1), point(latitude, longitude + 1)]
                for triangle in [[0, 1, 2], [0, 2, 3]] {
                    let vertices = triangle.map { corners[$0] }
                    let center = (vertices[0] + vertices[1] + vertices[2]) / 3
                    guard simd_length(simd_cross(vertices[1] - vertices[0], vertices[2] - vertices[0])) > 1e-6 else { continue }
                    // The colour carries the facet's centre (mapped into 0...1) and a random seed.
                    let packed = SIMD4<Float>(center / (2 * radius) + 0.5, Float.random(in: 0..<1, using: &rng))
                    let indices = vertices.map { mesh.add($0, normal: simd_normalize(center), color: packed) }
                    mesh.triangle(indices[0], indices[1], indices[2])
                }
            }
        }
        let shader = animated(functions: hueFunction, body: """
            float3 center = (_geometry.color.rgb - 0.5) * \(2 * radius);
            float seed = _geometry.color.a;
            float cycle = fract(fo_time * \(burstsPerLoop / loopLength));
            float burst = smoothstep(0.0, 0.25, cycle) * (1.0 - smoothstep(0.55, 0.85, cycle));
            float3 axis = normalize(cross(center, float3(0.3, 1.0, 0.2)) + float3(0.001));
            float angle = burst * (seed - 0.5) * 9.0;
            float c = cos(angle);
            float s = sin(angle);
            float3 local = _geometry.position.xyz - center;
            local = local * c + cross(axis, local) * s + axis * dot(axis, local) * (1.0 - c);
            float3 n = _geometry.normal;
            n = n * c + cross(axis, n) * s + axis * dot(axis, n) * (1.0 - c);
            _geometry.position.xyz = center * (1.0 + burst * (0.4 + 0.6 * seed)) + local;
            _geometry.normal = n;
            _geometry.color = float4(fo_hue(0.35 * center.y + 0.5 + fo_hue_shift), 1.0);
            """)
        return FlyingShape(geometry: mesh.geometry(extent: 1.6), shader: shader, extent: 1.6)
    }
}

/// Collects vertices (with optional colour and texture coordinates) and triangles into one geometry.
private struct MeshBuilder {
    private var positions: [SCNVector3] = []
    private var normals: [SCNVector3] = []
    private var colors: [SIMD4<Float>] = []
    private var textureCoordinates: [CGPoint] = []
    private var indices: [UInt32] = []

    @discardableResult
    mutating func add(_ position: SIMD3<Float>, normal: SIMD3<Float> = [0, 0, 1], color: SIMD4<Float> = [1, 1, 1, 1], uv: CGPoint = .zero) -> UInt32 {
        positions.append(SCNVector3(position))
        normals.append(SCNVector3(normal))
        colors.append(color)
        textureCoordinates.append(uv)
        return UInt32(positions.count - 1)
    }

    mutating func triangle(_ a: UInt32, _ b: UInt32, _ c: UInt32) {
        indices += [a, b, c]
    }

    /// A (columns + 1) × (rows + 1) grid of vertices over u, v in 0...1, triangulated.
    mutating func grid(columns: Int, rows: Int, normal: SIMD3<Float> = [0, 0, 1], color: SIMD4<Float> = [1, 1, 1, 1],
                       vertex: (Float, Float) -> (position: SIMD3<Float>, uv: CGPoint)) {
        let first = UInt32(positions.count)
        for row in 0...rows {
            for column in 0...columns {
                let point = vertex(Float(column) / Float(columns), Float(row) / Float(rows))
                add(point.position, normal: normal, color: color, uv: point.uv)
            }
        }
        let stride = UInt32(columns + 1)
        for row in 0..<UInt32(rows) {
            for column in 0..<UInt32(columns) {
                let a = first + row * stride + column
                triangle(a, a + 1, a + stride)
                triangle(a + 1, a + stride + 1, a + stride)
            }
        }
    }

    /// The shaders move the vertices, so tell SceneKit the whole space the shape can reach. That
    /// includes the clock node's offset, which the shader takes back out: up to about 2.3 units at
    /// the smallest size.
    func geometry(extent: Float) -> SCNGeometry {
        let colorSource = SCNGeometrySource(
            data: colors.withUnsafeBytes { Data($0) }, semantic: .color, vectorCount: colors.count,
            usesFloatComponents: true, componentsPerVector: 4, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: positions),
                SCNGeometrySource(normals: normals),
                colorSource,
                SCNGeometrySource(textureCoordinates: textureCoordinates),
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        let reach = extent + 3
        geometry.boundingBox = (min: SCNVector3(-reach, -reach, -reach), max: SCNVector3(reach, reach, reach))
        return geometry
    }
}
