import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appending(path: "Resources/NotesTaker.iconset", directoryHint: .isDirectory)
let icnsURL = root.appending(path: "Resources/NotesTaker.icns")

try? FileManager.default.removeItem(at: iconsetURL)
try? FileManager.default.removeItem(at: icnsURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in sizes {
    let image = drawIcon(size: size)
    let url = iconsetURL.appending(path: name)
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not encode \(name)")
    }
    try png.write(to: url)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fatalError("iconutil failed")
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let scale = size / 1024
    func r(_ value: CGFloat) -> CGFloat { value * scale }

    let tile = CGRect(x: r(64), y: r(64), width: r(896), height: r(896))
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: r(210), yRadius: r(210))
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.05, green: 0.10, blue: 0.19, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.34, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.70, blue: 0.72, alpha: 1)
    ])!
    gradient.draw(in: tilePath, angle: 135)

    NSColor.white.withAlphaComponent(0.14).setStroke()
    tilePath.lineWidth = r(8)
    tilePath.stroke()

    let sheet = CGRect(x: r(284), y: r(238), width: r(456), height: r(548))
    let sheetPath = NSBezierPath(roundedRect: sheet, xRadius: r(54), yRadius: r(54))
    NSColor(calibratedRed: 0.96, green: 0.99, blue: 0.98, alpha: 1).setFill()
    sheetPath.fill()

    let fold = NSBezierPath()
    fold.move(to: CGPoint(x: sheet.maxX - r(116), y: sheet.maxY))
    fold.line(to: CGPoint(x: sheet.maxX, y: sheet.maxY - r(116)))
    fold.line(to: CGPoint(x: sheet.maxX - r(104), y: sheet.maxY - r(104)))
    fold.close()
    NSColor(calibratedRed: 0.78, green: 0.92, blue: 0.94, alpha: 1).setFill()
    fold.fill()

    drawLine(x: r(364), y: r(648), width: r(248), height: r(26), radius: r(13), color: .navy)
    drawLine(x: r(364), y: r(570), width: r(296), height: r(22), radius: r(11), color: .muted)
    drawLine(x: r(364), y: r(508), width: r(244), height: r(22), radius: r(11), color: .muted)

    let micRect = CGRect(x: r(428), y: r(312), width: r(168), height: r(214))
    let mic = NSBezierPath(roundedRect: micRect, xRadius: r(82), yRadius: r(82))
    NSColor.tealAccent.setFill()
    mic.fill()

    let micInner = NSBezierPath(roundedRect: micRect.insetBy(dx: r(42), dy: r(42)), xRadius: r(44), yRadius: r(44))
    NSColor.white.withAlphaComponent(0.28).setFill()
    micInner.fill()

    let stem = NSBezierPath(roundedRect: CGRect(x: r(498), y: r(238), width: r(28), height: r(94)), xRadius: r(14), yRadius: r(14))
    NSColor.tealAccent.setFill()
    stem.fill()
    let base = NSBezierPath(roundedRect: CGRect(x: r(428), y: r(220), width: r(168), height: r(32)), xRadius: r(16), yRadius: r(16))
    base.fill()

    drawWave(x: r(224), y: r(398), heights: [58, 112, 164, 94], scale: scale)
    drawWave(x: r(750), y: r(398), heights: [94, 164, 112, 58], scale: scale)

    return image
}

func drawLine(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat, color: NSColor) {
    let path = NSBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
}

func drawWave(x: CGFloat, y: CGFloat, heights: [CGFloat], scale: CGFloat) {
    for (index, height) in heights.enumerated() {
        let line = NSBezierPath(roundedRect: CGRect(x: x + CGFloat(index) * 34 * scale, y: y - height * scale / 2, width: 16 * scale, height: height * scale), xRadius: 8 * scale, yRadius: 8 * scale)
        NSColor.white.withAlphaComponent(0.72).setFill()
        line.fill()
    }
}

private extension NSColor {
    static let navy = NSColor(calibratedRed: 0.055, green: 0.098, blue: 0.176, alpha: 1)
    static let muted = NSColor(calibratedRed: 0.42, green: 0.50, blue: 0.59, alpha: 1)
    static let tealAccent = NSColor(calibratedRed: 0.02, green: 0.76, blue: 0.78, alpha: 1)
}
