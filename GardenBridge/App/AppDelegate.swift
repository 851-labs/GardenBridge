import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let connectionState = ConnectionState()
    let permissionManager = PermissionManager()
    var gatewayClient: GatewayClient?
    var commandHandler: CommandHandler?
    
    private var hasShownOnboarding = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the command handler with all capability handlers
        commandHandler = CommandHandler(permissionManager: permissionManager)
        
        // Initialize the gateway client
        gatewayClient = GatewayClient(
            connectionState: connectionState,
            commandHandler: commandHandler!
        )
        
        // Check if this is first launch
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        if !hasCompletedOnboarding {
            showOnboarding()
        } else if connectionState.autoConnect {
            // Auto-connect to gateway
            Task {
                await connectToGateway()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Disconnect from gateway
        Task {
            await gatewayClient?.disconnect()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar apps should not terminate when windows close
        return false
    }
    
    // MARK: - Public Methods
    
    func connectToGateway() async {
        await gatewayClient?.connect()
    }
    
    func disconnectFromGateway() async {
        await gatewayClient?.disconnect()
    }
    
    func showOnboarding() {
        guard !hasShownOnboarding else { return }
        hasShownOnboarding = true
        
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "onboarding" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Open the onboarding window using SwiftUI's openWindow
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Close onboarding window if open
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "onboarding" }) {
            window.close()
        }
        
        // Start connection
        Task {
            await connectToGateway()
        }
    }
}
