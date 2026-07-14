// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotesTaker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NotesTaker", targets: ["NotesTakerApp"])
    ],
    targets: [
        .executableTarget(
            name: "NotesTakerApp",
            path: "Sources/NotesTakerApp"
        )
    ]
)
