import AppKit
// Build an iOS 4 icon: OpenRelay glyph (keyed out of their touch icon) on their lime green.
let src = NSImage(contentsOfFile: "openrelay-logo.png")!
let srcRep = NSBitmapImageRep(data: src.tiffRepresentation!)!
let sw = srcRep.pixelsWide, sh = srcRep.pixelsHigh
// glyph alpha = luminance of source (background is black)
let glyph = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: sw, pixelsHigh: sh, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
for y in 0..<sh { for x in 0..<sw {
    let c = srcRep.colorAt(x: x, y: y)!
    let lum = 0.299*c.redComponent + 0.587*c.greenComponent + 0.114*c.blueComponent
    // dark olive glyph, alpha from luminance, keep the silver shading as slight lightness
    let shade = 0.10 + 0.25*lum
    glyph.setColor(NSColor(deviceRed: shade*0.55, green: shade*0.75, blue: shade*0.25, alpha: lum), atX: x, y: y)
}}
func draw(_ size: Int, _ path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size)
    let g = NSGradient(starting: NSColor(deviceRed: 0xC9/255.0, green: 0xF0/255.0, blue: 0x3A/255.0, alpha: 1), ending: NSColor(deviceRed: 0xAF/255.0, green: 0xE2/255.0, blue: 0x04/255.0, alpha: 1))!
    g.draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: -90)
    let gi = NSImage(size: NSSize(width: sw, height: sh)); gi.addRepresentation(glyph)
    let inset = s*0.14
    gi.draw(in: NSRect(x: inset, y: inset, width: s-2*inset, height: s-2*inset), from: .zero, operation: .sourceOver, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
draw(57, "Icon.png"); draw(114, "Icon@2x.png"); draw(256, "Icon-preview.png")
print("icons ok")
