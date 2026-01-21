import Foundation
import Observation

/// Represents the current connection state to the Clawdbot Gateway
enum GatewayConnectionStatus: Equatable, Sendable {
  case disconnected
  case connecting
  case connected
  case paired
  case error(String)

  var displayText: String {
    switch self {
    case .disconnected:
      "Disconnected"
    case .connecting:
      "Connecting..."
    case .connected:
      "Connected (awaiting pairing)"
    case .paired:
      "Connected & Paired"
    case let .error(message):
      "Error: \(message)"
    }
  }

  var statusColor: String {
    switch self {
    case .disconnected:
      "gray"
    case .connecting:
      "yellow"
    case .connected:
      "orange"
    case .paired:
      "green"
    case .error:
      "red"
    }
  }

  var isConnected: Bool {
    switch self {
    case .connected, .paired:
      true
    default:
      false
    }
  }
}

/// Observable state for the gateway connection
@Observable
@MainActor
final class ConnectionState {
  var status: GatewayConnectionStatus = .disconnected
  var gatewayHost: String = "127.0.0.1"
  var gatewayPort: Int = 18789
  var deviceToken: String?
  var lastError: String?
  var autoConnect: Bool = true

  init() {
    self.loadSettings()
  }

  /// The full WebSocket URL for the gateway
  var gatewayURL: URL? {
    URL(string: "ws://\(self.gatewayHost):\(self.gatewayPort)")
  }

  func loadSettings() {
    let defaults = UserDefaults.standard
    if let host = defaults.string(forKey: Keys.gatewayHost), !host.isEmpty {
      self.gatewayHost = host
    }
    if defaults.object(forKey: Keys.gatewayPort) != nil {
      self.gatewayPort = defaults.integer(forKey: Keys.gatewayPort)
    }
    self.deviceToken = defaults.string(forKey: Keys.deviceToken)
    self.autoConnect = defaults.object(forKey: Keys.autoConnect) as? Bool ?? true
  }

  func saveSettings() {
    let defaults = UserDefaults.standard
    defaults.set(self.gatewayHost, forKey: Keys.gatewayHost)
    defaults.set(self.gatewayPort, forKey: Keys.gatewayPort)
    defaults.set(self.deviceToken, forKey: Keys.deviceToken)
    defaults.set(self.autoConnect, forKey: Keys.autoConnect)
  }

  func setStatus(_ newStatus: GatewayConnectionStatus) {
    self.status = newStatus
    if case let .error(message) = newStatus {
      self.lastError = message
    }
  }

  func clearError() {
    self.lastError = nil
  }

  /// Persisted settings keys
  private enum Keys {
    static let gatewayHost = "gatewayHost"
    static let gatewayPort = "gatewayPort"
    static let deviceToken = "deviceToken"
    static let autoConnect = "autoConnect"
  }
}
