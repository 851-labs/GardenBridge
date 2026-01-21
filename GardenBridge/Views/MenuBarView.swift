import SwiftUI

/// The main menu bar dropdown view
struct MenuBarView: View {
    @Environment(ConnectionState.self) private var connectionState
    @Environment(PermissionManager.self) private var permissionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Connection Status
            connectionStatusSection
            
            Divider()
            
            // Quick Actions
            quickActionsSection
            
            Divider()
            
            // Footer
            footerSection
        }
        .padding()
        .frame(width: 280)
    }
    
    // MARK: - Connection Status Section
    
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusIndicator
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clawdbot Gateway")
                        .font(.headline)
                    Text(connectionState.status.displayText)
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
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay {
                if connectionState.status == .connecting {
                    Circle()
                        .stroke(statusColor.opacity(0.5), lineWidth: 2)
                        .frame(width: 18, height: 18)
                }
            }
    }
    
    private var statusColor: Color {
        switch connectionState.status {
        case .disconnected:
            return .gray
        case .connecting:
            return .yellow
        case .connected:
            return .orange
        case .paired:
            return .green
        case .error:
            return .red
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if connectionState.status.isConnected {
                Button(action: disconnect) {
                    Label("Disconnect", systemImage: "bolt.slash")
                }
                .buttonStyle(.plain)
            } else {
                Button(action: connect) {
                    Label("Connect", systemImage: "bolt")
                }
                .buttonStyle(.plain)
            }
            
            SettingsLink {
                Label("Settings...", systemImage: "gear")
            }
            .buttonStyle(.plain)
            
            Button(action: refreshPermissions) {
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
        permissionManager.refreshAllStatuses()
    }
}

#Preview {
    MenuBarView()
        .environment(ConnectionState())
        .environment(PermissionManager())
}
