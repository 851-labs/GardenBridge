import Foundation
import Observation
import EventKit
import Contacts
@preconcurrency import CoreLocation
import AVFoundation
import ScreenCaptureKit
import AppKit

/// Permission status for each capability
enum PermissionStatus: String, Sendable {
    case notDetermined = "not_determined"
    case authorized = "authorized"
    case denied = "denied"
    case restricted = "restricted"
    case notAvailable = "not_available"
    
    var isGranted: Bool {
        self == .authorized
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
    
    // MARK: - Services

    private let eventStore = EKEventStore()
    private var _contactStore: CNContactStore?
    private var contactStore: CNContactStore {
        if _contactStore == nil {
            _contactStore = CNContactStore()
        }
        return _contactStore!
    }
    private var locationManager: CLLocationManager?
    private var locationDelegate: LocationAuthorizationDelegate?

    private enum SettingsURL {
        static let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        static let fullDiskAccess = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        static let automation = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        static let screenRecording = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        static let microphone = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
    }

    private let fullDiskAccessTestPath = "Library/Safari/Bookmarks.plist"
    
    override init() {
        super.init()
        setupLocationManager()
        refreshInitialStatuses()
    }
    
    private func setupLocationManager() {
        let manager = CLLocationManager()
        let delegate = LocationAuthorizationDelegate { [weak self] in
            Task { @MainActor in
                self?.refreshLocationStatus()
            }
        }
        manager.delegate = delegate
        locationManager = manager
        locationDelegate = delegate
    }
    
    
    // MARK: - Status Refresh
    
    func refreshAllStatuses() {
        refreshCalendarStatus()
        refreshRemindersStatus()
        // Skip refreshContactsStatus() here - it triggers Apple framework warnings
        // Contacts status is only checked after user requests access
        if _contactStore != nil {
            refreshContactsStatus()
        }
        refreshLocationStatus()
        refreshCameraStatus()
        refreshMicrophoneStatus()
        refreshScreenCaptureStatus()
        refreshAccessibilityStatus()
        refreshFullDiskAccessStatus()
        refreshAutomationStatus()
    }
    
    func refreshCalendarStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        calendarStatus = convertEKAuthStatus(status)
    }
    
    func refreshRemindersStatus() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        remindersStatus = convertEKAuthStatus(status)
    }
    
    func refreshContactsStatus() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        contactsStatus = convertCNAuthStatus(status)
    }
    
    func refreshLocationStatus() {
        let status = locationManager?.authorizationStatus ?? .notDetermined
        locationStatus = convertCLAuthStatus(status)
    }
    
    func refreshCameraStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraStatus = convertAVAuthStatus(status)
    }
    
    func refreshMicrophoneStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneStatus = convertAVAuthStatus(status)
    }
    
    func refreshScreenCaptureStatus() {
        screenCaptureStatus = CGPreflightScreenCaptureAccess() ? .authorized : .notDetermined
    }
    
    func refreshAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        accessibilityStatus = trusted ? .authorized : .notDetermined
    }
    
    func refreshFullDiskAccessStatus() {
        let testPath = (NSHomeDirectory() as NSString).appendingPathComponent(fullDiskAccessTestPath)
        fullDiskAccessStatus = FileManager.default.isReadableFile(atPath: testPath) ? .authorized : .notDetermined
    }
    
    func refreshAutomationStatus() {
        // Automation permission is checked per-app, we'll assume not determined
        // The actual check happens when we try to run an AppleScript
        automationStatus = .notDetermined
    }
    
    // MARK: - Request Permissions
    
    func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            refreshCalendarStatus()
            return granted
        } catch {
            print("Failed to request calendar access: \(error)")
            return false
        }
    }
    
    func requestRemindersAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            refreshRemindersStatus()
            return granted
        } catch {
            print("Failed to request reminders access: \(error)")
            return false
        }
    }
    
    func requestContactsAccess() async -> Bool {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            refreshContactsStatus()
            return granted
        } catch {
            print("Failed to request contacts access: \(error)")
            return false
        }
    }
    
    func requestLocationAccess() {
        locationManager?.requestWhenInUseAuthorization()
    }
    
    func requestCameraAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        refreshCameraStatus()
        return granted
    }
    
    func requestMicrophoneAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        refreshMicrophoneStatus()
        return granted
    }
    
    func requestScreenCaptureAccess() {
        // This opens System Preferences
        CGRequestScreenCaptureAccess()
        refreshScreenCaptureStatus()
    }
    
    func openAccessibilitySettings() {
        openSystemSettings(SettingsURL.accessibility)
    }
    
    func openFullDiskAccessSettings() {
        openSystemSettings(SettingsURL.fullDiskAccess)
    }
    
    func openAutomationSettings() {
        openSystemSettings(SettingsURL.automation)
    }
    
    func openScreenRecordingSettings() {
        openSystemSettings(SettingsURL.screenRecording)
    }

    func openMicrophoneSettings() {
        openSystemSettings(SettingsURL.microphone)
    }
    
    // MARK: - Get Permissions Dictionary
    
    nonisolated func getPermissionsDictionary() -> [String: Bool] {
        // This needs to be called from main actor context
        // Return a default dictionary for protocol use
        return [
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
            "shell.execute": true
        ]
    }
    
    // MARK: - Private Helpers

    private func refreshInitialStatuses() {
        refreshCalendarStatus()
        refreshRemindersStatus()
        refreshLocationStatus()
        refreshCameraStatus()
        refreshMicrophoneStatus()
        refreshScreenCaptureStatus()
        refreshAccessibilityStatus()
        refreshFullDiskAccessStatus()
        refreshAutomationStatus()
    }

    private func openSystemSettings(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
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
}

// MARK: - Location Authorization Delegate

private final class LocationAuthorizationDelegate: NSObject, CLLocationManagerDelegate {
    private let onAuthorizationChange: @Sendable () -> Void

    init(onAuthorizationChange: @escaping @Sendable () -> Void) {
        self.onAuthorizationChange = onAuthorizationChange
        super.init()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange()
    }
}
