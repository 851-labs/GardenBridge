import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let connectionState = ConnectionState()
    let permissionManager = PermissionManager()
    private lazy var commandHandler = CommandHandler(permissionManager: permissionManager)
    private lazy var gatewayClient = GatewayClient(
        connectionState: connectionState,
        commandHandler: commandHandler)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if this is first launch - if so, the Window scene will handle opening
        // If already completed onboarding, auto-connect if enabled
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if hasCompletedOnboarding, self.connectionState.autoConnect {
            Task {
                await self.connectToGateway()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Disconnect from gateway
        Task {
            await self.gatewayClient.disconnect()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar apps should not terminate when windows close
        false
    }

    // MARK: - Public Methods

    func connectToGateway() async {
        await self.gatewayClient.connect()
    }

    func disconnectFromGateway() async {
        await self.gatewayClient.disconnect()
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Start connection
        Task {
            await self.connectToGateway()
        }
    }
}
