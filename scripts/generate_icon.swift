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

    let tile = CGRect(x: r(82), y: r(82), width: r(860), height: r(860))
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: r(210), yRadius: r(210))
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.96, green: 1.00, blue: 0.99, alpha: 1),
        NSColor(calibratedRed: 0.89, green: 0.98, blue: 0.99, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.99, blue: 1.00, alpha: 1)
    ])!
    gradient.draw(in: tilePath, angle: 125)

    NSColor.tealAccent.withAlphaComponent(0.26).setStroke()
    tilePath.lineWidth = r(7)
    tilePath.stroke()

    let sheet = CGRect(x: r(300), y: r(242), width: r(424), height: r(536))
    let sheetPath = NSBezierPath(roundedRect: sheet, xRadius: r(70), yRadius: r(70))
    NSColor.white.setFill()
    sheetPath.fill()
    NSColor.navy.withAlphaComponent(0.12).setStroke()
    sheetPath.lineWidth = r(5)
    sheetPath.stroke()

    let fold = NSBezierPath()
    fold.move(to: CGPoint(x: sheet.maxX - r(112), y: sheet.maxY))
    fold.line(to: CGPoint(x: sheet.maxX, y: sheet.maxY - r(112)))
    fold.line(to: CGPoint(x: sheet.maxX - r(98), y: sheet.maxY - r(98)))
    fold.close()
    NSColor(calibratedRed: 0.86, green: 0.96, blue: 0.97, alpha: 1).setFill()
    fold.fill()

    drawLine(x: r(378), y: r(650), width: r(224), height: r(18), radius: r(9), color: .navy.withAlphaComponent(0.88))
    drawLine(x: r(378), y: r(588), width: r(270), height: r(14), radius: r(7), color: .muted.withAlphaComponent(0.48))
    drawLine(x: r(378), y: r(540), width: r(196), height: r(14), radius: r(7), color: .muted.withAlphaComponent(0.42))

    let micRect = CGRect(x: r(454), y: r(344), width: r(116), height: r(152))
    let mic = NSBezierPath(roundedRect: micRect, xRadius: r(74), yRadius: r(74))
    NSColor.tealAccent.setStroke()
    mic.lineWidth = r(16)
    mic.stroke()

    let smile = NSBezierPath()
    smile.move(to: CGPoint(x: r(424), y: r(420)))
    smile.curve(to: CGPoint(x: r(600), y: r(420)), controlPoint1: CGPoint(x: r(430), y: r(312)), controlPoint2: CGPoint(x: r(594), y: r(312)))
    smile.lineWidth = r(15)
    smile.lineCapStyle = .round
    NSColor.tealAccent.setStroke()
    smile.stroke()

    let stem = NSBezierPath(roundedRect: CGRect(x: r(503), y: r(270), width: r(18), height: r(68)), xRadius: r(9), yRadius: r(9))
    NSColor.tealAccent.setFill()
    stem.fill()
    let base = NSBezierPath(roundedRect: CGRect(x: r(462), y: r(254), width: r(100), height: r(16)), xRadius: r(8), yRadius: r(8))
    base.fill()

    drawWave(x: r(232), y: r(438), heights: [34, 62, 88], scale: scale, color: NSColor.tealAccent.withAlphaComponent(0.34))
    drawWave(x: r(744), y: r(438), heights: [88, 62, 34], scale: scale, color: NSColor.tealAccent.withAlphaComponent(0.34))

    return image
}

func drawLine(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat, color: NSColor) {
    let path = NSBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
}

func drawWave(x: CGFloat, y: CGFloat, heights: [CGFloat], scale: CGFloat, color: NSColor) {
    for (index, height) in heights.enumerated() {
        let line = NSBezierPath(roundedRect: CGRect(x: x + CGFloat(index) * 34 * scale, y: y - height * scale / 2, width: 12 * scale, height: height * scale), xRadius: 6 * scale, yRadius: 6 * scale)
        color.setFill()
        line.fill()
    }
}

private extension NSColor {
    static let navy = NSColor(calibratedRed: 0.055, green: 0.098, blue: 0.176, alpha: 1)
    static let muted = NSColor(calibratedRed: 0.42, green: 0.50, blue: 0.59, alpha: 1)
    static let tealAccent = NSColor(calibratedRed: 0.02, green: 0.76, blue: 0.78, alpha: 1)
}
