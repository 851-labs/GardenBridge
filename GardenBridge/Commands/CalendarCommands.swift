@preconcurrency import EventKit
import Foundation

/// Handles calendar-related commands using EventKit
actor CalendarCommands: CommandExecutor {
  private let eventStore = EKEventStore()
  private let dateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
    switch command {
    case "calendar.list":
      return try await self.listEvents(params: params)
    case "calendar.create":
      return try await self.createEvent(params: params)
    case "calendar.update":
      return try await self.updateEvent(params: params)
    case "calendar.delete":
      return try await self.deleteEvent(params: params)
    case "calendar.getCalendars":
      return try await self.getCalendars()
    default:
      throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown calendar command: \(command)")
    }
  }

  // MARK: - List Events

  private func listEvents(params: [String: AnyCodable]) async throws -> AnyCodable {
    guard let startDateStr = params["startDate"]?.stringValue,
          let endDateStr = params["endDate"]?.stringValue
    else {
      throw CommandError.invalidParam("startDate and endDate are required")
    }

    guard let startDate = parseDate(startDateStr) else {
      throw CommandError.invalidParam("startDate must be ISO8601 format")
    }

    guard let endDate = parseDate(endDateStr) else {
      throw CommandError.invalidParam("endDate must be ISO8601 format")
    }

    let calendars: [EKCalendar]? = if let calendarName = params["calendar"]?.stringValue {
      self.eventStore.calendars(for: .event).filter { $0.title == calendarName }
    } else {
      nil
    }

    let predicate = self.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
    let events = self.eventStore.events(matching: predicate)

    let eventDicts = events.map { event -> [String: Any] in
      var dict: [String: Any] = [
        "id": event.eventIdentifier ?? "",
        "title": event.title ?? "",
        "startDate": self.dateFormatter.string(from: event.startDate),
        "endDate": self.dateFormatter.string(from: event.endDate),
        "isAllDay": event.isAllDay,
        "calendar": event.calendar?.title ?? "",
      ]

      if let location = event.location {
        dict["location"] = location
      }
      if let notes = event.notes {
        dict["notes"] = notes
      }
      if let url = event.url {
        dict["url"] = url.absoluteString
      }

      return dict
    }

    return AnyCodable(["events": eventDicts])
  }

  // MARK: - Create Event

  private func createEvent(params: [String: AnyCodable]) async throws -> AnyCodable {
    guard let title = params["title"]?.stringValue else {
      throw CommandError.invalidParam("title")
    }

    guard let startDateStr = params["startDate"]?.stringValue,
          let endDateStr = params["endDate"]?.stringValue
    else {
      throw CommandError.invalidParam("startDate and endDate are required")
    }

    guard let startDate = parseDate(startDateStr) else {
      throw CommandError.invalidParam("startDate must be ISO8601 format")
    }

    guard let endDate = parseDate(endDateStr) else {
      throw CommandError.invalidParam("endDate must be ISO8601 format")
    }

    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = startDate
    event.endDate = endDate
    event.isAllDay = params["isAllDay"]?.boolValue ?? false

    if let location = params["location"]?.stringValue {
      event.location = location
    }
    if let notes = params["notes"]?.stringValue {
      event.notes = notes
    }
    if let urlStr = params["url"]?.stringValue, let url = URL(string: urlStr) {
      event.url = url
    }

    // Get calendar
    if let calendarName = params["calendar"]?.stringValue,
       let calendar = eventStore.calendars(for: .event).first(where: { $0.title == calendarName })
    {
      event.calendar = calendar
    } else {
      event.calendar = self.eventStore.defaultCalendarForNewEvents
    }

    try self.eventStore.save(event, span: .thisEvent)

    return AnyCodable([
      "id": event.eventIdentifier ?? "",
      "success": true,
    ])
  }

  // MARK: - Update Event

  private func updateEvent(params: [String: AnyCodable]) async throws -> AnyCodable {
    guard let eventId = params["id"]?.stringValue else {
      throw CommandError.invalidParam("id")
    }

    guard let event = eventStore.event(withIdentifier: eventId) else {
      throw CommandError.notFound
    }

    if let title = params["title"]?.stringValue {
      event.title = title
    }

    if let startDateStr = params["startDate"]?.stringValue,
       let startDate = parseDate(startDateStr)
    {
      event.startDate = startDate
    }

    if let endDateStr = params["endDate"]?.stringValue,
       let endDate = parseDate(endDateStr)
    {
      event.endDate = endDate
    }

    if let isAllDay = params["isAllDay"]?.boolValue {
      event.isAllDay = isAllDay
    }

    if let location = params["location"]?.stringValue {
      event.location = location
    }

    if let notes = params["notes"]?.stringValue {
      event.notes = notes
    }

    try self.eventStore.save(event, span: .thisEvent)

    return AnyCodable(["success": true])
  }

  // MARK: - Delete Event

  private func deleteEvent(params: [String: AnyCodable]) async throws -> AnyCodable {
    guard let eventId = params["id"]?.stringValue else {
      throw CommandError.invalidParam("id")
    }

    guard let event = eventStore.event(withIdentifier: eventId) else {
      throw CommandError.notFound
    }

    try self.eventStore.remove(event, span: .thisEvent)

    return AnyCodable(["success": true])
  }

  // MARK: - Get Calendars

  private func getCalendars() async throws -> AnyCodable {
    let calendars = self.eventStore.calendars(for: .event)

    let calendarDicts = calendars.map { calendar -> [String: Any] in
      [
        "id": calendar.calendarIdentifier,
        "title": calendar.title,
        "type": calendar.type.rawValue,
        "isImmutable": calendar.isImmutable,
        "allowsContentModifications": calendar.allowsContentModifications,
      ]
    }

    return AnyCodable(["calendars": calendarDicts])
  }

  private func parseDate(_ value: String) -> Date? {
    if let date = dateFormatter.date(from: value) {
      return date
    }

    let fallback = ISO8601DateFormatter()
    return fallback.date(from: value)
  }
}
