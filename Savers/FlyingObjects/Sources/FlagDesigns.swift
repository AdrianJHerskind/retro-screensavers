import AppKit

/// The flag's pictures. The Windows original waved the Windows logo; ours waves its own designs.
enum FlagDesigns {
    static func image(_ design: FlagDesign) -> CGImage {
        switch design {
        case .sunset: return sunset()
        case .checkered: return checkered()
        case .marble: return RetroTexture.marble.makeImage()
        case .wood: return RetroTexture.wood.makeImage()
        case .granite: return RetroTexture.granite.makeImage()
        }
    }

    /// A synthwave sunset: a striped sun sinking into a neon grid under a purple sky.
    private static func sunset(width: Int = 600, height: Int = 400) -> CGImage {
        let context = makeContext(width: width, height: height)
        let w = CGFloat(width)
        let h = CGFloat(height)
        // Core Graphics draws from the bottom up; the horizon sits 40% up from the bottom.
        let horizon = h * 0.4
        let space = CGColorSpace(name: CGColorSpace.sRGB)!

        let sky = CGGradient(colorsSpace: space, colors: [
            NSColor(srgbRed: 1, green: 0.55, blue: 0.2, alpha: 1).cgColor,
            NSColor(srgbRed: 0.85, green: 0.2, blue: 0.55, alpha: 1).cgColor,
            NSColor(srgbRed: 0.12, green: 0.05, blue: 0.3, alpha: 1).cgColor,
        ] as CFArray, locations: [0, 0.45, 1])!
        context.drawLinearGradient(sky, start: CGPoint(x: 0, y: horizon), end: CGPoint(x: 0, y: h), options: [])

        // The sun, cut by bands that widen towards the horizon.
        let sunRadius = h * 0.3
        let sunCenter = CGPoint(x: w / 2, y: horizon + sunRadius * 0.35)
        context.saveGState()
        context.addEllipse(in: CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2))
        context.addRect(CGRect(x: 0, y: horizon, width: w, height: h - horizon))
        context.clip(using: .evenOdd)
        context.restoreGState()
        context.saveGState()
        context.addEllipse(in: CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2))
        context.clip()
        let sun = CGGradient(colorsSpace: space, colors: [
            NSColor(srgbRed: 1, green: 0.3, blue: 0.5, alpha: 1).cgColor,
            NSColor(srgbRed: 1, green: 0.85, blue: 0.3, alpha: 1).cgColor,
        ] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(sun, start: CGPoint(x: 0, y: sunCenter.y - sunRadius), end: CGPoint(x: 0, y: sunCenter.y + sunRadius), options: [])
        context.setFillColor(NSColor(srgbRed: 0.95, green: 0.4, blue: 0.35, alpha: 1).cgColor)
        var bandTop = sunCenter.y
        for band in 0..<6 {
            let thickness = h * (0.008 + 0.006 * CGFloat(band))
            context.fill(CGRect(x: 0, y: bandTop - thickness, width: w, height: thickness))
            bandTop -= thickness + h * 0.03
        }
        context.restoreGState()

        // A dark floor with a neon grid running to the vanishing point.
        context.setFillColor(NSColor(srgbRed: 0.08, green: 0.02, blue: 0.15, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: w, height: horizon))
        context.setStrokeColor(NSColor(srgbRed: 1, green: 0.25, blue: 0.8, alpha: 1).cgColor)
        context.setLineWidth(2)
        for step in 1...7 {
            let depth = pow(CGFloat(step) / 7, 1.8)
            let y = horizon * (1 - depth)
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: w, y: y))
        }
        for column in -6...6 {
            context.move(to: CGPoint(x: w / 2, y: horizon))
            context.addLine(to: CGPoint(x: w / 2 + CGFloat(column) * w * 0.22, y: 0))
        }
        context.strokePath()
        return context.makeImage()!
    }

    /// A black and white racing flag.
    private static func checkered(width: Int = 600, height: Int = 400) -> CGImage {
        let context = makeContext(width: width, height: height)
        let columns = 9
        let rows = 6
        let cell = CGSize(width: CGFloat(width) / CGFloat(columns), height: CGFloat(height) / CGFloat(rows))
        for row in 0..<rows {
            for column in 0..<columns {
                let shade: CGFloat = (row + column) % 2 == 0 ? 0.08 : 0.95
                context.setFillColor(NSColor(white: shade, alpha: 1).cgColor)
                context.fill(CGRect(x: CGFloat(column) * cell.width, y: CGFloat(row) * cell.height, width: cell.width, height: cell.height))
            }
        }
        return context.makeImage()!
    }

    private static func makeContext(width: Int, height: Int) -> CGContext {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }
}
