import CoreGraphics
import Foundation
import ScreenCaptureKit

enum CaptureSourceProviderError: LocalizedError {
    case screenPermissionDenied
    case sourceLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .screenPermissionDenied:
            "Screen Recording permission is required before NotesTaker can list windows."
        case .sourceLoadFailed(let detail):
            "Could not load capture sources: \(detail)"
        }
    }
}

struct CaptureSourceProvider {
    func availableTargets() async throws -> [CaptureTarget] {
        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureSourceProviderError.screenPermissionDenied
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw CaptureSourceProviderError.sourceLoadFailed(error.localizedDescription)
        }

        let displays = content.displays.map {
            CaptureTarget(
                id: "display-\($0.displayID)",
                kind: .display,
                displayID: $0.displayID,
                windowID: nil,
                title: $0.displayID == CGMainDisplayID() ? "Full Screen" : "Display \($0.displayID)",
                subtitle: $0.displayID == CGMainDisplayID() ? "Capture the entire main display" : "Capture this display"
            )
        }

        let windows = content.windows
            .filter { window in
                guard window.isOnScreen else { return false }
                guard window.frame.width >= 160, window.frame.height >= 120 else { return false }
                return window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            }
            .map { window in
                let appName = window.owningApplication?.applicationName ?? "Unknown App"
                let title = window.title?.isEmpty == false ? window.title! : appName
                return CaptureTarget(
                    id: "window-\(window.windowID)",
                    kind: .window,
                    displayID: nil,
                    windowID: window.windowID,
                    title: title,
                    subtitle: appName
                )
            }

        return displays + windows
    }
}
