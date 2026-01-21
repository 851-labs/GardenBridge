import SwiftUI

/// Settings view for configuring the gateway connection and managing permissions
struct SettingsView: View {
    @Environment(ConnectionState.self) private var connectionState
    @Environment(PermissionManager.self) private var permissionManager
    
    var body: some View {
        TabView {
            ConnectionSettingsTab()
                .environment(connectionState)
                .tabItem {
                    Label("Connection", systemImage: "network")
                }
            
            PermissionsTab()
                .environment(permissionManager)
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
            
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Connection Settings Tab

struct ConnectionSettingsTab: View {
    @Environment(ConnectionState.self) private var connectionState
    
    var body: some View {
        @Bindable var state = connectionState
        
        Form {
            Section {
                TextField("Gateway Host", text: $state.gatewayHost)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Port", value: $state.gatewayPort, format: .number)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Auto-connect on launch", isOn: $state.autoConnect)
            } header: {
                Text("Gateway Connection")
            }
            
            Section {
                HStack {
                    Text("Status:")
                    Spacer()
                    Text(connectionState.status.displayText)
                        .foregroundStyle(statusColor)
                }
                
                if connectionState.status.isConnected {
                    Button("Disconnect") {
                        Task { @MainActor in
                            if let appDelegate = NSApp.delegate as? AppDelegate {
                                await appDelegate.disconnectFromGateway()
                            }
                        }
                    }
                } else {
                    Button("Connect") {
                        Task { @MainActor in
                            if let appDelegate = NSApp.delegate as? AppDelegate {
                                await appDelegate.connectToGateway()
                            }
                        }
                    }
                }
            } header: {
                Text("Connection Status")
            }
            
            Section {
                Button("Save Settings") {
                    connectionState.saveSettings()
                }
            }
        }
        .padding()
    }
    
    private var statusColor: Color {
        switch connectionState.status {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .orange
        case .paired: return .green
        case .error: return .red
        }
    }
}

// MARK: - Permissions Tab

struct PermissionsTab: View {
    @Environment(PermissionManager.self) private var permissionManager
    
    var body: some View {
        Form {
            Section {
                PermissionRow(
                    name: "Calendar",
                    status: permissionManager.calendarStatus,
                    action: {
                        Task {
                            _ = await permissionManager.requestCalendarAccess()
                            bringToFront()
                        }
                    }
                )
                
                PermissionRow(
                    name: "Reminders",
                    status: permissionManager.remindersStatus,
                    action: {
                        Task {
                            _ = await permissionManager.requestRemindersAccess()
                            bringToFront()
                        }
                    }
                )
                
                PermissionRow(
                    name: "Contacts",
                    status: permissionManager.contactsStatus,
                    action: {
                        Task {
                            _ = await permissionManager.requestContactsAccess()
                            bringToFront()
                        }
                    }
                )
                
                PermissionRow(
                    name: "Location",
                    status: permissionManager.locationStatus,
                    action: {
                        permissionManager.requestLocationAccess()
                        // Refresh after a delay since location auth is async
                        Task {
                            try? await Task.sleep(for: .seconds(1))
                            permissionManager.refreshLocationStatus()
                            bringToFront()
                        }
                    }
                )
                
                PermissionRow(
                    name: "Camera",
                    status: permissionManager.cameraStatus,
                    action: {
                        Task {
                            _ = await permissionManager.requestCameraAccess()
                            bringToFront()
                        }
                    }
                )
                
                PermissionRow(
                    name: "Microphone",
                    status: permissionManager.microphoneStatus,
                    action: {
                        Task {
                            _ = await permissionManager.requestMicrophoneAccess()
                            bringToFront()
                        }
                    }
                )
            } header: {
                Text("System Permissions")
            }
            
            Section {
                PermissionRow(
                    name: "Screen Recording",
                    status: permissionManager.screenCaptureStatus,
                    action: { permissionManager.openScreenRecordingSettings() },
                    opensSettings: true
                )
                
                PermissionRow(
                    name: "Accessibility",
                    status: permissionManager.accessibilityStatus,
                    action: { permissionManager.openAccessibilitySettings() },
                    opensSettings: true
                )
                
                PermissionRow(
                    name: "Full Disk Access",
                    status: permissionManager.fullDiskAccessStatus,
                    action: { permissionManager.openFullDiskAccessSettings() },
                    opensSettings: true
                )
                
                PermissionRow(
                    name: "Automation",
                    status: permissionManager.automationStatus,
                    action: { permissionManager.openAutomationSettings() },
                    opensSettings: true
                )
            } header: {
                Text("Privacy & Security Settings")
            } footer: {
                Text("These permissions require manual approval in System Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                Button("Refresh All") {
                    permissionManager.refreshAllStatuses()
                }
            }
        }
        .padding()
        .onAppear {
            permissionManager.refreshAllStatuses()
        }
    }
    
    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let name: String
    let status: PermissionStatus
    let action: () -> Void
    var opensSettings: Bool = false
    
    var body: some View {
        HStack {
            Text(name)
            
            Spacer()
            
            statusBadge
            
            if status != .authorized {
                Button(opensSettings ? "Open Settings" : "Request") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .authorized: return .green
        case .denied, .restricted: return .red
        case .notDetermined, .notAvailable: return .gray
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text("GardenBridge")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("A Clawdbot Node for macOS")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Divider()
                .frame(width: 200)
            
            Text("GardenBridge connects your macOS system to the Clawdbot Gateway, allowing AI assistants to interact with your calendar, contacts, reminders, files, and more.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Spacer()
            
            Text("2026 851 Labs")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
        .environment(ConnectionState())
        .environment(PermissionManager())
}
