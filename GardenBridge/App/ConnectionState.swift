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
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected (awaiting pairing)"
        case .paired:
            return "Connected & Paired"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var statusColor: String {
        switch self {
        case .disconnected:
            return "gray"
        case .connecting:
            return "yellow"
        case .connected:
            return "orange"
        case .paired:
            return "green"
        case .error:
            return "red"
        }
    }
    
    var isConnected: Bool {
        switch self {
        case .connected, .paired:
            return true
        default:
            return false
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
    
    /// The full WebSocket URL for the gateway
    var gatewayURL: URL? {
        URL(string: "ws://\(gatewayHost):\(gatewayPort)")
    }
    
    /// Persisted settings keys
    private enum Keys {
        static let gatewayHost = "gatewayHost"
        static let gatewayPort = "gatewayPort"
        static let deviceToken = "deviceToken"
        static let autoConnect = "autoConnect"
    }
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        let defaults = UserDefaults.standard
        if let host = defaults.string(forKey: Keys.gatewayHost), !host.isEmpty {
            gatewayHost = host
        }
        if defaults.object(forKey: Keys.gatewayPort) != nil {
            gatewayPort = defaults.integer(forKey: Keys.gatewayPort)
        }
        deviceToken = defaults.string(forKey: Keys.deviceToken)
        autoConnect = defaults.object(forKey: Keys.autoConnect) as? Bool ?? true
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(gatewayHost, forKey: Keys.gatewayHost)
        defaults.set(gatewayPort, forKey: Keys.gatewayPort)
        defaults.set(deviceToken, forKey: Keys.deviceToken)
        defaults.set(autoConnect, forKey: Keys.autoConnect)
    }
    
    func setStatus(_ newStatus: GatewayConnectionStatus) {
        status = newStatus
        if case .error(let message) = newStatus {
            lastError = message
        }
    }
    
    func clearError() {
        lastError = nil
    }
}
