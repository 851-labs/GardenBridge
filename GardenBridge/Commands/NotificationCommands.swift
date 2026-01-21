import Foundation
import UserNotifications

/// Handles notification commands using UserNotifications
actor NotificationCommands: CommandExecutor {
    
    func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
        switch command {
        case "notification.send":
            return try await sendNotification(params: params)
        default:
            throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown notification command: \(command)")
        }
    }
    
    // MARK: - Send Notification
    
    private func sendNotification(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let title = params["title"]?.stringValue else {
            throw CommandError.invalidParam("title")
        }
        
        let body = params["body"]?.stringValue ?? ""
        let subtitle = params["subtitle"]?.stringValue
        let sound = params["sound"]?.boolValue ?? true
        let badge = params["badge"]?.intValue
        let identifier = params["id"]?.stringValue ?? UUID().uuidString
        
        // Request authorization if needed
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            do {
                try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                throw CommandError(code: "NOTIFICATION_AUTH_FAILED", message: "Failed to get notification authorization")
            }
        }

        let updatedSettings = await center.notificationSettings()
        if updatedSettings.authorizationStatus == .denied {
            throw CommandError(code: "NOTIFICATION_DENIED", message: "Notification permission denied")
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        
        if sound {
            content.sound = .default
        }
        
        if let badge = badge {
            content.badge = NSNumber(value: badge)
        }
        
        // Add any custom data
        if let userInfo = params["userInfo"]?.dictionaryValue {
            content.userInfo = userInfo
        }
        
        // Create request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        // Schedule notification
        try await center.add(request)
        
        return AnyCodable([
            "success": true,
            "id": identifier
        ])
    }
}
