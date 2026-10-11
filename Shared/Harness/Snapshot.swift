import AppKit

/// Offscreen rendering from the command line, to check a saver's look without opening a window:
///
///     <Harness> --snapshot out.png [--time 20] [--size 1600x1000] [--seed 1] [saver-specific flags]
///     <Harness> --thumbnails Savers/<Name>/Resources
enum Snapshot {
    static func writeSnapshot(to path: String) -> Int32 {
        let seconds = argumentValue("--time").flatMap(Double.init) ?? 20
        let seed = argumentValue("--seed").flatMap(UInt64.init) ?? 1
        var size = CGSize(width: 1600, height: 1000)
        if let dimensions = argumentValue("--size")?.split(separator: "x").compactMap({ Double($0) }), dimensions.count == 2 {
            size = CGSize(width: dimensions[0], height: dimensions[1])
        }
        guard let image = HarnessSaver.renderSnapshot(size: size, seconds: seconds, seed: seed) else {
            fputs("Rendering failed\n", stderr)
            return 1
        }
        return write(image, to: path) ? 0 : 1
    }

    /// Writes the 90x58 and 180x116 thumbnails System Settings shows for a saver.
    static func writeThumbnails(to directory: String) -> Int32 {
        let moment = HarnessSaver.thumbnailMoment
        guard let image = HarnessSaver.renderSnapshot(size: CGSize(width: 1440, height: 928), seconds: moment.seconds, seed: moment.seed) else {
            fputs("Rendering failed\n", stderr)
            return 1
        }
        let outputs = [("thumbnail.png", CGSize(width: 90, height: 58)), ("thumbnail@2x.png", CGSize(width: 180, height: 116))]
        for (name, size) in outputs {
            guard let scaled = scale(image, to: size), write(scaled, to: "\(directory)/\(name)") else { return 1 }
        }
        return 0
    }

    private static func scale(_ image: CGImage, to size: CGSize) -> CGImage? {
        let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(origin: .zero, size: size))
        return context?.makeImage()
    }

    private static func write(_ image: CGImage, to path: String) -> Bool {
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            fputs("Could not encode PNG\n", stderr)
            return false
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("Wrote \(path)")
            return true
        } catch {
            fputs("Could not write \(path): \(error.localizedDescription)\n", stderr)
            return false
        }
    }
}
