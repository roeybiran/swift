import Foundation
import PackagePlugin

// MARK: - SwiftLintBuildToolPlugin

@main
struct SwiftLintBuildToolPlugin: BuildToolPlugin {

  // MARK: Internal

  func createBuildCommands(
    context: PluginContext,
    target: Target,
  ) throws -> [Command] {
    try makeCommand(
      executable: context.tool(named: "swiftlint"),
      swiftFiles: (target as? SourceModuleTarget).flatMap(swiftFiles) ?? [],
      environment: environment(context: context, target: target),
      pluginWorkDirectory: context.pluginWorkDirectory,
    )
  }

  // MARK: Private

  private func swiftFiles(target: SourceModuleTarget) -> [Path] {
    target
      .sourceFiles(withSuffix: "swift")
      .map(\.path)
  }

  private func environment(
    context: PluginContext,
    target: Target,
  ) throws -> [String: String] {
    let workingDirectory = try target.directory.resolveWorkingDirectory(in: context.package.directory)
    return ["BUILD_WORKSPACE_DIRECTORY": "\(workingDirectory)"]
  }

  private func makeCommand(
    executable: PluginContext.Tool,
    swiftFiles: [Path],
    environment: [String: String],
    pluginWorkDirectory: Path,
  ) throws -> [Command] {
    if swiftFiles.isEmpty {
      return []
    }

    let workingDirectory = environment["BUILD_WORKSPACE_DIRECTORY"]
      .map(Path.init)
      ?? Path(".")
    let swiftLintConfig = workingDirectory.swiftLintConfigPath

    let arguments: [String] = [
      "lint",
      "--quiet",
      "--force-exclude",
      "--config",
      swiftLintConfig.string,
    ]

    let cacheArguments: [String]
    if ProcessInfo.processInfo.environment["CI_XCODE_CLOUD"] == "TRUE" {
      cacheArguments = ["--no-cache"]
    } else {
      let cachePath = pluginWorkDirectory.appending("Cache")
      try FileManager.default.createDirectory(
        atPath: cachePath.string,
        withIntermediateDirectories: true,
      )
      cacheArguments = ["--cache-path", cachePath.string]
    }

    let outputPath = pluginWorkDirectory.appending("Output")
    try FileManager.default.createDirectory(
      atPath: outputPath.string,
      withIntermediateDirectories: true,
    )

    return [
      .prebuildCommand(
        displayName: "SwiftLint",
        executable: executable.path,
        arguments: arguments + cacheArguments + swiftFiles.map(\.string),
        environment: environment,
        outputFilesDirectory: outputPath,
      )
    ]
  }
}

#if canImport(XcodeProjectPlugin)

import XcodeProjectPlugin

extension SwiftLintBuildToolPlugin: XcodeBuildToolPlugin {

  // MARK: Internal

  func createBuildCommands(
    context: XcodePluginContext,
    target: XcodeTarget,
  ) throws -> [Command] {
    try makeCommand(
      executable: context.tool(named: "swiftlint"),
      swiftFiles: swiftFiles(target: target),
      environment: environment(context: context, target: target),
      pluginWorkDirectory: context.pluginWorkDirectory,
    )
  }

  // MARK: Private

  private func swiftFiles(target: XcodeTarget) -> [Path] {
    target
      .inputFiles
      .filter { $0.type == .source && $0.path.extension == "swift" }
      .map(\.path)
  }

  private func environment(
    context: XcodePluginContext,
    target: XcodeTarget,
  ) throws -> [String: String] {
    let projectDirectory = context.xcodeProject.directory
    let swiftFiles = swiftFiles(target: target)
    let swiftFilesNotInProjectDirectory = swiftFiles.filter { !$0.isDescendant(of: projectDirectory) }

    if !swiftFilesNotInProjectDirectory.isEmpty {
      throw SwiftLintBuildToolPluginError.swiftFilesNotInProjectDirectory(projectDirectory)
    }

    let directories = try swiftFiles.map { try $0.resolveWorkingDirectory(in: projectDirectory) }
    let workingDirectory = directories.min { $0.depth < $1.depth } ?? projectDirectory
    let swiftFilesNotInWorkingDirectory = swiftFiles.filter { !$0.isDescendant(of: workingDirectory) }

    if !swiftFilesNotInWorkingDirectory.isEmpty {
      throw SwiftLintBuildToolPluginError.swiftFilesNotInWorkingDirectory(workingDirectory)
    }

    return ["BUILD_WORKSPACE_DIRECTORY": "\(workingDirectory)"]
  }
}

#endif
