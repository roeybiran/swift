# Airbnb Swift Plugins

This repository provides Swift Package Manager plugins for Airbnb's Swift style setup.

## Available Plugins

- `SwiftLintBuildToolPlugin`: Runs SwiftLint during target builds.
- `FormatSwift`: Command plugin (`swift package format`) that runs SwiftFormat and SwiftLint.

## Local Usage

```bash
# Lint only (non-mutating)
swift package --allow-writing-to-package-directory format --lint

# Apply formatting and lint fixes
swift package --allow-writing-to-package-directory format
```

## Compatibility Script

`lint.sh` is kept as a compatibility wrapper. It delegates to the command plugin and prints a deprecation warning.

## Use in Another Package

Add this package as a dependency:

```swift
dependencies: [
  .package(url: "https://github.com/airbnb/swift", from: "1.0.0"),
]
```

Attach the build tool plugin to a target:

```swift
.target(
  name: "MyTarget",
  plugins: [
    .plugin(name: "SwiftLintBuildToolPlugin", package: "swift"),
  ]
)
```

Run the command plugin:

```bash
swift package --allow-writing-to-package-directory format
```
