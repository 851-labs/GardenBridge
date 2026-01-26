import Sparkle
import SwiftUI

@main
struct GardenBridgeApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  private let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil)

  var body: some Scene {
    Settings {
      SettingsView(updaterController: self.updaterController)
        .environment(self.appDelegate.permissionManager)
    }
    .commands {
      CommandGroup(after: .appInfo) {
        Button {
          self.updaterController.checkForUpdates(nil)
        } label: {
          Label("Check for Updates…", systemImage: "square.and.arrow.down")
        }
      }
    }

    MenuBarExtra {
      MenuBarView()
        .environment(self.appDelegate.permissionManager)
    } label: {
      Label("GardenBridge", systemImage: "leaf.circle.fill")
    }
    .menuBarExtraStyle(.window)

    Window("Welcome to GardenBridge", id: "onboarding") {
      OnboardingView()
        .environment(self.appDelegate.permissionManager)
    }
    .windowResizability(.contentSize)
    .defaultPosition(.center)
  }
}
