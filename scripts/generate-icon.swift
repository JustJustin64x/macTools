import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for pointSize in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = pointSize * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let factor = CGFloat(size) / 1024
        let transform = NSAffineTransform()
        transform.scale(by: factor)
        transform.concat()
        let rect = NSRect(x: 68, y: 68, width: 888, height: 888)
        let background = NSBezierPath(roundedRect: rect, xRadius: 200, yRadius: 200)
        NSGradient(starting: NSColor(red: 0.29, green: 0.49, blue: 0.99, alpha: 1),
                   ending: NSColor(red: 0.12, green: 0.25, blue: 0.71, alpha: 1))!.draw(in: background, angle: -90)
        for (y, alpha) in [(300.0, 0.35), (420.0, 0.60), (540.0, 1.0)] {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 264, y: y + 100))
            path.line(to: NSPoint(x: 512, y: y + 230))
            path.line(to: NSPoint(x: 760, y: y + 100))
            path.line(to: NSPoint(x: 512, y: y - 30))
            path.close()
            NSColor.white.withAlphaComponent(alpha).setFill()
            path.fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let filename = "icon_\(pointSize)x\(pointSize)\(suffix).png"
        try rep.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(filename))
    }
}
