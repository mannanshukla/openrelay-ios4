import AppKit
// Wraps a 640x960 screenshot in an iPod touch 4th-gen style frame (black glass, chrome edge, home button, glossy reflection).
let args = CommandLine.arguments
let inPath = args[1], outPath = args[2]
let shot = NSImage(contentsOfFile: inPath)!
let shotRep = NSBitmapImageRep(data: shot.tiffRepresentation!)!
let sw = CGFloat(shotRep.pixelsWide), sh = CGFloat(shotRep.pixelsHigh)   // 640 x 960
let bezelX: CGFloat = 70, bezelTop: CGFloat = 150, bezelBottom: CGFloat = 170
let W = Int(sw + 2*bezelX), H = Int(sh + bezelTop + bezelBottom)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
let body = NSRect(x: 0, y: 0, width: CGFloat(W), height: CGFloat(H))
// chrome rim
let rim = NSBezierPath(roundedRect: body, xRadius: 100, yRadius: 100)
NSGradient(starting: NSColor(white: 0.85, alpha: 1), ending: NSColor(white: 0.45, alpha: 1))!.draw(in: rim, angle: -90)
// black glass face
let face = NSBezierPath(roundedRect: body.insetBy(dx: 6, dy: 6), xRadius: 95, yRadius: 95)
NSGradient(starting: NSColor(white: 0.12, alpha: 1), ending: NSColor(white: 0.02, alpha: 1))!.draw(in: face, angle: -90)
// screen (flip y: AppKit origin bottom-left)
let screen = NSRect(x: bezelX, y: bezelBottom, width: sw, height: sh)
shot.draw(in: screen, from: .zero, operation: .sourceOver, fraction: 1)
NSColor(white: 0, alpha: 0.6).setStroke(); NSBezierPath(rect: screen).stroke()
// home button
let hb = NSRect(x: CGFloat(W)/2 - 56, y: 30, width: 112, height: 112)
let hbPath = NSBezierPath(ovalIn: hb)
NSGradient(starting: NSColor(white: 0.10, alpha: 1), ending: NSColor(white: 0.22, alpha: 1))!.draw(in: hbPath, angle: -90)
NSColor(white: 0.35, alpha: 1).setStroke(); hbPath.lineWidth = 2; hbPath.stroke()
let sq = NSBezierPath(roundedRect: NSRect(x: hb.midX - 22, y: hb.midY - 22, width: 44, height: 44), xRadius: 8, yRadius: 8)
NSColor(white: 0.55, alpha: 1).setStroke(); sq.lineWidth = 3; sq.stroke()
// front camera dot
let cam = NSBezierPath(ovalIn: NSRect(x: CGFloat(W)/2 - 10, y: CGFloat(H) - 92, width: 20, height: 20))
NSColor(white: 0.16, alpha: 1).setFill(); cam.fill()
// glass gloss sweep
ctx.saveGState()
face.addClip()
let gloss = NSBezierPath(); gloss.move(to: NSPoint(x: 0, y: CGFloat(H))); gloss.line(to: NSPoint(x: CGFloat(W), y: CGFloat(H))); gloss.line(to: NSPoint(x: CGFloat(W), y: CGFloat(H)*0.72)); gloss.line(to: NSPoint(x: 0, y: CGFloat(H)*0.58)); gloss.close()
NSGradient(starting: NSColor(white: 1, alpha: 0.10), ending: NSColor(white: 1, alpha: 0.0))!.draw(in: gloss, angle: -90)
ctx.restoreGState()
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("framed", outPath, W, H)
