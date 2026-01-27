@preconcurrency import CoreBluetooth
import Foundation

/// Handles Bluetooth commands using CoreBluetooth
actor BluetoothCommands: CommandExecutor {
  private var centralManager: CBCentralManager?
  private var delegate: BluetoothScanDelegate?
  private var stateContinuation: CheckedContinuation<CBManagerState, Never>?
  private var discoveredDevices: [UUID: [String: Any]] = [:]

  func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
    switch command {
    case "bluetooth.status":
      return try await self.status()
    case "bluetooth.scan":
      return try await self.scan(params: params)
    case "bluetooth.devices":
      return try await self.devices()
    default:
      throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown bluetooth command: \(command)")
    }
  }

  // MARK: - Status

  private func status() async throws -> AnyCodable {
    let manager = await self.ensureManager()
    let state = manager.state

    return AnyCodable([
      "state": self.stateString(state),
      "authorization": self.authorizationString(CBManager.authorization),
    ])
  }

  // MARK: - Scan

  private func scan(params: [String: AnyCodable]) async throws -> AnyCodable {
    let manager = await self.ensureManager()
    let duration = min(max(params["duration"]?.doubleValue ?? 5, 1), 60)
    let serviceUUIDs = self.parseServiceUUIDs(params["serviceUUIDs"])

    let state = await self.waitForState(manager: manager)
    switch state {
    case .poweredOn:
      break
    case .unauthorized:
      throw CommandError.permissionDenied
    case .poweredOff:
      throw CommandError(code: "BLUETOOTH_POWERED_OFF", message: "Bluetooth is powered off")
    case .unsupported:
      throw CommandError(code: "BLUETOOTH_UNSUPPORTED", message: "Bluetooth is unsupported")
    default:
      throw CommandError(code: "BLUETOOTH_UNAVAILABLE", message: "Bluetooth is unavailable")
    }

    self.discoveredDevices = [:]

    await MainActor.run {
      manager.scanForPeripherals(withServices: serviceUUIDs, options: [
        CBCentralManagerScanOptionAllowDuplicatesKey: false,
      ])
    }

    try? await Task.sleep(for: .seconds(duration))

    await MainActor.run {
      manager.stopScan()
    }

    let devices = Array(self.discoveredDevices.values)
    return AnyCodable([
      "count": devices.count,
      "devices": devices,
    ])
  }

  // MARK: - Devices

  private func devices() async throws -> AnyCodable {
    return AnyCodable([
      "count": self.discoveredDevices.count,
      "devices": Array(self.discoveredDevices.values),
    ])
  }

  // MARK: - Helpers

  private func ensureManager() async -> CBCentralManager {
    if let centralManager {
      return centralManager
    }

    let delegate = BluetoothScanDelegate(
      onStateUpdate: { [weak self] state in
        Task { await self?.handleStateUpdate(state) }
      },
      onDiscover: { [weak self] peripheral, data, rssi in
        Task { await self?.handleDiscover(peripheral: peripheral, data: data, rssi: rssi) }
      })

    let manager = await MainActor.run {
      CBCentralManager(delegate: delegate, queue: nil)
    }

    self.centralManager = manager
    self.delegate = delegate
    return manager
  }

  private func waitForState(manager: CBCentralManager) async -> CBManagerState {
    if manager.state != .unknown && manager.state != .resetting {
      return manager.state
    }

    return await withCheckedContinuation { continuation in
      self.stateContinuation = continuation
      Task {
        try? await Task.sleep(for: .seconds(2))
        await self.handleStateUpdate(manager.state)
      }
    }
  }

  private func handleStateUpdate(_ state: CBManagerState) {
    self.stateContinuation?.resume(returning: state)
    self.stateContinuation = nil
  }

  private func handleDiscover(peripheral: CBPeripheral, data: [String: Any], rssi: NSNumber) {
    var entry: [String: Any] = [
      "id": peripheral.identifier.uuidString,
      "rssi": rssi.intValue,
    ]

    if let name = peripheral.name {
      entry["name"] = name
    }

    if let advertisedName = data[CBAdvertisementDataLocalNameKey] as? String {
      entry["advertisedName"] = advertisedName
    }

    if let serviceUUIDs = data[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
      entry["serviceUUIDs"] = serviceUUIDs.map { $0.uuidString }
    }

    if let manufacturerData = data[CBAdvertisementDataManufacturerDataKey] as? Data {
      entry["manufacturerData"] = manufacturerData.base64EncodedString()
    }

    self.discoveredDevices[peripheral.identifier] = entry
  }

  private func parseServiceUUIDs(_ value: AnyCodable?) -> [CBUUID]? {
    guard let array = value?.value as? [Any] else { return nil }
    let uuids = array.compactMap { item -> CBUUID? in
      if let string = item as? String {
        return CBUUID(string: string)
      }
      return nil
    }
    return uuids.isEmpty ? nil : uuids
  }

  private func stateString(_ state: CBManagerState) -> String {
    switch state {
    case .unknown: return "unknown"
    case .resetting: return "resetting"
    case .unsupported: return "unsupported"
    case .unauthorized: return "unauthorized"
    case .poweredOff: return "poweredOff"
    case .poweredOn: return "poweredOn"
    @unknown default: return "unknown"
    }
  }

  private func authorizationString(_ status: CBManagerAuthorization) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .allowedAlways: return "allowed"
    @unknown default: return "unknown"
    }
  }
}

private final class BluetoothScanDelegate: NSObject, CBCentralManagerDelegate {
  private let onStateUpdate: @Sendable (CBManagerState) -> Void
  private let onDiscover: @Sendable (CBPeripheral, [String: Any], NSNumber) -> Void

  init(
    onStateUpdate: @escaping @Sendable (CBManagerState) -> Void,
    onDiscover: @escaping @Sendable (CBPeripheral, [String: Any], NSNumber) -> Void
  ) {
    self.onStateUpdate = onStateUpdate
    self.onDiscover = onDiscover
    super.init()
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    self.onStateUpdate(central.state)
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    self.onDiscover(peripheral, advertisementData, RSSI)
  }
}
