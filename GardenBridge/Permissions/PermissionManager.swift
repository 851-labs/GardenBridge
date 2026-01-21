import Foundation
import Observation
import EventKit
import Contacts
import CoreLocation
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
final class PermissionManager: NSObject, CLLocationManagerDelegate {
    // Permission statuses
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
    
    // Services
    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()
    private var locationManager: CLLocationManager?
    
    override init() {
        super.init()
        setupLocationManager()
        refreshAllStatuses()
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
    }
    
    // MARK: - CLLocationManagerDelegate
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            refreshLocationStatus()
        }
    }
    
    // MARK: - Status Refresh
    
    func refreshAllStatuses() {
        refreshCalendarStatus()
        refreshRemindersStatus()
        refreshContactsStatus()
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
        // Screen capture permission is checked differently
        // We check if we can get the display list
        if CGPreflightScreenCaptureAccess() {
            screenCaptureStatus = .authorized
        } else {
            screenCaptureStatus = .notDetermined
        }
    }
    
    func refreshAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        accessibilityStatus = trusted ? .authorized : .notDetermined
    }
    
    func refreshFullDiskAccessStatus() {
        // Check full disk access by trying to read a protected file
        let testPath = "\(NSHomeDirectory())/Library/Safari/Bookmarks.plist"
        if FileManager.default.isReadableFile(atPath: testPath) {
            fullDiskAccessStatus = .authorized
        } else {
            fullDiskAccessStatus = .notDetermined
        }
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
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
    
    func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
    
    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
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
