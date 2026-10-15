import SceneKit

/// The screen as a grid of glyph cells: one quad per cell, which never moves, and the geometry
/// shader modifier that lights the cells and picks their glyphs.
///
/// The glyphs don't fall: each column's stream is a lit stretch of cells whose head steps down a
/// cell at a time, and the cells keep their glyphs, which change now and then. So the shader only
/// needs the clock to work out every cell's brightness and glyph.
enum RainGrid {
    /// The scene spans -aspect...aspect by -1...1; row 0 is at the top.
    static func geometry(rows: Int, aspect: Float) -> SCNGeometry {
        let cellHeight = 2 / Float(rows)
        let cellWidth = cellHeight * Float(GlyphAtlas.cellAspect)
        // Enough columns to fill the width, centred, the outer ones cut off by the screen's edges.
        let columns = Int((2 * aspect / cellWidth).rounded(.up))
        let left = -Float(columns) * cellWidth / 2

        var positions: [SCNVector3] = []
        var cells: [SIMD4<Float>] = []
        var indices: [UInt32] = []
        positions.reserveCapacity(rows * columns * 4)
        cells.reserveCapacity(rows * columns * 4)
        indices.reserveCapacity(rows * columns * 6)
        for row in 0..<rows {
            let top = 1 - Float(row) * cellHeight
            for column in 0..<columns {
                let x = left + Float(column) * cellWidth
                let first = UInt32(positions.count)
                for (u, v) in [(Float(0), Float(0)), (1, 0), (0, 1), (1, 1)] {
                    positions.append(SCNVector3(x + u * cellWidth, top - v * cellHeight, 0))
                    // The color carries the cell's column and row, and the corner's place in the glyph.
                    cells.append([Float(column), Float(row), u, v])
                }
                indices += [first, first + 2, first + 1, first + 1, first + 2, first + 3]
            }
        }
        let cellSource = SCNGeometrySource(
            data: cells.withUnsafeBytes { Data($0) }, semantic: .color, vectorCount: cells.count,
            usesFloatComponents: true, componentsPerVector: 4, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        // Placeholder texture coordinates: the shader sets the real ones.
        let texture = SCNGeometrySource(textureCoordinates: [CGPoint](repeating: .zero, count: positions.count))
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: positions), cellSource, texture],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        // Allow for the clock's offset in z, which the shader takes back out.
        geometry.boundingBox = (min: SCNVector3(left, -1, -1.1), max: SCNVector3(-left, 1, 0.1))
        return geometry
    }

    /// The easter egg: now and then a stream spells out one of these, top to bottom. No film quotes
    /// or names. TEAPOT is for Pipes' teapot, XYZZY is the magic word from Colossal Cave Adventure
    /// (1976), and the white rabbit is Lewis Carroll's.
    static let eggWords = ["TEAPOT", "WHITE RABBIT", "HELLO WORLD", "XYZZY", "RETRO", "1999"]
    /// One stream in this many carries a word: about one every two minutes on a laptop screen.
    static let eggOdds = 1024

    /// The words as indices into `GlyphAtlas.eggAlphabet` (255 is a space), for the shader.
    private static var eggTables: String {
        var letters: [Int] = []
        var starts: [Int] = []
        for word in eggWords {
            starts.append(letters.count)
            letters += word.map { GlyphAtlas.eggAlphabet.firstIndex(of: $0) ?? 255 }
        }
        func list(_ values: [Int]) -> String { values.map(String.init).joined(separator: ", ") }
        return """
            constant ushort dr_egg_letters[] = { \(list(letters)) };
            constant ushort dr_egg_starts[] = { \(list(starts)) };
            constant ushort dr_egg_lengths[] = { \(list(eggWords.map(\.count))) };
            """
    }

    /// The clock is the rain node's z position: ticks / 2^24, which a float holds exactly (see
    /// `DigitalRainScene`). The vertices are moved back to z = 0.
    ///
    /// `dr_grid` is (rows on screen, the rain's glyphs, glyph columns and rows in the texture).
    /// `dr_rain` is (shortest step in ticks, how many step lengths, gap scale, seed).
    /// `dr_color` is the rain's color, linear.
    /// `dr_egg` is (one stream in how many carries a word, where the egg's alphabet starts).
    static let shader = """
        \(eggTables)
        uint dr_hash(uint x) {
            x ^= x >> 16;
            x *= 0x7feb352du;
            x ^= x >> 15;
            x *= 0x846ca68bu;
            x ^= x >> 16;
            return x;
        }
        #pragma arguments
        float4 dr_grid;
        float4 dr_rain;
        float4 dr_color;
        float4 dr_egg;
        #pragma body
        float offset = scn_node.modelTransform[3].z;
        uint ticks = uint(offset * 16777216.0 + 0.5);
        uint column = uint(_geometry.color.r + 0.5);
        uint row = uint(_geometry.color.g + 0.5);
        float2 corner = _geometry.color.ba;
        uint seed = uint(dr_rain.w);
        uint rows = uint(dr_grid.x);

        // Each column has one stream: its head steps down a cell every `interval` ticks, followed
        // by `trail` lit cells, then a gap before the next head. Rows past the bottom are off screen.
        uint h = dr_hash(column * 0x9E3779B9u ^ seed);
        uint interval = uint(dr_rain.x) + h % uint(dr_rain.y);
        uint trail = rows / 4u + (h >> 8) % (rows + 1u);
        uint gap = uint(float((h >> 20) & 0xFFFu) / 4095.0 * dr_rain.z * float(rows));
        uint period = rows + trail + gap;
        uint position = dr_hash(h) % period + ticks / interval;
        uint head = position % period;
        uint behind = (head + period - row) % period;
        float brightness = behind < trail ? 1.0 - float(behind) / float(trail) : 0.0;

        // Each cell shows a random glyph, which changes now and then; a few cells flicker.
        uint cell = dr_hash(column * 0x85EBCA6Bu + row * 0xC2B2AE35u + seed);
        uint every = (cell >> 24) < 16u ? 2u + cell % 4u : 20u + cell % 160u;
        uint version = (ticks + (cell >> 8) % every) / every;
        uint glyph = dr_hash(cell ^ (version * 0x27D4EB2Fu)) % uint(dr_grid.y);

        // The easter egg: now and then, one pass of a stream spells out a word on the way down.
        uint egg = dr_hash(h ^ ((position / period) * 0x2545F491u));
        if (egg % uint(dr_egg.x) == 0u) {
            uint word = (egg >> 12) % \(eggWords.count)u;
            uint length = dr_egg_lengths[word];
            if (length <= rows) {
                uint top = (egg >> 20) % (rows - length + 1u);
                if (row >= top && row < top + length) {
                    uint letter = dr_egg_letters[dr_egg_starts[word] + row - top];
                    if (letter == 255u) {
                        brightness = 0.0;
                    } else {
                        glyph = uint(dr_egg.y) + letter;
                    }
                }
            }
        }
        uint glyphColumns = uint(dr_grid.z);
        _geometry.texcoords[0] = (float2(float(glyph % glyphColumns), float(glyph / glyphColumns)) + corner) / dr_grid.zw;

        // Some glyphs shine a little brighter than their neighbours; the head is nearly white.
        brightness *= 0.75 + 0.5 * float(dr_hash(cell ^ version) & 0xFFu) / 255.0;
        float3 color = dr_color.rgb * min(brightness, 1.0);
        if (behind == 0u) {
            color = mix(dr_color.rgb, float3(1.0), 0.8);
        }
        _geometry.color = float4(color, 1.0);
        _geometry.position.z -= offset;
        """
}
