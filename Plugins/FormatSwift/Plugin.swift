import Foundation
import PackagePlugin

// MARK: - FormatSwiftPlugin

@main
struct FormatSwiftPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) async throws {
    var argumentExtractor = ArgumentExtractor(arguments)
    let targetNames = argumentExtractor.extractOption(named: "target")
    var inputPaths = argumentExtractor.extractOption(named: "paths")
    let lintOnly = argumentExtractor.extractFlag(named: "lint") > 0

    if !targetNames.isEmpty {
      inputPaths += try context.package.targets(named: targetNames).map { $0.directory.string }
    } else if inputPaths.isEmpty {
      inputPaths = try defaultInputPaths(for: context.package)
    }

    try run(
      context: context,
      inputPaths: inputPaths,
      lintOnly: lintOnly,
      workingDirectory: context.package.directory,
    )
  }
}

#if canImport(XcodeProjectPlugin)

import XcodeProjectPlugin

extension FormatSwiftPlugin: XcodeCommandPlugin {
  func performCommand(context: XcodePluginContext, arguments: [String]) throws {
    var argumentExtractor = ArgumentExtractor(arguments)
    let targetNames = Set(argumentExtractor.extractOption(named: "target"))
    let lintOnly = argumentExtractor.extractFlag(named: "lint") > 0

    let inputPaths = context.xcodeProject.targets.lazy
      .filter { targetNames.isEmpty || targetNames.contains($0.displayName) }
      .flatMap(\.inputFiles)
      .map(\.path.string)
      .filter { $0.hasSuffix(".swift") }

    try run(
      context: context,
      inputPaths: Array(inputPaths),
      lintOnly: lintOnly,
      workingDirectory: context.xcodeProject.directory,
    )
  }
}

#endif

extension FormatSwiftPlugin {
  private func run(
    context: some CommandContext,
    inputPaths: [String],
    lintOnly: Bool,
    workingDirectory: Path,
  ) throws {
    if inputPaths.isEmpty {
      Diagnostics.remark("No Swift sources were found to format or lint.")
      return
    }

    let swiftFormatConfig = workingDirectory.appending("airbnb.swiftformat")
    let swiftLintConfig = workingDirectory.swiftLintConfigPath
    let swiftFormatCachePath = context.pluginWorkDirectory.appending("swiftformat.cache")
    let swiftLintCachePath = context.pluginWorkDirectory.appending("swiftlint.cache")

    try runCommand(
      executable: context.tool(named: "swiftformat").path,
      workingDirectory: workingDirectory,
      commandName: "swiftformat",
      arguments: inputPaths + [
        "--quiet",
        "--config",
        swiftFormatConfig.string,
        "--cache",
        swiftFormatCachePath.string,
      ] + (lintOnly ? ["--lint"] : []),
    )

    try runCommand(
      executable: context.tool(named: "swiftlint").path,
      workingDirectory: workingDirectory,
      commandName: "swiftlint",
      arguments: [
        "lint",
        "--quiet",
        "--force-exclude",
        "--config",
        swiftLintConfig.string,
        "--cache-path",
        swiftLintCachePath.string,
      ] + (lintOnly ? [] : ["--fix"]) + inputPaths,
    )
  }

  private func runCommand(
    executable: Path,
    workingDirectory: Path,
    commandName: String,
    arguments: [String],
  ) throws {
    let process = Process()
    process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory.string)
    process.executableURL = URL(fileURLWithPath: executable.string)
    process.arguments = arguments

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      Diagnostics.error("Failed to run \(commandName): \(error)")
      throw error
    }

    switch process.terminationReason {
    case .exit:
      guard process.terminationStatus == EXIT_SUCCESS else {
        let failure = PluginError.commandFailed(command: commandName, exitCode: process.terminationStatus)
        Diagnostics.error(failure.description)
        throw failure
      }

    case .uncaughtSignal:
      let failure = PluginError.commandInterrupted(command: commandName)
      Diagnostics.error(failure.description)
      throw failure

    @unknown default:
      let failure = PluginError.unknownTermination(command: commandName)
      Diagnostics.error(failure.description)
      throw failure
    }
  }

  private func defaultInputPaths(for package: Package) throws -> [String] {
    let packageDirectoryContents = try FileManager.default.contentsOfDirectory(
      at: URL(fileURLWithPath: package.directory.string),
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles],
    )

    let subdirectories = packageDirectoryContents.filter(\.hasDirectoryPath)
    let rootSwiftFiles = packageDirectoryContents.filter { $0.pathExtension == "swift" }
    return (subdirectories + rootSwiftFiles).map(\.path)
  }
}

// MARK: - PluginError

private enum PluginError: Error, CustomStringConvertible {
  case commandFailed(command: String, exitCode: Int32)
  case commandInterrupted(command: String)
  case unknownTermination(command: String)

  var description: String {
    switch self {
    case .commandFailed(let command, let exitCode):
      "Command '\(command)' finished with a non-zero exit code (\(exitCode))."
    case .commandInterrupted(let command):
      "Command '\(command)' stopped due to an uncaught signal."
    case .unknownTermination(let command):
      "Command '\(command)' stopped unexpectedly."
    }
  }
}

// MARK: - CommandContext

private protocol CommandContext {
  var pluginWorkDirectory: Path { get }

  func tool(named name: String) throws -> PluginContext.Tool
}

// MARK: - PluginContext + CommandContext

extension PluginContext: CommandContext { }

#if canImport(XcodeProjectPlugin)
extension XcodePluginContext: CommandContext { }
#endif

extension Path {
  fileprivate var swiftLintConfigPath: Path {
    let preferredConfigPath = appending("swiftlint.yml")
    if FileManager.default.fileExists(atPath: preferredConfigPath.string) {
      return preferredConfigPath
    }

    return appending(".swiftlint.yml")
  }
}
