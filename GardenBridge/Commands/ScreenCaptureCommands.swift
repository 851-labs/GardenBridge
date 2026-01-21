import Foundation
@preconcurrency import ScreenCaptureKit
import CoreGraphics
import AppKit

/// Handles screen capture commands using ScreenCaptureKit
actor ScreenCaptureCommands: CommandExecutor {
    
    func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
        switch command {
        case "screen.capture":
            return try await captureScreen(params: params)
        case "screen.list":
            return try await listDisplays()
        default:
            throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown screen command: \(command)")
        }
    }
    
    // MARK: - Capture Screen
    
    private func captureScreen(params: [String: AnyCodable]) async throws -> AnyCodable {
        // Check permission
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            throw CommandError(code: "SCREEN_CAPTURE_NOT_AUTHORIZED", message: "Screen capture permission not granted")
        }
        
        let displayId = params["display"]?.intValue ?? Int(CGMainDisplayID())
        let format = params["format"]?.stringValue ?? "png"
        let quality = params["quality"]?.doubleValue ?? 0.9
        
        // Get available displays using ScreenCaptureKit
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let display = content.displays.first(where: { $0.displayID == CGDirectDisplayID(displayId) }) ?? content.displays.first else {
            throw CommandError(code: "DISPLAY_NOT_FOUND", message: "Display not found")
        }
        
        // Create filter for the display
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // Create stream configuration
        let config = SCStreamConfiguration()
        config.width = display.width * 2  // Retina
        config.height = display.height * 2
        
        // Capture screenshot using ScreenCaptureKit
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        // Convert to requested format
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw CommandError(code: "CONVERSION_FAILED", message: "Failed to convert image")
        }
        
        let imageData: Data?
        let mimeType: String
        
        switch format.lowercased() {
        case "jpeg", "jpg":
            imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
            mimeType = "image/jpeg"
        case "png":
            imageData = bitmap.representation(using: .png, properties: [:])
            mimeType = "image/png"
        case "tiff":
            imageData = bitmap.representation(using: .tiff, properties: [:])
            mimeType = "image/tiff"
        default:
            imageData = bitmap.representation(using: .png, properties: [:])
            mimeType = "image/png"
        }
        
        guard let data = imageData else {
            throw CommandError(code: "ENCODING_FAILED", message: "Failed to encode image")
        }
        
        return AnyCodable([
            "format": format,
            "mimeType": mimeType,
            "width": image.width,
            "height": image.height,
            "base64": data.base64EncodedString()
        ])
    }
    
    // MARK: - List Displays
    
    private func listDisplays() async throws -> AnyCodable {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        let displays = content.displays.map { display -> [String: Any] in
            [
                "id": Int(display.displayID),
                "width": display.width,
                "height": display.height,
                "frame": [
                    "x": display.frame.origin.x,
                    "y": display.frame.origin.y,
                    "width": display.frame.size.width,
                    "height": display.frame.size.height
                ]
            ]
        }
        
        return AnyCodable([
            "displays": displays,
            "count": displays.count,
            "mainDisplay": Int(CGMainDisplayID())
        ])
    }
}
