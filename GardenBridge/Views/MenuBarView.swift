import SwiftUI

/// The main menu bar dropdown view
struct MenuBarView: View {
  @Environment(ConnectionState.self) private var connectionState
  @Environment(PermissionManager.self) private var permissionManager

  private let menuWidth: CGFloat = 280

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      self.connectionStatusSection
      Divider()
      self.quickActionsSection
      Divider()
      self.footerSection
    }
    .padding()
    .frame(width: self.menuWidth)
  }

  // MARK: - Connection Status Section

  private var connectionStatusSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        self.statusIndicator

        VStack(alignment: .leading, spacing: 2) {
          Text("Clawdbot Gateway")
            .font(.headline)
          Text(self.connectionState.status.displayText)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }

      if let error = connectionState.lastError {
        Text(error)
          .font(.caption2)
          .foregroundStyle(.red)
          .lineLimit(2)
      }
    }
  }

  private var statusIndicator: some View {
    Circle()
      .fill(self.statusColor)
      .frame(width: 12, height: 12)
      .overlay {
        if self.connectionState.status == .connecting {
          Circle()
            .stroke(self.statusColor.opacity(0.5), lineWidth: 2)
            .frame(width: 18, height: 18)
        }
      }
  }

  private var statusColor: Color {
    switch self.connectionState.status {
    case .disconnected:
      .gray
    case .connecting:
      .yellow
    case .connected:
      .orange
    case .paired:
      .green
    case .error:
      .red
    }
  }

  // MARK: - Quick Actions Section

  private var quickActionsSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      if self.connectionState.status.isConnected {
        Button(action: self.disconnect) {
          Label("Disconnect", systemImage: "bolt.slash")
        }
        .buttonStyle(.plain)
      } else {
        Button(action: self.connect) {
          Label("Connect", systemImage: "bolt")
        }
        .buttonStyle(.plain)
      }

      SettingsLink {
        Label("Settings...", systemImage: "gear")
      }
      .buttonStyle(.plain)

      Button(action: self.refreshPermissions) {
        Label("Refresh Permissions", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Footer Section

  private var footerSection: some View {
    HStack {
      Text("GardenBridge v1.0")
        .font(.caption2)
        .foregroundStyle(.tertiary)

      Spacer()

      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
      .buttonStyle(.plain)
      .font(.caption)
      .foregroundStyle(.secondary)
      .keyboardShortcut("q", modifiers: .command)
    }
  }

  // MARK: - Actions

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

  private func refreshPermissions() {
    self.permissionManager.refreshAllStatuses()
  }
}

#Preview {
  MenuBarView()
    .environment(ConnectionState())
    .environment(PermissionManager())
}
