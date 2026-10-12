// Draws the Flower app icon (1024×1024 PNG).
//   swift scripts/make-icon.swift Resources/AppIcon.png
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func linear(_ colors: [CGColor], in rect: CGRect, from: CGPoint, to: CGPoint, clip path: CGPath) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

// Background tile on Apple's macOS icon grid: 824pt body, ~185pt corner radius, soft drop shadow.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.28))
ctx.addPath(tilePath)
ctx.setFillColor(color(0xFFFFFF))
ctx.fillPath()
ctx.restoreGState()
linear([color(0xFFF6E9), color(0xFFE1E8)], in: tile, from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100), clip: tilePath)

let center = CGPoint(x: 512, y: 580)

// Stem and leaf.
ctx.saveGState()
ctx.setStrokeColor(color(0x4FA56B))
ctx.setLineWidth(30)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 512, y: 420))
ctx.addCurve(to: CGPoint(x: 500, y: 175), control1: CGPoint(x: 520, y: 340), control2: CGPoint(x: 490, y: 250))
ctx.strokePath()
let leaf = CGMutablePath()
leaf.move(to: CGPoint(x: 505, y: 250))
leaf.addCurve(to: CGPoint(x: 680, y: 330), control1: CGPoint(x: 560, y: 340), control2: CGPoint(x: 640, y: 350))
leaf.addCurve(to: CGPoint(x: 505, y: 250), control1: CGPoint(x: 650, y: 260), control2: CGPoint(x: 570, y: 230))
linear([color(0x7DD39A), color(0x3E9A5C)], in: tile, from: CGPoint(x: 680, y: 330), to: CGPoint(x: 505, y: 250), clip: leaf)
ctx.restoreGState()

// Petals: two rings for depth.
func petals(count: Int, length: CGFloat, width: CGFloat, rotation: CGFloat, colors: [CGColor]) {
    for i in 0..<count {
        let angle = rotation + CGFloat(i) * 2 * .pi / CGFloat(count)
        var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
        let petal = CGMutablePath()
        petal.move(to: .zero)
        petal.addCurve(to: CGPoint(x: 0, y: length), control1: CGPoint(x: width, y: length * 0.35), control2: CGPoint(x: width * 0.75, y: length))
        petal.addCurve(to: .zero, control1: CGPoint(x: -width * 0.75, y: length), control2: CGPoint(x: -width, y: length * 0.35))
        let path = petal.copy(using: &t)!
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0xB0305A, 0.25))
        ctx.addPath(path)
        ctx.setFillColor(colors.last!)
        ctx.fillPath()
        ctx.restoreGState()
        let tip = CGPoint(x: center.x - sin(angle) * length, y: center.y + cos(angle) * length)
        linear(colors, in: tile, from: tip, to: center, clip: path)
    }
}
petals(count: 6, length: 255, width: 135, rotation: .pi / 6, colors: [color(0xFFB3C7), color(0xF06292)])
petals(count: 6, length: 200, width: 105, rotation: 0, colors: [color(0xFFD6E0), color(0xF48FB1)])

// Center.
let disc = CGPath(ellipseIn: CGRect(x: center.x - 82, y: center.y - 82, width: 164, height: 164), transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: color(0x8A4B00, 0.35))
ctx.addPath(disc)
ctx.setFillColor(color(0xFFB300))
ctx.fillPath()
ctx.restoreGState()
linear([color(0xFFE082), color(0xFFA000)], in: tile, from: CGPoint(x: center.x - 60, y: center.y + 80), to: CGPoint(x: center.x + 60, y: center.y - 80), clip: disc)
for i in 0..<10 {
    let a = CGFloat(i) * 2 * .pi / 10
    let r: CGFloat = i % 2 == 0 ? 44 : 24
    ctx.setFillColor(color(0xC77700, 0.55))
    ctx.fillEllipse(in: CGRect(x: center.x + cos(a) * r - 9, y: center.y + sin(a) * r - 9, width: 18, height: 18))
}

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
