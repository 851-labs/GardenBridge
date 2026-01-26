import AppKit
import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

/// Storage for temporary screenshot files
actor ScreenshotStorage {
  static let shared = ScreenshotStorage()

  private var screenshots: [String: URL] = [:]
  private let tempDirectory: URL

  private init() {
    self.tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("gardenbridge-screenshots")
    try? FileManager.default.createDirectory(at: self.tempDirectory, withIntermediateDirectories: true)
  }

  func store(data: Data, format: String) -> String {
    let id = UUID().uuidString
    let ext = format == "jpeg" || format == "jpg" ? "jpg" : format
    let fileURL = self.tempDirectory.appendingPathComponent("\(id).\(ext)")

    do {
      try data.write(to: fileURL)
      self.screenshots[id] = fileURL
      // Schedule cleanup after 5 minutes
      Task {
        try? await Task.sleep(for: .seconds(300))
        await self.remove(id: id)
      }
      return id
    } catch {
      return ""
    }
  }

  func get(id: String) -> URL? {
    return self.screenshots[id]
  }

  func remove(id: String) {
    if let url = self.screenshots.removeValue(forKey: id) {
      try? FileManager.default.removeItem(at: url)
    }
  }
}

/// Handles screen capture commands using ScreenCaptureKit
actor ScreenCaptureCommands: CommandExecutor {
  private let retinaScale: Int = 2
  private let serverPort: UInt16 = 28790

  func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
    switch command {
    case "screen.capture":
      return try await self.captureScreen(params: params)
    case "screen.list":
      return try await self.listDisplays()
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
    let formatLowercased = format.lowercased()
    let quality = params["quality"]?.doubleValue ?? 0.9

    // Get available displays using ScreenCaptureKit
    let content = try await shareableContent()

    guard let display = content.displays.first(where: { $0.displayID == CGDirectDisplayID(displayId) }) ?? content
      .displays.first
    else {
      throw CommandError(code: "DISPLAY_NOT_FOUND", message: "Display not found")
    }

    // Create filter for the display
    let filter = SCContentFilter(display: display, excludingWindows: [])

    // Create stream configuration
    let config = SCStreamConfiguration()
    config.width = display.width * self.retinaScale
    config.height = display.height * self.retinaScale

    // Capture screenshot using ScreenCaptureKit
    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

    let (data, mimeType) = try encodeImage(image, format: formatLowercased, quality: quality)

    // Store screenshot in temp storage and return URL
    let imageId = await ScreenshotStorage.shared.store(data: data, format: formatLowercased)
    guard !imageId.isEmpty else {
      throw CommandError(code: "STORAGE_FAILED", message: "Failed to store screenshot")
    }

    let imageUrl = "http://localhost:\(self.serverPort)/screenshot/\(imageId)"

    return AnyCodable([
      "imageId": imageId,
      "imageUrl": imageUrl,
      "format": format,
      "mimeType": mimeType,
      "width": image.width,
      "height": image.height,
    ])
  }

  // MARK: - List Displays

  private func listDisplays() async throws -> AnyCodable {
    let content = try await shareableContent()

    let displays = content.displays.map { display -> [String: Any] in
      [
        "id": Int(display.displayID),
        "width": display.width,
        "height": display.height,
        "frame": [
          "x": display.frame.origin.x,
          "y": display.frame.origin.y,
          "width": display.frame.size.width,
          "height": display.frame.size.height,
        ],
      ]
    }

    return AnyCodable([
      "displays": displays,
      "count": displays.count,
      "mainDisplay": Int(CGMainDisplayID()),
    ])
  }

  private func shareableContent() async throws -> SCShareableContent {
    try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
  }

  private func encodeImage(_ image: CGImage, format: String, quality: Double) throws -> (Data, String) {
    let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

    guard let tiffData = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData)
    else {
      throw CommandError(code: "CONVERSION_FAILED", message: "Failed to convert image")
    }

    let imageData: Data?
    let mimeType: String

    switch format {
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

    return (data, mimeType)
  }
}
