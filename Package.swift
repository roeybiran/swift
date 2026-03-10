// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "AirbnbSwift",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .plugin(name: "SwiftLintBuildToolPlugin", targets: ["SwiftLintBuildToolPlugin"]),
    .plugin(name: "FormatSwift", targets: ["FormatSwift"]),
  ],
  targets: [
    .plugin(
      name: "SwiftLintBuildToolPlugin",
      capability: .buildTool(),
      dependencies: [
        "SwiftLintBinary"
      ],
    ),
    .plugin(
      name: "FormatSwift",
      capability: .command(
        intent: .custom(
          verb: "format",
          description: "Formats and lints Swift source files according to the Airbnb Swift style guide.",
        ),
        permissions: [
          .writeToPackageDirectory(
            reason: "Formatting and lint fixes may modify Swift source files."
          )
        ],
      ),
      dependencies: [
        "swiftformat",
        "SwiftLintBinary",
      ],
    ),
    .binaryTarget(
      name: "swiftformat",
      url: "https://github.com/calda/SwiftFormat-nightly/releases/download/2026-02-23-b/SwiftFormat.artifactbundle.zip",
      checksum: "6b48bb0fd19af630a1f00fb162a65f0a6a8906c4ee97f6a8b33d4c22042ae754",
    ),
    .binaryTarget(
      name: "SwiftLintBinary",
      url: "https://github.com/realm/SwiftLint/releases/download/0.63.2/SwiftLintBinary.artifactbundle.zip",
      checksum: "12befab676fc972ffde2ec295d016d53c3a85f64aabd9c7fee0032d681e307e9",
    ),
  ],
)
