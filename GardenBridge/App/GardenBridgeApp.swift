import SwiftUI

@main
struct GardenBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(self.appDelegate.connectionState)
                .environment(self.appDelegate.permissionManager)
        }

        MenuBarExtra {
            MenuBarView()
                .environment(self.appDelegate.connectionState)
                .environment(self.appDelegate.permissionManager)
        } label: {
            Label("GardenBridge", systemImage: "leaf.circle.fill")
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to GardenBridge", id: "onboarding") {
            OnboardingView()
                .environment(self.appDelegate.connectionState)
                .environment(self.appDelegate.permissionManager)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
