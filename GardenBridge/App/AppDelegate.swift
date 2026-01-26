import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let permissionManager = PermissionManager()
  private lazy var commandHandler = CommandHandler(permissionManager: permissionManager)
  private lazy var httpServer = HTTPServer(commandHandler: commandHandler)

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Start HTTP server for MCP integration
    Task {
      do {
        try await self.httpServer.start()
      } catch {
        print("[AppDelegate] Failed to start HTTP server: \(error)")
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    Task {
      await self.httpServer.stop()
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Menu bar apps should not terminate when windows close
    false
  }

  // MARK: - Public Methods

  func completeOnboarding() {
    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
  }
}
