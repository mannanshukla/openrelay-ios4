import AppKit
func draw(_ size: Int, _ path: String) {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    let g = NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.95, alpha: 1), ending: NSColor(calibratedRed: 0.05, green: 0.18, blue: 0.55, alpha: 1))!
    g.draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: -90)
    // chat bubble
    let bw = s*0.70, bh = s*0.46
    let bubble = NSBezierPath(roundedRect: NSRect(x: (s-bw)/2, y: s*0.30, width: bw, height: bh), xRadius: s*0.12, yRadius: s*0.12)
    NSColor.white.withAlphaComponent(0.95).setFill(); bubble.fill()
    let tail = NSBezierPath(); tail.move(to: NSPoint(x: s*0.30, y: s*0.33)); tail.line(to: NSPoint(x: s*0.24, y: s*0.20)); tail.line(to: NSPoint(x: s*0.42, y: s*0.30)); tail.close(); tail.fill()
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: s*0.26), .foregroundColor: NSColor(calibratedRed: 0.08, green: 0.25, blue: 0.70, alpha: 1), .paragraphStyle: para]
    ("OR" as NSString).draw(in: NSRect(x: 0, y: s*0.36, width: s, height: s*0.36), withAttributes: attrs)
    img.unlockFocus()
    let tiff = img.tiffRepresentation!, rep = NSBitmapImageRep(data: tiff)!
    rep.size = NSSize(width: s, height: s)
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
}
draw(57, "Icon.png"); draw(114, "Icon@2x.png")
print("icons ok")
