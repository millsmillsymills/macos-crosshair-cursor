// swift-tools-version:6.0
import PackageDescription

// swift-testing ships inside CommandLineTools but its framework and the
// lib_TestingInterop.dylib it loads are not on the default search paths, so
// `swift test` can't find them out of the box. Point the test target at both.
let cltDeveloper = "/Library/Developer/CommandLineTools/Library/Developer"
let testingFrameworks = "\(cltDeveloper)/Frameworks"
let testingInteropLib = "\(cltDeveloper)/usr/lib"

let package = Package(
    name: "Crosshair",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "CrosshairCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "CrosshairApp",
            dependencies: ["CrosshairCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CrosshairCoreTests",
            dependencies: ["CrosshairCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags(["-F", testingFrameworks])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", testingFrameworks,
                    "-Xlinker", "-rpath", "-Xlinker", testingFrameworks,
                    "-Xlinker", "-rpath", "-Xlinker", testingInteropLib
                ])
            ]
        )
    ]
)
