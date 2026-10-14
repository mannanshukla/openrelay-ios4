import AppKit
// 1200x630 Open Graph card: headline left, device right, on the page's light gradient.
let W: CGFloat = 1200, H: CGFloat = 630
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGradient(starting: NSColor(deviceRed: 0.965, green: 0.969, blue: 0.976, alpha: 1), ending: NSColor(deviceRed: 0.788, green: 0.812, blue: 0.839, alpha: 1))!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)
// five devices fanned on the right, bleeding off the bottom like a 2010 hero
let names = ["radiotuner", "trainboard", "habitstoday", "setsworkout", "ball8", "bursts"]
for (i, n) in names.enumerated() {
    let dev = NSImage(contentsOfFile: "img/\(n)-device.png")!
    let dh: CGFloat = 500, dw = dev.size.width / dev.size.height * dh
    let x = W - dw - 16 - CGFloat(5 - i) * 62, y: CGFloat = -110 - CGFloat(5 - i) * 12
    let sh = NSShadow(); sh.shadowColor = NSColor(white: 0, alpha: 0.35); sh.shadowOffset = NSSize(width: -6, height: 0); sh.shadowBlurRadius = 14
    NSGraphicsContext.saveGraphicsState(); sh.set()
    dev.draw(in: NSRect(x: x, y: y, width: dw, height: dh), from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}
func text(_ s: String, _ size: CGFloat, _ bold: Bool, _ color: NSColor, _ x: CGFloat, _ y: CGFloat, _ maxW: CGFloat, _ h: CGFloat) {
    let p = NSMutableParagraphStyle(); p.lineBreakMode = .byWordWrapping
    let f = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
    let sh = NSShadow(); sh.shadowColor = NSColor.white; sh.shadowOffset = NSSize(width: 0, height: -1); sh.shadowBlurRadius = 0
    let a: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: color, .paragraphStyle: p, .shadow: sh, .kern: bold ? -1.5 : 0]
    (s as NSString).draw(in: NSRect(x: x, y: y, width: maxW, height: h), withAttributes: a)
}
text("Six native apps", 24, false, NSColor(white: 0.42, alpha: 1), 80, 530, 600, 40)
text("AI apps for\niPod touch 4.", 72, true, NSColor(white: 0.12, alpha: 1), 80, 350, 520, 176)
text("Texting, a Magic 8-Ball, a workout log,\na habit tracker, Bay Area transit\nand radio, on open models, on iOS 4.", 25, false, NSColor(white: 0.28, alpha: 1), 80, 215, 480, 120)
// badge
let badge = NSBezierPath(roundedRect: NSRect(x: 80, y: 140, width: 300, height: 44), xRadius: 7, yRadius: 7)
NSGradient(starting: NSColor(deviceRed: 0.71, green: 0.92, blue: 0.31, alpha: 1), ending: NSColor(deviceRed: 0.36, green: 0.62, blue: 0.05, alpha: 1))!.draw(in: badge, angle: -90)
NSColor(deviceRed: 0.23, green: 0.42, blue: 0.04, alpha: 1).setStroke(); badge.lineWidth = 1; badge.stroke()
let bp = NSMutableParagraphStyle(); bp.alignment = .center
let bsh = NSShadow(); bsh.shadowColor = NSColor(white: 0, alpha: 0.45); bsh.shadowOffset = NSSize(width: 0, height: 1)
("Free  ·  iOS 4.3  ·  Jailbreak required" as NSString).draw(in: NSRect(x: 80, y: 148, width: 300, height: 30), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 17), .foregroundColor: NSColor.white, .paragraphStyle: bp, .shadow: bsh])
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88])!.write(to: URL(fileURLWithPath: "img/og.jpg"))
print("og ok")
