import SwiftUI

enum AppColors {
    static let canvas = Color(red: 0.955, green: 0.961, blue: 0.949)
    static let sidebar = Color(red: 0.902, green: 0.929, blue: 0.918)
    static let surface = Color(red: 1.0, green: 1.0, blue: 0.985)
    static let surfaceAlt = Color(red: 0.935, green: 0.951, blue: 0.969)
    static let toolbar = Color(red: 0.925, green: 0.937, blue: 0.937)
    static let text = Color(red: 0.055, green: 0.098, blue: 0.176)
    static let textMuted = Color(red: 0.357, green: 0.408, blue: 0.486)
    static let textSoft = Color(red: 0.525, green: 0.574, blue: 0.647)
}

extension ShapeStyle where Self == Color {
    static var navy: Color { Color(red: 0.055, green: 0.098, blue: 0.176) }
    static var softNavy: Color { Color(red: 0.118, green: 0.169, blue: 0.267) }
    static var indigo: Color { Color(red: 0.306, green: 0.275, blue: 0.776) }
    static var coral: Color { Color(red: 0.875, green: 0.302, blue: 0.267) }
    static var amber: Color { Color(red: 0.82, green: 0.529, blue: 0.075) }
}
