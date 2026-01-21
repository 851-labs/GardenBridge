import Foundation

/// Handles AppleScript execution commands
actor AppleScriptCommands: CommandExecutor {
  func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
    switch command {
    case "applescript.execute":
      return try await self.executeScript(params: params)
    default:
      throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown applescript command: \(command)")
    }
  }

  // MARK: - Execute AppleScript

  private func executeScript(params: [String: AnyCodable]) async throws -> AnyCodable {
    guard let script = params["script"]?.stringValue else {
      throw CommandError.invalidParam("script")
    }

    // Execute on main thread since NSAppleScript is not thread-safe
    let result = await MainActor.run { () -> Result<String?, CommandError> in
      var errorInfo: NSDictionary?

      let appleScript = NSAppleScript(source: script)
      let eventDescriptor = appleScript?.executeAndReturnError(&errorInfo)

      if let error = errorInfo {
        let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
        let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
        return .failure(CommandError(code: "APPLESCRIPT_ERROR_\(errorNumber)", message: errorMessage))
      }

      // Extract result if available
      let resultString = eventDescriptor?.stringValue
      return .success(resultString)
    }

    switch result {
    case let .success(output):
      return AnyCodable([
        "success": true,
        "output": output as Any,
      ])
    case let .failure(error):
      throw error
    }
  }
}
