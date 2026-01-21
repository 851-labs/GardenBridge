import Foundation

/// Central handler for all gateway invoke commands
actor CommandHandler {
    private let permissionManager: PermissionManager
    
    // Command handlers
    private let calendarCommands: CalendarCommands
    private let contactsCommands: ContactsCommands
    private let remindersCommands: RemindersCommands
    private let locationCommands: LocationCommands
    private let appleScriptCommands: AppleScriptCommands
    private let fileSystemCommands: FileSystemCommands
    private let accessibilityCommands: AccessibilityCommands
    private let screenCaptureCommands: ScreenCaptureCommands
    private let cameraCommands: CameraCommands
    private let notificationCommands: NotificationCommands
    private let shellCommands: ShellCommands
    
    init(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager
        self.calendarCommands = CalendarCommands()
        self.contactsCommands = ContactsCommands()
        self.remindersCommands = RemindersCommands()
        self.locationCommands = LocationCommands()
        self.appleScriptCommands = AppleScriptCommands()
        self.fileSystemCommands = FileSystemCommands()
        self.accessibilityCommands = AccessibilityCommands()
        self.screenCaptureCommands = ScreenCaptureCommands()
        self.cameraCommands = CameraCommands()
        self.notificationCommands = NotificationCommands()
        self.shellCommands = ShellCommands()
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
            return GatewayInvokeResponse.failure(id: invoke.id, code: "INTERNAL_ERROR", message: error.localizedDescription)
        }
    }
    
    /// Get current permissions for connect request
    func getPermissions() async -> [String: Bool] {
        await MainActor.run {
            permissionManager.getPermissionsDictionary()
        }
    }
    
    // MARK: - Command Routing
    
    private func executeCommand(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
        // Route to appropriate handler based on command prefix
        if command.hasPrefix("calendar.") {
            return try await calendarCommands.execute(command: command, params: params)
        } else if command.hasPrefix("contacts.") {
            return try await contactsCommands.execute(command: command, params: params)
        } else if command.hasPrefix("reminders.") {
            return try await remindersCommands.execute(command: command, params: params)
        } else if command.hasPrefix("location.") {
            return try await locationCommands.execute(command: command, params: params)
        } else if command.hasPrefix("applescript.") {
            return try await appleScriptCommands.execute(command: command, params: params)
        } else if command.hasPrefix("file.") {
            return try await fileSystemCommands.execute(command: command, params: params)
        } else if command.hasPrefix("accessibility.") {
            return try await accessibilityCommands.execute(command: command, params: params)
        } else if command.hasPrefix("screen.") {
            return try await screenCaptureCommands.execute(command: command, params: params)
        } else if command.hasPrefix("camera.") {
            return try await cameraCommands.execute(command: command, params: params)
        } else if command.hasPrefix("notification.") {
            return try await notificationCommands.execute(command: command, params: params)
        } else if command.hasPrefix("shell.") {
            return try await shellCommands.execute(command: command, params: params)
        } else {
            throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)")
        }
    }
}

/// Error type for command execution
struct CommandError: Error {
    let code: String
    let message: String
    
    static let permissionDenied = CommandError(code: "PERMISSION_DENIED", message: "Permission denied for this operation")
    static let invalidParams = CommandError(code: "INVALID_PARAMS", message: "Invalid or missing parameters")
    static let notFound = CommandError(code: "NOT_FOUND", message: "Resource not found")
    static let notImplemented = CommandError(code: "NOT_IMPLEMENTED", message: "Command not implemented")
    
    static func invalidParam(_ name: String) -> CommandError {
        CommandError(code: "INVALID_PARAMS", message: "Missing or invalid parameter: \(name)")
    }
}

/// Protocol for command handlers
protocol CommandExecutor {
    func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable?
}
