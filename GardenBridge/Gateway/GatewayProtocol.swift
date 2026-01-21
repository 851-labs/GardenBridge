import Foundation

// MARK: - Protocol Version
let GATEWAY_PROTOCOL_VERSION = 3

// MARK: - Message Types

/// Base protocol message envelope
enum GatewayMessageType: String, Codable, Sendable {
    case req
    case res
    case event
    case invoke
    case invokeRes = "invoke-res"
    case ping
    case pong
}

/// Request message sent to gateway
struct GatewayRequest: Codable, Sendable {
    let type: String
    let id: String
    let method: String
    let params: [String: AnyCodable]?
    
    init(type: String = "req", id: String = UUID().uuidString, method: String, params: [String: AnyCodable]? = nil) {
        self.type = type
        self.id = id
        self.method = method
        self.params = params
    }
}

/// Response message from gateway
struct GatewayResponse: Codable, Sendable {
    let type: String
    let id: String
    let ok: Bool
    let payload: AnyCodable?
    let error: GatewayError?
}

/// Error structure
struct GatewayError: Codable, Sendable {
    let code: String
    let message: String
}

/// Event message from gateway
struct GatewayEvent: Codable, Sendable {
    let type: String
    let event: String
    let payload: AnyCodable?
    let seq: Int?
    let stateVersion: Int?
}

/// Invoke message from gateway (command request to node)
struct GatewayInvoke: Codable, Sendable {
    let type: String
    let id: String
    let command: String
    let params: [String: AnyCodable]?
}

/// Invoke response message to gateway
struct GatewayInvokeResponse: Codable, Sendable {
    let type: String
    let id: String
    let ok: Bool
    let payload: AnyCodable?
    let error: GatewayError?
    
    init(type: String = "invoke-res", id: String, ok: Bool, payload: AnyCodable? = nil, error: GatewayError? = nil) {
        self.type = type
        self.id = id
        self.ok = ok
        self.payload = payload
        self.error = error
    }
    
    static func success(id: String, payload: AnyCodable? = nil) -> GatewayInvokeResponse {
        GatewayInvokeResponse(id: id, ok: true, payload: payload)
    }
    
    static func failure(id: String, code: String, message: String) -> GatewayInvokeResponse {
        GatewayInvokeResponse(id: id, ok: false, error: GatewayError(code: code, message: message))
    }
}

// MARK: - Connect Request/Response

/// Client information sent during connect
struct ClientInfo: Codable, Sendable {
    let id: String
    let version: String
    let platform: String
    let mode: String
}

/// Device identity for pairing
struct DeviceInfo: Codable, Sendable {
    let id: String
    let publicKey: String?
    let signature: String?
    let signedAt: Int64?
    let nonce: String?
}

/// Auth information
struct AuthInfo: Codable, Sendable {
    let token: String?
    let deviceToken: String?
}

/// Connect request parameters
struct ConnectParams: Codable, Sendable {
    let minProtocol: Int
    let maxProtocol: Int
    let client: ClientInfo
    let role: String
    let scopes: [String]
    let caps: [String]
    let commands: [String]
    let permissions: [String: Bool]
    let auth: AuthInfo?
    let locale: String
    let userAgent: String
    let device: DeviceInfo
}

/// Hello-OK response payload
struct HelloOkPayload: Codable, Sendable {
    let type: String
    let `protocol`: Int
    let policy: PolicyInfo?
    let auth: AuthResponseInfo?
}

struct PolicyInfo: Codable, Sendable {
    let tickIntervalMs: Int?
}

struct AuthResponseInfo: Codable, Sendable {
    let deviceToken: String?
    let role: String?
    let scopes: [String]?
}

// MARK: - Challenge Event

struct ConnectChallengePayload: Codable, Sendable {
    let nonce: String
    let ts: Int64
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for dynamic JSON values
struct AnyCodable: Codable, Hashable, @unchecked Sendable {
    nonisolated(unsafe) let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int64 as Int64:
            try container.encode(int64)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Simple equality check for common types
        switch (lhs.value, rhs.value) {
        case (let l as Bool, let r as Bool): return l == r
        case (let l as Int, let r as Int): return l == r
        case (let l as Double, let r as Double): return l == r
        case (let l as String, let r as String): return l == r
        case (is NSNull, is NSNull): return true
        default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch value {
        case let bool as Bool: hasher.combine(bool)
        case let int as Int: hasher.combine(int)
        case let double as Double: hasher.combine(double)
        case let string as String: hasher.combine(string)
        default: hasher.combine(0)
        }
    }
    
    // MARK: - Convenience accessors
    
    var stringValue: String? {
        value as? String
    }
    
    var intValue: Int? {
        value as? Int
    }
    
    var doubleValue: Double? {
        value as? Double
    }
    
    var boolValue: Bool? {
        value as? Bool
    }
    
    var arrayValue: [Any]? {
        value as? [Any]
    }
    
    var dictionaryValue: [String: Any]? {
        value as? [String: Any]
    }
}

// MARK: - Capability Definitions

/// All capabilities that GardenBridge can provide
enum NodeCapability: String, CaseIterable, Sendable {
    case calendar
    case contacts
    case reminders
    case location
    case applescript
    case filesystem
    case accessibility
    case screen
    case camera
    case notifications
    case shell
}

/// All commands that GardenBridge can handle
enum NodeCommand: String, CaseIterable, Sendable {
    // Calendar
    case calendarList = "calendar.list"
    case calendarCreate = "calendar.create"
    case calendarUpdate = "calendar.update"
    case calendarDelete = "calendar.delete"
    case calendarGetCalendars = "calendar.getCalendars"
    
    // Contacts
    case contactsSearch = "contacts.search"
    case contactsGet = "contacts.get"
    case contactsBirthdays = "contacts.birthdays"
    
    // Reminders
    case remindersList = "reminders.list"
    case remindersCreate = "reminders.create"
    case remindersComplete = "reminders.complete"
    case remindersDelete = "reminders.delete"
    case remindersGetLists = "reminders.getLists"
    
    // Location
    case locationGet = "location.get"
    
    // AppleScript
    case applescriptExecute = "applescript.execute"
    
    // FileSystem
    case fileRead = "file.read"
    case fileWrite = "file.write"
    case fileList = "file.list"
    case fileExists = "file.exists"
    case fileDelete = "file.delete"
    case fileInfo = "file.info"
    
    // Accessibility
    case accessibilityClick = "accessibility.click"
    case accessibilityType = "accessibility.type"
    case accessibilityGetElement = "accessibility.getElement"
    case accessibilityGetWindows = "accessibility.getWindows"
    
    // Screen
    case screenCapture = "screen.capture"
    case screenList = "screen.list"
    
    // Camera
    case cameraSnap = "camera.snap"
    case cameraList = "camera.list"
    
    // Notifications
    case notificationSend = "notification.send"
    
    // Shell
    case shellExecute = "shell.execute"
    case shellWhich = "shell.which"
}
