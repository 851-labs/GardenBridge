import Foundation

// MARK: - Command Types

/// Error structure for command responses
struct GatewayError: Codable, Sendable {
  let code: String
  let message: String
}

/// Invoke message (command request)
struct GatewayInvoke: Codable, Sendable {
  let type: String
  let id: String
  let command: String
  let params: [String: AnyCodable]?
}

/// Invoke response message
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
      self.value = NSNull()
    } else if let bool = try? container.decode(Bool.self) {
      self.value = bool
    } else if let int = try? container.decode(Int.self) {
      self.value = int
    } else if let double = try? container.decode(Double.self) {
      self.value = double
    } else if let string = try? container.decode(String.self) {
      self.value = string
    } else if let array = try? container.decode([AnyCodable].self) {
      self.value = array.map(\.value)
    } else if let dictionary = try? container.decode([String: AnyCodable].self) {
      self.value = dictionary.mapValues { $0.value }
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self.value {
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
      throw EncodingError.invalidValue(
        self.value,
        EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type"))
    }
  }

  static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
    switch (lhs.value, rhs.value) {
    case let (l as Bool, r as Bool): l == r
    case let (l as Int, r as Int): l == r
    case let (l as Double, r as Double): l == r
    case let (l as String, r as String): l == r
    case (is NSNull, is NSNull): true
    default: false
    }
  }

  func hash(into hasher: inout Hasher) {
    switch self.value {
    case let bool as Bool: hasher.combine(bool)
    case let int as Int: hasher.combine(int)
    case let double as Double: hasher.combine(double)
    case let string as String: hasher.combine(string)
    default: hasher.combine(0)
    }
  }

  // MARK: - Convenience accessors

  var stringValue: String? {
    self.value as? String
  }

  var intValue: Int? {
    self.value as? Int
  }

  var doubleValue: Double? {
    self.value as? Double
  }

  var boolValue: Bool? {
    self.value as? Bool
  }

  var arrayValue: [Any]? {
    self.value as? [Any]
  }

  var dictionaryValue: [String: Any]? {
    self.value as? [String: Any]
  }
}
