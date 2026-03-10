import Foundation
import PackagePlugin

private let swiftLintConfigFiles = [
  "swiftlint.yml",
  ".swiftlint.yml",
]

extension Path {
  var directoryContainsConfigFile: Bool {
    swiftLintConfigFiles.contains {
      FileManager.default.fileExists(atPath: "\(self)/\($0)")
    }
  }

  var swiftLintConfigPath: Path {
    for configName in swiftLintConfigFiles {
      let configPath = appending(configName)
      if FileManager.default.fileExists(atPath: configPath.string) {
        return configPath
      }
    }
    return appending("swiftlint.yml")
  }

  var depth: Int {
    URL(fileURLWithPath: "\(self)").pathComponents.count
  }

  func isDescendant(of path: Path) -> Bool {
    "\(self)".hasPrefix("\(path)")
  }

  func resolveWorkingDirectory(in directory: Path) throws -> Path {
    guard "\(self)".hasPrefix("\(directory)") else {
      throw SwiftLintBuildToolPluginError.pathNotInDirectory(path: self, directory: directory)
    }

    let path = sequence(first: self) { path in
      let parent = path.removingLastComponent()
      guard "\(parent)".hasPrefix("\(directory)") else {
        return nil
      }
      return parent
    }
    .reversed()
    .first(where: \.directoryContainsConfigFile)

    return path ?? directory
  }
}
