@preconcurrency import Contacts
import Foundation

/// Handles contacts-related commands using Contacts framework
actor ContactsCommands: CommandExecutor {
  private var contactStore: CNContactStore?

  private let basicKeys: [CNKeyDescriptor] = [
    CNContactIdentifierKey as CNKeyDescriptor,
    CNContactGivenNameKey as CNKeyDescriptor,
    CNContactFamilyNameKey as CNKeyDescriptor,
    CNContactOrganizationNameKey as CNKeyDescriptor,
    CNContactEmailAddressesKey as CNKeyDescriptor,
    CNContactPhoneNumbersKey as CNKeyDescriptor,
    CNContactBirthdayKey as CNKeyDescriptor,
    CNContactImageDataAvailableKey as CNKeyDescriptor,
  ]

  private let detailedKeys: [CNKeyDescriptor] = [
    CNContactIdentifierKey as CNKeyDescriptor,
    CNContactGivenNameKey as CNKeyDescriptor,
    CNContactFamilyNameKey as CNKeyDescriptor,
    CNContactMiddleNameKey as CNKeyDescriptor,
    CNContactOrganizationNameKey as CNKeyDescriptor,
    CNContactJobTitleKey as CNKeyDescriptor,
    CNContactEmailAddressesKey as CNKeyDescriptor,
    CNContactPhoneNumbersKey as CNKeyDescriptor,
    CNContactPostalAddressesKey as CNKeyDescriptor,
    CNContactBirthdayKey as CNKeyDescriptor,
    CNContactNoteKey as CNKeyDescriptor,
    CNContactUrlAddressesKey as CNKeyDescriptor,
    CNContactSocialProfilesKey as CNKeyDescriptor,
    CNContactImageDataAvailableKey as CNKeyDescriptor,
  ]

  private func getContactStore() -> CNContactStore {
    if let contactStore {
      return contactStore
    }
    let store = CNContactStore()
    contactStore = store
    return store
  }

  func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
    switch command {
    case "contacts.search":
      return try await self.searchContacts(params: params)
    case "contacts.get":
      return try await self.getContact(params: params)
    case "contacts.birthdays":
      return try await self.getBirthdays(params: params)
    default:
      throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown contacts command: \(command)")
    }
  }

  // MARK: - Search Contacts

  private func searchContacts(params: [String: AnyCodable]) async throws -> AnyCodable {
    let query = params["query"]?.stringValue ?? ""
    let limit = params["limit"]?.intValue ?? 50

    var contacts: [CNContact] = []

    let request = CNContactFetchRequest(keysToFetch: basicKeys)

    if !query.isEmpty {
      request.predicate = CNContact.predicateForContacts(matchingName: query)
    }

    try self.getContactStore().enumerateContacts(with: request) { contact, stop in
      contacts.append(contact)
      if contacts.count >= limit {
        stop.pointee = true
      }
    }

    let contactDicts = contacts.map { self.formatContact($0) }

    return AnyCodable(["contacts": contactDicts, "count": contactDicts.count])
  }

  // MARK: - Get Contact

  private func getContact(params: [String: AnyCodable]) async throws -> AnyCodable {
    guard let contactId = params["id"]?.stringValue else {
      throw CommandError.invalidParam("id")
    }

    do {
      let contact = try getContactStore().unifiedContact(
        withIdentifier: contactId,
        keysToFetch: self.detailedKeys)
      return AnyCodable(["contact": self.formatContactDetailed(contact)])
    } catch {
      throw CommandError.notFound
    }
  }

  // MARK: - Get Birthdays

  private func getBirthdays(params: [String: AnyCodable]) async throws -> AnyCodable {
    let daysAhead = params["daysAhead"]?.intValue ?? 30

    let keysToFetch: [CNKeyDescriptor] = [
      CNContactIdentifierKey as CNKeyDescriptor,
      CNContactGivenNameKey as CNKeyDescriptor,
      CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactBirthdayKey as CNKeyDescriptor,
    ]

    var birthdays: [[String: Any]] = []
    let calendar = Calendar.current
    let today = Date()
    let endDate = calendar.date(byAdding: .day, value: daysAhead, to: today)!

    let request = CNContactFetchRequest(keysToFetch: keysToFetch)

    try getContactStore().enumerateContacts(with: request) { contact, _ in
      guard let birthday = contact.birthday else { return }

      // Create this year's birthday date
      var components = birthday
      components.year = calendar.component(.year, from: today)

      guard let birthdayDate = calendar.date(from: components) else { return }

      // Check if birthday is within range
      var checkDate = birthdayDate
      if checkDate < today {
        // Birthday already passed this year, check next year
        components.year = calendar.component(.year, from: today) + 1
        checkDate = calendar.date(from: components) ?? birthdayDate
      }

      if checkDate >= today, checkDate <= endDate {
        let daysUntil = calendar.dateComponents([.day], from: today, to: checkDate).day ?? 0

        birthdays.append([
          "id": contact.identifier,
          "name": "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces),
          "date": ISO8601DateFormatter().string(from: checkDate),
          "daysUntil": daysUntil,
        ])
      }
    }

    // Sort by days until birthday
    birthdays.sort { ($0["daysUntil"] as? Int ?? 0) < ($1["daysUntil"] as? Int ?? 0) }

    return AnyCodable(["birthdays": birthdays, "count": birthdays.count])
  }

  // MARK: - Formatting Helpers

  private func formatContact(_ contact: CNContact) -> [String: Any] {
    var dict: [String: Any] = [
      "id": contact.identifier,
      "givenName": contact.givenName,
      "familyName": contact.familyName,
    ]

    if !contact.organizationName.isEmpty {
      dict["organization"] = contact.organizationName
    }

    if !contact.emailAddresses.isEmpty {
      dict["emails"] = contact.emailAddresses.map { $0.value as String }
    }

    if !contact.phoneNumbers.isEmpty {
      dict["phones"] = contact.phoneNumbers.map(\.value.stringValue)
    }

    if let birthday = contact.birthday, let date = Calendar.current.date(from: birthday) {
      let formatter = DateFormatter()
      formatter.dateFormat = "MM-dd"
      dict["birthday"] = formatter.string(from: date)
    }

    return dict
  }

  private func formatContactDetailed(_ contact: CNContact) -> [String: Any] {
    var dict = self.formatContact(contact)

    if !contact.middleName.isEmpty {
      dict["middleName"] = contact.middleName
    }

    if !contact.jobTitle.isEmpty {
      dict["jobTitle"] = contact.jobTitle
    }

    if !contact.note.isEmpty {
      dict["note"] = contact.note
    }

    if !contact.postalAddresses.isEmpty {
      dict["addresses"] = contact.postalAddresses.map { address -> [String: String] in
        let postal = address.value
        return [
          "label": address.label ?? "",
          "street": postal.street,
          "city": postal.city,
          "state": postal.state,
          "postalCode": postal.postalCode,
          "country": postal.country,
        ]
      }
    }

    if !contact.urlAddresses.isEmpty {
      dict["urls"] = contact.urlAddresses.map { $0.value as String }
    }

    return dict
  }
}
