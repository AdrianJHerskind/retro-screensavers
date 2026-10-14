import SceneKit

/// One polygon and its trail of copies: a mesh of thin quads, one per edge of each copy, and the
/// geometry shader modifier that places them.
///
/// The mesh stores no positions, only which copy, edge, end and side of the line each vertex is.
/// The shader works out where the corners were at that copy's moment from a few numbers per
/// polygon (see `MystifyScene`), so the CPU only advances those numbers each frame.
enum MystifyLines {
    static let corners = 4

    /// The scene spans -aspect...aspect by -1...1.
    static func geometry(copies: Int, aspect: Float) -> SCNGeometry {
        var positions: [SCNVector3] = []
        var copyIndices: [SIMD4<Float>] = []
        var indices: [UInt32] = []
        // Oldest copy first, so the newest is drawn on top.
        for copy in stride(from: copies - 1, through: 0, by: -1) {
            for edge in 0..<corners {
                let first = UInt32(positions.count)
                for end in 0...1 {
                    for side in [-1, 1] {
                        positions.append(SCNVector3(Float(edge), Float(end), Float(side)))
                        copyIndices.append([Float(copy), 0, 0, 1])
                    }
                }
                indices += [first, first + 1, first + 2, first + 1, first + 3, first + 2]
            }
        }
        // The copy index rides in the vertex color, which the shader then replaces with the real color.
        let copySource = SCNGeometrySource(
            data: copyIndices.withUnsafeBytes { Data($0) }, semantic: .color, vectorCount: copyIndices.count,
            usesFloatComponents: true, componentsPerVector: 4, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: positions), copySource],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        // The shader moves the vertices, so tell SceneKit the whole area they can reach. That
        // includes the clock's offset in z, which the shader takes back out (see `shader`).
        let loop = Float(MystifyScene.loopLength)
        geometry.boundingBox = (min: SCNVector3(-aspect, -1, -loop - 1), max: SCNVector3(aspect, 1, 1))
        return geometry
    }

    /// Each corner bounces between the edges along its own "phase", in screen crossings: phase
    /// 0 is one edge, 1 the other, 2 back again. The phase advances at a steady speed plus a slow
    /// wobble, so the corners speed up and slow down a little, and the shapes keep changing.
    ///
    /// The clock is the z position of the polygons' parent node (see `MystifyScene`). Each copy
    /// is that many seconds back, and the vertices are moved back to z = 0.
    ///
    /// Per polygon, for the four corners' x and y:
    /// - `my_phase_*` and `my_angle_*`: the phase and the wobble's angle at clock 0
    /// - `my_speed_*`, `my_rate_*`, `my_wobble_*`: how fast those advance, and the wobble's size
    ///
    /// `my_field` is (aspect, half the line width, seconds between copies, colors per second).
    /// `my_color_a` and `my_color_b` are the two colors (rgb) with the mode and a random seed in w.
    static let shader = """
        float my_bounce(float phase) {
            float f = fract(phase * 0.5);
            return f < 0.5 ? 4.0 * f - 1.0 : 3.0 - 4.0 * f;
        }
        // The nth of `count` random colors, fully saturated. It's an integer hash: sin-based ones
        // lose precision on the GPU, and gave both polygons the same colors.
        float3 my_random_color(float n, float count, float seed) {
            uint h = uint(n - count * floor(n / count)) * 747796405u + uint(seed) * 2891336453u;
            h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
            h = (h >> 22u) ^ h;
            float hue = float(h & 0xFFFFu) / 65536.0;
            return clamp(abs(fract(float3(hue) + float3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
        }
        #pragma arguments
        float4 my_phase_x;
        float4 my_phase_y;
        float4 my_angle_x;
        float4 my_angle_y;
        float4 my_speed_x;
        float4 my_speed_y;
        float4 my_rate_x;
        float4 my_rate_y;
        float4 my_wobble_x;
        float4 my_wobble_y;
        float4 my_field;
        float4 my_color_a;
        float4 my_color_b;
        #pragma body
        float clock = scn_node.modelTransform[3].z;
        float t = clock - _geometry.color.r * my_field.z;
        int i = int(_geometry.position.x + 0.5);
        int j = (i + 1) % 4;
        float end = _geometry.position.y;
        float side = _geometry.position.z;
        float h = my_field.y;
        float2 range = float2(my_field.x - h, 1.0 - h);

        float2 a = range * float2(
            my_bounce(my_phase_x[i] + my_speed_x[i] * t + my_wobble_x[i] * sin(my_angle_x[i] + my_rate_x[i] * t)),
            my_bounce(my_phase_y[i] + my_speed_y[i] * t + my_wobble_y[i] * sin(my_angle_y[i] + my_rate_y[i] * t)));
        float2 b = range * float2(
            my_bounce(my_phase_x[j] + my_speed_x[j] * t + my_wobble_x[j] * sin(my_angle_x[j] + my_rate_x[j] * t)),
            my_bounce(my_phase_y[j] + my_speed_y[j] * t + my_wobble_y[j] * sin(my_angle_y[j] + my_rate_y[j] * t)));
        float2 d = b - a;
        float len = length(d);
        float2 along = len > 0.00001 ? d / len : float2(1.0, 0.0);
        float2 across = float2(-along.y, along.x);
        // Square ends, so the edges meet at the corners.
        float2 p = (end > 0.5 ? b + along * h : a - along * h) + across * side * h;
        _geometry.position = float4(p, -clock, 1.0);

        float colorPhase = t * my_field.w;
        float3 color;
        if (my_color_a.w > 0.5) {
            color = mix(my_color_a.rgb, my_color_b.rgb, 0.5 - 0.5 * cos(6.2831853 * colorPhase));
        } else {
            float n = floor(colorPhase);
            float f = colorPhase - n;
            // Random colors repeat with the clock's loop, so it starts over seamlessly.
            float count = \(MystifyScene.loopLength) * my_field.w;
            color = mix(my_random_color(n, count, my_color_b.w), my_random_color(n + 1.0, count, my_color_b.w), smoothstep(0.0, 1.0, f));
        }
        _geometry.color = float4(color, 1.0);
        """
}
