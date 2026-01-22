import SwiftUI

/// Settings view for configuring the gateway connection and managing permissions
struct SettingsView: View {
  @Environment(ConnectionState.self) private var connectionState
  @Environment(PermissionManager.self) private var permissionManager

  var body: some View {
    TabView {
      ConnectionSettingsTab()
        .environment(self.connectionState)
        .tabItem {
          Label("Connection", systemImage: "network")
        }

      PermissionsTab()
        .environment(self.permissionManager)
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
    @Bindable var state = self.connectionState

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
      self.statusSection
      self.saveSection
    }
    .padding()
  }

  private var statusSection: some View {
    Section {
      HStack {
        Text("Status:")
        Spacer()
        Text(self.connectionState.status.displayText)
          .foregroundStyle(self.statusColor)
      }

      if self.connectionState.status.isConnected {
        Button("Disconnect", action: self.disconnect)
      } else {
        Button("Connect", action: self.connect)
      }
    } header: {
      Text("Connection Status")
    }
  }

  private var saveSection: some View {
    Section {
      Button("Save Settings") {
        self.connectionState.saveSettings()
      }
    }
  }

  private var statusColor: Color {
    switch self.connectionState.status {
    case .disconnected: .gray
    case .connecting: .yellow
    case .connected: .orange
    case .paired: .green
    case .error: .red
    }
  }

  private func connect() {
    Task { @MainActor in
      if let appDelegate = NSApp.delegate as? AppDelegate {
        await appDelegate.connectToGateway()
      }
    }
  }

  private func disconnect() {
    Task { @MainActor in
      if let appDelegate = NSApp.delegate as? AppDelegate {
        await appDelegate.disconnectFromGateway()
      }
    }
  }
}

// MARK: - Permissions Tab

struct PermissionsTab: View {
  @Environment(PermissionManager.self) private var permissionManager

  private let bringToFrontDelay = Duration.milliseconds(200)

  var body: some View {
    Form {
      self.privacyPermissionsSection
      self.securityPermissionsSection
      self.refreshSection
    }
    .formStyle(.grouped)
    .onAppear {
      self.permissionManager.refreshAllStatuses()
    }
  }

  private var privacyPermissionsSection: some View {
    Section {
      PermissionRow(
        name: "Location",
        systemImage: "location",
        status: self.permissionManager.locationStatus,
        action: {
          self.permissionManager.requestLocationAccess()
          Task { @MainActor in
            await self.bringToFront()
          }
        })

      PermissionRow(
        name: "Calendar",
        systemImage: "calendar",
        status: self.permissionManager.calendarStatus,
        action: {
          self.performPermissionRequest {
            _ = await self.permissionManager.requestCalendarAccess()
          }
        })

      PermissionRow(
        name: "Contacts",
        systemImage: "person.crop.circle",
        status: self.permissionManager.contactsStatus,
        action: {
          self.performPermissionRequest {
            _ = await self.permissionManager.requestContactsAccess()
          }
        })

      PermissionRow(
        name: "Reminders",
        systemImage: "checklist",
        status: self.permissionManager.remindersStatus,
        action: {
          self.performPermissionRequest {
            _ = await self.permissionManager.requestRemindersAccess()
          }
        })

      PermissionRow(
        name: "Photos",
        systemImage: "photo",
        status: self.permissionManager.photosStatus,
        action: {
          if self.permissionManager.photosStatus == .denied
            || self.permissionManager.photosStatus == .restricted
          {
            self.permissionManager.openPhotosSettings()
          } else {
            self.performPermissionRequest {
              _ = await self.permissionManager.requestPhotosAccess()
            }
          }
        },
        opensSettings: self.permissionManager.photosStatus == .denied
          || self.permissionManager.photosStatus == .restricted)

      PermissionRow(
        name: "Media & Apple Music",
        systemImage: "music.note.list",
        status: self.permissionManager.mediaLibraryStatus,
        action: {
          self.permissionManager.requestMediaLibraryAccess()
        },
        opensSettings: true)

      PermissionRow(
        name: "Notifications",
        systemImage: "bell.badge",
        status: self.permissionManager.notificationsStatus,
        action: {
          if self.permissionManager.notificationsStatus == .denied {
            self.permissionManager.openNotificationsSettings()
          } else {
            self.performPermissionRequest {
              _ = await self.permissionManager.requestNotificationsAccess()
            }
          }
        },
        opensSettings: self.permissionManager.notificationsStatus == .denied)

      PermissionRow(
        name: "Local Network",
        systemImage: "network",
        status: self.permissionManager.localNetworkStatus,
        action: {
          if self.permissionManager.localNetworkStatus == .denied
            || self.permissionManager.localNetworkStatus == .restricted
            || self.permissionManager.localNetworkStatus == .notAvailable
          {
            self.permissionManager.openLocalNetworkSettings()
          } else {
            self.permissionManager.requestLocalNetworkAccess()
          }
        },
        opensSettings: self.permissionManager.localNetworkStatus == .denied
          || self.permissionManager.localNetworkStatus == .restricted
          || self.permissionManager.localNetworkStatus == .notAvailable)

      PermissionRow(
        name: "Camera",
        systemImage: "camera",
        status: self.permissionManager.cameraStatus,
        action: {
          self.performPermissionRequest {
            _ = await self.permissionManager.requestCameraAccess()
          }
        })

      PermissionRow(
        name: "Microphone",
        systemImage: "mic",
        status: self.permissionManager.microphoneStatus,
        action: {
          if self.permissionManager.microphoneStatus == .denied {
            self.permissionManager.openMicrophoneSettings()
          } else {
            self.performPermissionRequest {
              _ = await self.permissionManager.requestMicrophoneAccess()
            }
          }
        },
        opensSettings: self.permissionManager.microphoneStatus == .denied)

      PermissionRow(
        name: "Bluetooth",
        systemImage: "dot.radiowaves.left.and.right",
        status: self.permissionManager.bluetoothStatus,
        action: {
          if self.permissionManager.bluetoothStatus == .denied
            || self.permissionManager.bluetoothStatus == .restricted
          {
            self.permissionManager.openBluetoothSettings()
          } else {
            self.permissionManager.requestBluetoothAccess()
          }
        },
        opensSettings: self.permissionManager.bluetoothStatus == .denied
          || self.permissionManager.bluetoothStatus == .restricted)
    } header: {
      Text("Privacy")
    }
  }

  private var securityPermissionsSection: some View {
    Section {
      PermissionRow(
        name: "Screen Recording",
        systemImage: "record.circle",
        status: self.permissionManager.screenCaptureStatus,
        action: { self.permissionManager.requestScreenCaptureAccess() },
        opensSettings: self.permissionManager.screenCaptureStatus != .authorized)

      PermissionRow(
        name: "Accessibility",
        systemImage: "figure.walk",
        status: self.permissionManager.accessibilityStatus,
        action: { self.permissionManager.requestAccessibilityAccess() },
        opensSettings: self.permissionManager.accessibilityStatus != .authorized)

      PermissionRow(
        name: "Full Disk Access",
        systemImage: "externaldrive",
        status: self.permissionManager.fullDiskAccessStatus,
        action: { self.permissionManager.openFullDiskAccessSettings() },
        opensSettings: true)

      PermissionRow(
        name: "Automation",
        systemImage: "gearshape",
        status: self.permissionManager.automationStatus,
        action: { self.permissionManager.openAutomationSettings() },
        opensSettings: true)
    } header: {
      Text("Security")
    } footer: {
      Text("These permissions require manual approval in System Settings.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var refreshSection: some View {
    Section {
      Button("Refresh All") {
        self.permissionManager.refreshAllStatuses()
      }
    }
  }

  @MainActor
  private func bringToFront() async {
    try? await Task.sleep(for: self.bringToFrontDelay)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func performPermissionRequest(_ action: @escaping @Sendable () async -> Void) {
    Task { @MainActor in
      await action()
      await self.bringToFront()
    }
  }
}

// MARK: - Permission Row

struct PermissionRow: View {
  let name: String
  let systemImage: String
  let status: PermissionStatus
  let action: () -> Void
  var opensSettings: Bool = false

  var body: some View {
    LabeledContent {
      HStack(spacing: 12) {
        self.statusBadge

        if self.status != .authorized {
          Button(self.opensSettings ? "Open Settings" : "Request") {
            self.action()
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
      }
    } label: {
      Label(self.name, systemImage: self.systemImage)
    }
  }

  private var statusBadge: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(self.statusColor)
        .frame(width: 8, height: 8)

      Text(self.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var statusColor: Color {
    switch self.status {
    case .authorized: .green
    case .denied, .restricted: .red
    case .notDetermined, .notAvailable: .gray
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

      Text(
        "GardenBridge connects your macOS system to the Clawdbot Gateway, "
          + "allowing AI assistants to interact with your calendar, contacts, reminders, files, and more.")
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
