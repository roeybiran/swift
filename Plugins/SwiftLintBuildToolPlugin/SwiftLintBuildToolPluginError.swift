import PackagePlugin

enum SwiftLintBuildToolPluginError: Error, CustomStringConvertible {
  case pathNotInDirectory(path: Path, directory: Path)
  case swiftFilesNotInProjectDirectory(Path)
  case swiftFilesNotInWorkingDirectory(Path)

  var description: String {
    switch self {
    case .pathNotInDirectory(let path, let directory):
      "Path '\(path)' is not in directory '\(directory)'."
    case .swiftFilesNotInProjectDirectory(let directory):
      "Swift files are not in project directory '\(directory)'."
    case .swiftFilesNotInWorkingDirectory(let directory):
      "Swift files are not in working directory '\(directory)'."
    }
  }
}
