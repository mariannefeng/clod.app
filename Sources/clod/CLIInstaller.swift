import Foundation

enum CLIInstallError: Error, LocalizedError {
  case noExecutablePath
  case pathNotWritable(String)

  var errorDescription: String? {
    switch self {
    case .noExecutablePath: "Couldn't determine clod's own executable path"
    case .pathNotWritable(let path): "Couldn't create \(path)"
    }
  }
}

enum CLIInstaller {
  private static var linkURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appending(path: ".local/bin/clod")
  }

  static var isInstalled: Bool {
    guard let target = Bundle.main.executablePath,
      let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: linkURL.path)
    else { return false }
    return resolved == target
  }

  static func install() throws {
    guard let target = Bundle.main.executablePath else { throw CLIInstallError.noExecutablePath }

    let binDir = linkURL.deletingLastPathComponent()
    do {
      try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
    } catch {
      throw CLIInstallError.pathNotWritable(binDir.path)
    }

    if FileManager.default.fileExists(atPath: linkURL.path) {
      try FileManager.default.removeItem(at: linkURL)
    }
    try FileManager.default.createSymbolicLink(atPath: linkURL.path, withDestinationPath: target)
  }
}
