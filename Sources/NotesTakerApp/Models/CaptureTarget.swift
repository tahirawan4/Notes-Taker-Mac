import Foundation

enum CaptureTargetKind: String, Codable, Hashable {
    case display
    case window
}

struct CaptureTarget: Identifiable, Codable, Hashable {
    var id: String
    var kind: CaptureTargetKind
    var displayID: UInt32?
    var windowID: UInt32?
    var title: String
    var subtitle: String

    static func mainDisplay() -> CaptureTarget {
        CaptureTarget(
            id: "display-main",
            kind: .display,
            displayID: nil,
            windowID: nil,
            title: "Full Screen",
            subtitle: "Capture the entire main display"
        )
    }
}
