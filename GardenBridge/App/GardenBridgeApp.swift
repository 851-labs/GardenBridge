import SwiftUI

@main
struct GardenBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appDelegate.connectionState)
                .environment(appDelegate.permissionManager)
        }
        
        MenuBarExtra {
            MenuBarView()
                .environment(appDelegate.connectionState)
                .environment(appDelegate.permissionManager)
        } label: {
            Label("GardenBridge", systemImage: "leaf.circle.fill")
        }
        .menuBarExtraStyle(.window)
        
        Window("Onboarding", id: "onboarding") {
            OnboardingView()
                .environment(appDelegate.connectionState)
                .environment(appDelegate.permissionManager)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
