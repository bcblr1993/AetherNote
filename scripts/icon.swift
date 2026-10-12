import AppKit
let output = CommandLine.arguments[1]
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let bg = NSBezierPath(roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900), xRadius: 208, yRadius: 208)
NSGradient(colors: [NSColor(calibratedRed: 0.13, green: 0.4, blue: 0.5, alpha: 1), NSColor(calibratedRed: 0.6, green: 0.83, blue: 0.79, alpha: 1)])!.draw(in: bg, angle: 65)
let rope = NSBezierPath(); rope.move(to: NSPoint(x: 128, y: 754)); rope.curve(to: NSPoint(x: 896, y: 754), controlPoint1: NSPoint(x: 340, y: 670), controlPoint2: NSPoint(x: 650, y: 670)); rope.lineWidth = 9; rope.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.7).setStroke(); rope.stroke()
for (x, y, angle) in [(235.0, 360.0, -9.0), (414.0, 283.0, 0.0), (612.0, 364.0, 10.0)] {
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform(); t.translateX(by: x + 92, yBy: y + 320); t.concat()
    let r = NSAffineTransform(); r.rotate(byDegrees: angle); r.concat()
    let card = NSBezierPath(roundedRect: NSRect(x: -98, y: -310, width: 196, height: 306), xRadius: 24, yRadius: 24)
    let shadow = NSShadow(); shadow.shadowColor = .black.withAlphaComponent(0.16); shadow.shadowBlurRadius = 20; shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.set()
    NSColor.white.withAlphaComponent(0.85).setFill(); card.fill()
    NSShadow().set(); NSColor.white.withAlphaComponent(0.8).setStroke(); card.lineWidth = 2; card.stroke()
    NSColor(calibratedRed: 0.87, green: 0.68, blue: 0.38, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: -11, y: -20, width: 22, height: 65), xRadius: 8, yRadius: 8).fill()
    for (line, width) in [(70.0, 115.0), (109.0, 95.0), (148.0, 112.0), (187.0, 72.0)] {
        NSColor(calibratedRed: 0.2, green: 0.43, blue: 0.48, alpha: 0.35).setFill()
        NSBezierPath(roundedRect: NSRect(x: -62, y: -line - 12, width: width, height: 10), xRadius: 5, yRadius: 5).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
