import SwiftUI

/// The main menu bar dropdown view
struct MenuBarView: View {
  @Environment(PermissionManager.self) private var permissionManager
  @Environment(\.openSettings) private var openSettings

  private let menuWidth: CGFloat = 280

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      self.statusSection
      Divider()
      self.quickActionsSection
      Divider()
      self.footerSection
    }
    .padding()
    .frame(width: self.menuWidth)
  }

  // MARK: - Status Section

  private var statusSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Circle()
          .fill(.green)
          .frame(width: 12, height: 12)

        VStack(alignment: .leading, spacing: 2) {
          Text("GardenBridge")
            .font(.headline)
          Text("HTTP Server Running")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }
    }
  }

  // MARK: - Quick Actions Section

  private var quickActionsSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      Button {
        self.openSettings()
      } label: {
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

  private func refreshPermissions() {
    self.permissionManager.refreshAllStatuses()
  }
}

#Preview {
  MenuBarView()
    .environment(PermissionManager())
}
