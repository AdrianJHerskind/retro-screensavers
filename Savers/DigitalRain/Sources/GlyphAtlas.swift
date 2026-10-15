import AppKit
import CoreText

/// The glyphs, drawn once into a texture: white on black, each in its own cell with a soft glow
/// baked in, so the glow costs nothing while the rain runs. The shader picks a cell for each
/// glyph on screen.
///
/// After the rain's own glyphs come the easter egg's letters and digits, always the right way
/// round, so its words are readable (see `RainGrid.eggWords`).
struct GlyphAtlas {
    let image: CGImage
    /// The rain's own glyphs, which come first.
    let glyphCount: Int
    /// Where the easter egg's alphabet starts.
    let eggStart: Int
    /// Cells per row, and rows, in the texture.
    let columns: Int
    let rows: Int

    /// Width over height of a glyph cell, in the texture and on screen.
    static let cellAspect = 0.72
    private static let cellHeight = 96
    private static let cellWidth = Int((Double(cellHeight) * cellAspect).rounded())
    /// Hiragino Sans ships with every Mac and has half-width katakana.
    private static let fontName = "HiraginoSans-W6"
    static let eggAlphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    init(_ characters: RainCharacters) {
        let glyphs = Array(characters.glyphs) + Self.eggAlphabet
        columns = 10
        rows = (glyphs.count + columns - 1) / columns
        glyphCount = glyphs.count - Self.eggAlphabet.count
        eggStart = glyphCount
        let width = columns * Self.cellWidth
        let height = rows * Self.cellHeight
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = CTFontCreateWithName(Self.fontName as CFString, CGFloat(Self.cellHeight) * 0.8, nil)
        for (index, character) in glyphs.enumerated() {
            // The first glyph goes top left, like the texture coordinates.
            let cell = CGRect(x: index % columns * Self.cellWidth, y: height - (index / columns + 1) * Self.cellHeight,
                              width: Self.cellWidth, height: Self.cellHeight)
            let line = CTLineCreateWithAttributedString(NSAttributedString(
                string: String(character), attributes: [.font: font, .foregroundColor: NSColor.white]))
            let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            context.saveGState()
            // Keep each glow inside its own cell, with a pixel to spare for the texture filtering.
            context.clip(to: cell.insetBy(dx: 1, dy: 1))
            context.translateBy(x: cell.midX, y: cell.midY)
            if characters.isMirrored, index < glyphCount {
                context.scaleBy(x: -1, y: 1)
            }
            context.setShadow(offset: .zero, blur: CGFloat(Self.cellHeight) * 0.1, color: CGColor(gray: 1, alpha: 0.85))
            context.textPosition = CGPoint(x: -ink.midX, y: -ink.midY)
            CTLineDraw(line, context)
            context.restoreGState()
        }
        image = context.makeImage()!
    }
}
