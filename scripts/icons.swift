// Renders the plugin's PNG icons with SF Symbols. Usage: swift icons.swift <outdir>
import AppKit

let out = CommandLine.arguments[1]

func render(_ symbol: String, px: Int, bg: NSColor?, fg: NSColor, scale: CGFloat, to name: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    if let bg { bg.setFill(); NSRect(x: 0, y: 0, width: s, height: s).fill() }
    let cfg = NSImage.SymbolConfiguration(pointSize: s * scale, weight: .semibold)
        .applying(.init(paletteColors: [fg]))
    let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
    let r = NSRect(x: (s - img.size.width) / 2, y: (s - img.size.height) / 2, width: img.size.width, height: img.size.height)
    img.draw(in: r)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}

let live = NSColor(srgbRed: 0.13, green: 0.55, blue: 0.30, alpha: 1)
let muted = NSColor(srgbRed: 0.78, green: 0.16, blue: 0.16, alpha: 1)
for (px, suffix) in [(72, ""), (144, "@2x")] {
    render("mic.fill", px: px, bg: live, fg: .white, scale: 0.42, to: "key-live\(suffix)")
    render("mic.slash.fill", px: px, bg: muted, fg: .white, scale: 0.42, to: "key-muted\(suffix)")
}
for (px, suffix) in [(20, ""), (40, "@2x")] { render("mic.slash", px: px, bg: nil, fg: .white, scale: 0.7, to: "action\(suffix)") }
for (px, suffix) in [(28, ""), (56, "@2x")] { render("ear", px: px, bg: nil, fg: .white, scale: 0.7, to: "category\(suffix)") }
for (px, suffix) in [(256, ""), (512, "@2x")] { render("mic.slash.fill", px: px, bg: muted, fg: .white, scale: 0.42, to: "plugin\(suffix)") }
