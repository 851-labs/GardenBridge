import AppKit
import ApplicationServices
import AVFoundation
import Contacts
import CoreBluetooth
@preconcurrency import CoreLocation
import EventKit
import Foundation
import Observation
import iTunesLibrary
import Photos
import ScreenCaptureKit
import UserNotifications

/// Permission status for each capability
enum PermissionStatus: String, Sendable {
  case notDetermined = "not_determined"
  case authorized
  case denied
  case restricted
  case notAvailable = "not_available"

  var isGranted: Bool {
    self == .authorized
  }
}

final class LocalNetworkAuthorizationDelegate: NSObject, NetServiceBrowserDelegate {
  private let onStatusUpdate: @MainActor (PermissionStatus) -> Void
  private let notAuthorizedErrorCode = -72008

  init(onStatusUpdate: @escaping @MainActor (PermissionStatus) -> Void) {
    self.onStatusUpdate = onStatusUpdate
  }

  func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
    Task { @MainActor in
      self.onStatusUpdate(.authorized)
    }
  }

  func netServiceBrowser(
    _ browser: NetServiceBrowser,
    didNotSearch errorDict: [String: NSNumber]
  ) {
    let code = errorDict[NetService.errorCode]?.intValue ?? 0
    let status: PermissionStatus = code == self.notAuthorizedErrorCode ? .denied : .notDetermined

    Task { @MainActor in
      self.onStatusUpdate(status)
    }
  }

  func netServiceBrowser(
    _ browser: NetServiceBrowser,
    didFind service: NetService,
    moreComing: Bool
  ) {
    Task { @MainActor in
      self.onStatusUpdate(.authorized)
    }
  }
}

/// Manages macOS permissions for all capabilities
@Observable
@MainActor
final class PermissionManager: NSObject {
  // MARK: - Permission Statuses

  var calendarStatus: PermissionStatus = .notDetermined
  var remindersStatus: PermissionStatus = .notDetermined
  var contactsStatus: PermissionStatus = .notDetermined
  var locationStatus: PermissionStatus = .notDetermined
  var cameraStatus: PermissionStatus = .notDetermined
  var microphoneStatus: PermissionStatus = .notDetermined
  var screenCaptureStatus: PermissionStatus = .notDetermined
  var accessibilityStatus: PermissionStatus = .notDetermined
  var fullDiskAccessStatus: PermissionStatus = .notDetermined
  var automationStatus: PermissionStatus = .notDetermined
  var bluetoothStatus: PermissionStatus = .notDetermined
  var notificationsStatus: PermissionStatus = .notDetermined
  var localNetworkStatus: PermissionStatus = .notDetermined
  var mediaLibraryStatus: PermissionStatus = .notDetermined
  var photosStatus: PermissionStatus = .notDetermined

  // MARK: - Services

  private let eventStore = EKEventStore()
  private var _contactStore: CNContactStore?
  private var contactStore: CNContactStore {
    if self._contactStore == nil {
      self._contactStore = CNContactStore()
    }
    return self._contactStore!
  }

  private var locationManager: CLLocationManager?
  private var locationDelegate: LocationAuthorizationDelegate?
  private var bluetoothManager: CBCentralManager?
  private var bluetoothDelegate: BluetoothAuthorizationDelegate?
  private var localNetworkServiceBrowser: NetServiceBrowser?
  private var localNetworkDelegate: LocalNetworkAuthorizationDelegate?

  private enum SettingsURL {
    static let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    static let fullDiskAccess = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    static let automation = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    static let screenRecording = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    static let microphone = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
    static let bluetooth = "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
    static let photos = "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos"
    static let mediaLibrary = "x-apple.systempreferences:com.apple.preference.security?Privacy_Media"
    static let localNetwork = "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork"
    static let notifications = "x-apple.systempreferences:com.apple.preference.notifications"
  }

  private let fullDiskAccessTestPath = "Library/Safari/Bookmarks.plist"

  override init() {
    super.init()
    self.setupLocationManager()
    self.refreshInitialStatuses()
  }

  private func setupLocationManager() {
    let manager = CLLocationManager()
    let delegate = LocationAuthorizationDelegate { [weak self] in
      Task { @MainActor in
        self?.refreshLocationStatus()
      }
    }
    manager.delegate = delegate
    self.locationManager = manager
    self.locationDelegate = delegate
  }

  // MARK: - Status Refresh

  func refreshAllStatuses() {
    self.refreshCalendarStatus()
    self.refreshRemindersStatus()
    self.refreshContactsStatus()
    self.refreshLocationStatus()
    self.refreshCameraStatus()
    self.refreshMicrophoneStatus()
    self.refreshScreenCaptureStatus()
    self.refreshAccessibilityStatus()
    self.refreshFullDiskAccessStatus()
    self.refreshAutomationStatus()
    self.refreshBluetoothStatus()
    self.refreshNotificationsStatus()
    self.refreshLocalNetworkStatus()
    self.refreshMediaLibraryStatus()
    self.refreshPhotosStatus()
  }

  func refreshCalendarStatus() {
    let status = EKEventStore.authorizationStatus(for: .event)
    self.calendarStatus = self.convertEKAuthStatus(status)
  }

  func refreshRemindersStatus() {
    let status = EKEventStore.authorizationStatus(for: .reminder)
    self.remindersStatus = self.convertEKAuthStatus(status)
  }

  func refreshContactsStatus() {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    self.contactsStatus = self.convertCNAuthStatus(status)
  }

  func refreshLocationStatus() {
    let status = self.locationManager?.authorizationStatus ?? .notDetermined
    self.locationStatus = self.convertCLAuthStatus(status)
  }

  func refreshCameraStatus() {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    self.cameraStatus = self.convertAVAuthStatus(status)
  }

  func refreshMicrophoneStatus() {
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    self.microphoneStatus = self.convertAVAuthStatus(status)
  }

  func refreshScreenCaptureStatus() {
    self.screenCaptureStatus = CGPreflightScreenCaptureAccess() ? .authorized : .notDetermined
  }

  func refreshAccessibilityStatus() {
    let trusted = AXIsProcessTrusted()
    self.accessibilityStatus = trusted ? .authorized : .denied
  }

  func refreshFullDiskAccessStatus() {
    let testPath = (NSHomeDirectory() as NSString).appendingPathComponent(self.fullDiskAccessTestPath)
    self.fullDiskAccessStatus = FileManager.default.isReadableFile(atPath: testPath) ? .authorized : .notDetermined
  }

  func refreshAutomationStatus() {
    // Automation permission is checked per-app, we'll assume not determined
    // The actual check happens when we try to run an AppleScript
    self.automationStatus = .notDetermined
  }

  func refreshBluetoothStatus() {
    let status = CBManager.authorization
    self.bluetoothStatus = self.convertCBAuthStatus(status)
  }

  func refreshNotificationsStatus() {
    Task { @MainActor in
      let settings = await UNUserNotificationCenter.current().notificationSettings()
      self.notificationsStatus = self.convertUNAuthStatus(settings.authorizationStatus)
    }
  }

  func refreshLocalNetworkStatus() {
    if self.localNetworkStatus == .notDetermined {
      self.localNetworkStatus = .notDetermined
    }
  }

  func refreshMediaLibraryStatus() {
    do {
      _ = try ITLibrary(apiVersion: "1.0")
      self.mediaLibraryStatus = .authorized
    } catch {
      self.mediaLibraryStatus = .denied
    }
  }

  func refreshPhotosStatus() {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    self.photosStatus = self.convertPHAuthStatus(status)
  }

  // MARK: - Request Permissions

  func requestCalendarAccess() async -> Bool {
    do {
      let granted = try await eventStore.requestFullAccessToEvents()
      self.refreshCalendarStatus()
      return granted
    } catch {
      print("Failed to request calendar access: \(error)")
      return false
    }
  }

  func requestRemindersAccess() async -> Bool {
    do {
      let granted = try await eventStore.requestFullAccessToReminders()
      self.refreshRemindersStatus()
      return granted
    } catch {
      print("Failed to request reminders access: \(error)")
      return false
    }
  }

  func requestContactsAccess() async -> Bool {
    do {
      let granted = try await contactStore.requestAccess(for: .contacts)
      self.refreshContactsStatus()
      return granted
    } catch {
      print("Failed to request contacts access: \(error)")
      return false
    }
  }

  func requestLocationAccess() {
    self.locationManager?.requestWhenInUseAuthorization()
  }

  func requestCameraAccess() async -> Bool {
    let granted = await AVCaptureDevice.requestAccess(for: .video)
    self.refreshCameraStatus()
    return granted
  }

  func requestMicrophoneAccess() async -> Bool {
    let granted = await AVCaptureDevice.requestAccess(for: .audio)
    self.refreshMicrophoneStatus()
    return granted
  }

  func requestNotificationsAccess() async -> Bool {
    let center = UNUserNotificationCenter.current()

    do {
      let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
      await self.updateNotificationsStatus()
      return granted
    } catch {
      print("Failed to request notification access: \(error)")
      await self.updateNotificationsStatus()
      return false
    }
  }

  func requestLocalNetworkAccess() {
    self.stopLocalNetworkProbe()

    let delegate = LocalNetworkAuthorizationDelegate { [weak self] status in
      guard let self else { return }
      self.localNetworkStatus = status

      if status == .authorized || status == .denied {
        self.stopLocalNetworkProbe()
      }
    }

    let serviceBrowser = NetServiceBrowser()
    serviceBrowser.delegate = delegate
    self.localNetworkDelegate = delegate
    self.localNetworkServiceBrowser = serviceBrowser
    serviceBrowser.searchForServices(ofType: "_http._tcp.", inDomain: "local.")
  }

  func requestMediaLibraryAccess() async -> Bool {
    do {
      _ = try ITLibrary(apiVersion: "1.0")
      self.mediaLibraryStatus = .authorized
      return true
    } catch {
      self.mediaLibraryStatus = .denied
      return false
    }
  }

  func requestPhotosAccess() async -> Bool {
    // Request authorization - this should prompt on first access
    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

    // Perform a minimal fetch to ensure the app is registered in System Settings
    if status == .authorized || status == .limited {
      let options = PHFetchOptions()
      options.fetchLimit = 1
      _ = PHAsset.fetchAssets(with: options)
    }

    self.photosStatus = self.convertPHAuthStatus(status)
    return status == .authorized || status == .limited
  }

  func requestBluetoothAccess() {
    if self.bluetoothManager == nil {
      let delegate = BluetoothAuthorizationDelegate { [weak self] in
        Task { @MainActor in
          self?.refreshBluetoothStatus()
        }
      }
      self.bluetoothDelegate = delegate
      self.bluetoothManager = CBCentralManager(delegate: delegate, queue: nil)
    } else {
      self.refreshBluetoothStatus()
    }
  }

  func requestScreenCaptureAccess() {
    // This opens System Preferences
    CGRequestScreenCaptureAccess()
    self.refreshScreenCaptureStatus()
  }

  func requestAccessibilityAccess() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    self.refreshAccessibilityStatus()
  }

  func openAccessibilitySettings() {
    self.openSystemSettings(SettingsURL.accessibility)
  }

  func openFullDiskAccessSettings() {
    self.openSystemSettings(SettingsURL.fullDiskAccess)
  }

  func openAutomationSettings() {
    self.openSystemSettings(SettingsURL.automation)
  }

  func openBluetoothSettings() {
    self.openSystemSettings(SettingsURL.bluetooth)
  }

  func openNotificationsSettings() {
    self.openSystemSettings(SettingsURL.notifications)
  }

  func openLocalNetworkSettings() {
    self.openSystemSettings(SettingsURL.localNetwork)
  }

  func openMediaLibrarySettings() {
    self.openSystemSettings(SettingsURL.mediaLibrary)
  }

  func openPhotosSettings() {
    self.openSystemSettings(SettingsURL.photos)
  }

  func openScreenRecordingSettings() {
    self.openSystemSettings(SettingsURL.screenRecording)
  }

  func openMicrophoneSettings() {
    self.openSystemSettings(SettingsURL.microphone)
  }

  // MARK: - Get Permissions Dictionary

  nonisolated func getPermissionsDictionary() -> [String: Bool] {
    // This needs to be called from main actor context
    // Return a default dictionary for protocol use
    [
      "calendar.read": true,
      "calendar.write": true,
      "contacts.read": true,
      "reminders.read": true,
      "reminders.write": true,
      "location.get": true,
      "applescript.execute": true,
      "file.read": true,
      "file.write": true,
      "accessibility.use": true,
      "screen.capture": true,
      "camera.capture": true,
      "notification.send": true,
      "shell.execute": true,
      "bluetooth.use": true,
      "localnetwork.use": true,
      "media.read": true,
      "photos.read": true,
    ]
  }

  // MARK: - Private Helpers

  private func refreshInitialStatuses() {
    self.refreshCalendarStatus()
    self.refreshRemindersStatus()
    self.refreshContactsStatus()
    self.refreshLocationStatus()
    self.refreshCameraStatus()
    self.refreshMicrophoneStatus()
    self.refreshScreenCaptureStatus()
    self.refreshAccessibilityStatus()
    self.refreshFullDiskAccessStatus()
    self.refreshAutomationStatus()
    self.refreshBluetoothStatus()
    self.refreshNotificationsStatus()
    self.refreshLocalNetworkStatus()
    self.refreshMediaLibraryStatus()
    self.refreshPhotosStatus()
  }

  @discardableResult
  private func openSystemSettings(_ urlString: String) -> Bool {
    guard let url = URL(string: urlString) else { return false }
    return NSWorkspace.shared.open(url)
  }

  private func convertEKAuthStatus(_ status: EKAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .restricted: return .restricted
    case .denied: return .denied
    case .fullAccess: return .authorized
    case .writeOnly: return .authorized
    @unknown default: return .notDetermined
    }
  }

  private func convertCNAuthStatus(_ status: CNAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .restricted: return .restricted
    case .denied: return .denied
    case .authorized: return .authorized
    @unknown default: return .notDetermined
    }
  }

  private func convertCLAuthStatus(_ status: CLAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .restricted: return .restricted
    case .denied: return .denied
    case .authorizedAlways, .authorizedWhenInUse: return .authorized
    @unknown default: return .notDetermined
    }
  }

  private func convertAVAuthStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .restricted: return .restricted
    case .denied: return .denied
    case .authorized: return .authorized
    @unknown default: return .notDetermined
    }
  }

  private func convertUNAuthStatus(_ status: UNAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .denied: return .denied
    case .authorized, .provisional, .ephemeral: return .authorized
    @unknown default: return .notDetermined
    }
  }

  private func convertPHAuthStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .restricted: return .restricted
    case .denied: return .denied
    case .authorized, .limited: return .authorized
    @unknown default: return .notDetermined
    }
  }


  private func stopLocalNetworkProbe() {
    self.localNetworkServiceBrowser?.stop()
    self.localNetworkServiceBrowser = nil
    self.localNetworkDelegate = nil
  }

  private func updateNotificationsStatus() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    self.notificationsStatus = self.convertUNAuthStatus(settings.authorizationStatus)
  }

  private func convertCBAuthStatus(_ status: CBManagerAuthorization) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .restricted: return .restricted
    case .denied: return .denied
    case .allowedAlways: return .authorized
    @unknown default: return .notDetermined
    }
  }
}

// MARK: - Location Authorization Delegate

private final class LocationAuthorizationDelegate: NSObject, CLLocationManagerDelegate {
  private let onAuthorizationChange: @Sendable () -> Void

  init(onAuthorizationChange: @escaping @Sendable () -> Void) {
    self.onAuthorizationChange = onAuthorizationChange
    super.init()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    self.onAuthorizationChange()
  }
}

private final class BluetoothAuthorizationDelegate: NSObject, CBCentralManagerDelegate {
  private let onAuthorizationChange: @Sendable () -> Void

  init(onAuthorizationChange: @escaping @Sendable () -> Void) {
    self.onAuthorizationChange = onAuthorizationChange
    super.init()
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    self.onAuthorizationChange()
  }
}
