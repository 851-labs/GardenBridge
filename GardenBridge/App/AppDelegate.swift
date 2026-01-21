import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let connectionState = ConnectionState()
    let permissionManager = PermissionManager()
    private lazy var commandHandler = CommandHandler(permissionManager: permissionManager)
    private lazy var gatewayClient = GatewayClient(
        connectionState: connectionState,
        commandHandler: commandHandler
    )
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if this is first launch - if so, the Window scene will handle opening
        // If already completed onboarding, auto-connect if enabled
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        if hasCompletedOnboarding && connectionState.autoConnect {
            Task {
                await connectToGateway()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Disconnect from gateway
        Task {
            await gatewayClient.disconnect()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar apps should not terminate when windows close
        return false
    }
    
    // MARK: - Public Methods
    
    func connectToGateway() async {
        await gatewayClient.connect()
    }
    
    func disconnectFromGateway() async {
        await gatewayClient.disconnect()
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Start connection
        Task {
            await connectToGateway()
        }
    }
}
