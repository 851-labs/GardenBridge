import Foundation
import EventKit

/// Handles reminders-related commands using EventKit
actor RemindersCommands: CommandExecutor {
    private let eventStore = EKEventStore()
    
    func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
        switch command {
        case "reminders.list":
            return try await listReminders(params: params)
        case "reminders.create":
            return try await createReminder(params: params)
        case "reminders.complete":
            return try await completeReminder(params: params)
        case "reminders.delete":
            return try await deleteReminder(params: params)
        case "reminders.getLists":
            return try await getReminderLists()
        default:
            throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown reminders command: \(command)")
        }
    }
    
    // MARK: - List Reminders
    
    private func listReminders(params: [String: AnyCodable]) async throws -> AnyCodable {
        let includeCompleted = params["includeCompleted"]?.boolValue ?? false
        let listName = params["list"]?.stringValue
        
        let calendars: [EKCalendar]?
        if let listName = listName {
            calendars = eventStore.calendars(for: .reminder).filter { $0.title == listName }
        } else {
            calendars = eventStore.calendars(for: .reminder)
        }
        
        let predicate: NSPredicate
        if includeCompleted {
            predicate = eventStore.predicateForReminders(in: calendars)
        } else {
            predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)
        }
        
        let reminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        let formatter = ISO8601DateFormatter()
        
        let reminderDicts = reminders.map { reminder -> [String: Any] in
            var dict: [String: Any] = [
                "id": reminder.calendarItemIdentifier,
                "title": reminder.title ?? "",
                "isCompleted": reminder.isCompleted,
                "list": reminder.calendar?.title ?? ""
            ]
            
            if let dueDate = reminder.dueDateComponents,
               let date = Calendar.current.date(from: dueDate) {
                dict["dueDate"] = formatter.string(from: date)
            }
            
            if let completionDate = reminder.completionDate {
                dict["completionDate"] = formatter.string(from: completionDate)
            }
            
            if let priority = reminder.priority as Int?, priority > 0 {
                dict["priority"] = priority
            }
            
            if let notes = reminder.notes {
                dict["notes"] = notes
            }
            
            return dict
        }
        
        return AnyCodable(["reminders": reminderDicts, "count": reminderDicts.count])
    }
    
    // MARK: - Create Reminder
    
    private func createReminder(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let title = params["title"]?.stringValue else {
            throw CommandError.invalidParam("title")
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        
        if let dueDateStr = params["dueDate"]?.stringValue {
            let formatter = ISO8601DateFormatter()
            if let dueDate = formatter.date(from: dueDateStr) {
                reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            }
        }
        
        if let priority = params["priority"]?.intValue {
            reminder.priority = priority
        }
        
        if let notes = params["notes"]?.stringValue {
            reminder.notes = notes
        }
        
        // Get list
        if let listName = params["list"]?.stringValue,
           let calendar = eventStore.calendars(for: .reminder).first(where: { $0.title == listName }) {
            reminder.calendar = calendar
        } else {
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
        }
        
        try eventStore.save(reminder, commit: true)
        
        return AnyCodable([
            "id": reminder.calendarItemIdentifier,
            "success": true
        ])
    }
    
    // MARK: - Complete Reminder
    
    private func completeReminder(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let reminderId = params["id"]?.stringValue else {
            throw CommandError.invalidParam("id")
        }
        
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw CommandError.notFound
        }
        
        let completed = params["completed"]?.boolValue ?? true
        reminder.isCompleted = completed
        
        if completed {
            reminder.completionDate = Date()
        } else {
            reminder.completionDate = nil
        }
        
        try eventStore.save(reminder, commit: true)
        
        return AnyCodable(["success": true])
    }
    
    // MARK: - Delete Reminder
    
    private func deleteReminder(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let reminderId = params["id"]?.stringValue else {
            throw CommandError.invalidParam("id")
        }
        
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw CommandError.notFound
        }
        
        try eventStore.remove(reminder, commit: true)
        
        return AnyCodable(["success": true])
    }
    
    // MARK: - Get Reminder Lists
    
    private func getReminderLists() async throws -> AnyCodable {
        let calendars = eventStore.calendars(for: .reminder)
        
        let listDicts = calendars.map { calendar -> [String: Any] in
            [
                "id": calendar.calendarIdentifier,
                "title": calendar.title,
                "isDefault": calendar == eventStore.defaultCalendarForNewReminders(),
                "allowsContentModifications": calendar.allowsContentModifications
            ]
        }
        
        return AnyCodable(["lists": listDicts])
    }
}
