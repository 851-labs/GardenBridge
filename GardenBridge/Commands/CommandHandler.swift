import Foundation

/// Central handler for all gateway invoke commands
actor CommandHandler {
    private let permissionManager: PermissionManager

    private let handlers: [(prefix: String, handler: any CommandExecutor)]

    init(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager
        self.handlers = [
            ("calendar.", CalendarCommands()),
            ("contacts.", ContactsCommands()),
            ("reminders.", RemindersCommands()),
            ("location.", LocationCommands()),
            ("applescript.", AppleScriptCommands()),
            ("file.", FileSystemCommands()),
            ("accessibility.", AccessibilityCommands()),
            ("screen.", ScreenCaptureCommands()),
            ("camera.", CameraCommands()),
            ("notification.", NotificationCommands()),
            ("shell.", ShellCommands()),
        ]
    }

    /// Handle an invoke request from the gateway
    func handle(invoke: GatewayInvoke) async -> GatewayInvokeResponse {
        let command = invoke.command
        let params = invoke.params ?? [:]

        do {
            let result = try await executeCommand(command: command, params: params)
            return GatewayInvokeResponse.success(id: invoke.id, payload: result)
        } catch let error as CommandError {
            return GatewayInvokeResponse.failure(id: invoke.id, code: error.code, message: error.message)
        } catch {
            return GatewayInvokeResponse.failure(
                id: invoke.id,
                code: "INTERNAL_ERROR",
                message: error.localizedDescription)
        }
    }

    /// Get current permissions for connect request
    func getPermissions() async -> [String: Bool] {
        await MainActor.run {
            self.permissionManager.getPermissionsDictionary()
        }
    }

    // MARK: - Command Routing

    private func executeCommand(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
        for handler in self.handlers where command.hasPrefix(handler.prefix) {
            return try await handler.handler.execute(command: command, params: params)
        }

        throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)")
    }
}

/// Error type for command execution
struct CommandError: Error, Sendable {
    let code: String
    let message: String

    static let permissionDenied = CommandError(
        code: "PERMISSION_DENIED",
        message: "Permission denied for this operation")
    static let invalidParams = CommandError(code: "INVALID_PARAMS", message: "Invalid or missing parameters")
    static let notFound = CommandError(code: "NOT_FOUND", message: "Resource not found")
    static let notImplemented = CommandError(code: "NOT_IMPLEMENTED", message: "Command not implemented")

    static func invalidParam(_ name: String) -> CommandError {
        CommandError(code: "INVALID_PARAMS", message: "Missing or invalid parameter: \(name)")
    }
}

/// Protocol for command handlers
protocol CommandExecutor: Sendable {
    func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable?
}
