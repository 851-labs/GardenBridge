import AppKit
import ApplicationServices
import Foundation

/// Handles accessibility-related commands using Accessibility APIs
actor AccessibilityCommands: CommandExecutor {
  func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
    // Check accessibility permission first
    guard AXIsProcessTrusted() else {
      let message = "Accessibility permission not granted. "
        + "Please enable it in System Preferences > Security & Privacy > Privacy > Accessibility"
      throw CommandError(code: "ACCESSIBILITY_NOT_TRUSTED", message: message)
    }

    switch command {
    case "accessibility.click":
      return try await self.clickElement(params: params)
    case "accessibility.type":
      return try await self.typeText(params: params)
    case "accessibility.getElement":
      return try await self.getElement(params: params)
    case "accessibility.getWindows":
      return try await self.getWindows(params: params)
    default:
      throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown accessibility command: \(command)")
    }
  }

  // MARK: - Click Element

  private func clickElement(params: [String: AnyCodable]) async throws -> AnyCodable {
    // Either click at coordinates or click a specific element
    if let x = params["x"]?.doubleValue,
       let y = params["y"]?.doubleValue
    {
      return try await self.clickAtPoint(x: x, y: y, params: params)
    }

    throw CommandError.invalidParam("x and y coordinates are required")
  }

  private func clickAtPoint(x: Double, y: Double, params: [String: AnyCodable]) async throws -> AnyCodable {
    let point = CGPoint(x: x, y: y)
    let clickType = params["clickType"]?.stringValue ?? "left"
    let clickCount = params["clickCount"]?.intValue ?? 1

    let (mouseButton, mouseDown, mouseUp) = self.mouseEventTypes(for: clickType)

    for _ in 0..<clickCount {
      let downEvent = CGEvent(
        mouseEventSource: nil,
        mouseType: mouseDown,
        mouseCursorPosition: point,
        mouseButton: mouseButton)
      let upEvent = CGEvent(
        mouseEventSource: nil,
        mouseType: mouseUp,
        mouseCursorPosition: point,
        mouseButton: mouseButton)

      downEvent?.post(tap: .cghidEventTap)
      upEvent?.post(tap: .cghidEventTap)
    }

    return AnyCodable([
      "success": true,
      "x": x,
      "y": y,
      "clickType": clickType,
      "clickCount": clickCount,
    ])
  }

  // MARK: - Type Text

  private func typeText(params: [String: AnyCodable]) async throws -> AnyCodable {
    guard let text = params["text"]?.stringValue else {
      throw CommandError.invalidParam("text")
    }

    let delay = params["delay"]?.intValue ?? 0

    for character in text {
      // Create key event for character
      let keyCode = self.keyCodeForCharacter(character)

      if let code = keyCode {
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: code.keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: code.keyCode, keyDown: false)

        if code.shift {
          keyDown?.flags = .maskShift
        }

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
      } else {
        // Use Unicode input for complex characters
        let source = CGEventSource(stateID: .hidSystemState)
        if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
          var utf16 = Array(String(character).utf16)
          event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
          event.post(tap: .cghidEventTap)

          let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
          upEvent?.post(tap: .cghidEventTap)
        }
      }

      if delay > 0 {
        try? await Task.sleep(for: .milliseconds(delay))
      }
    }

    return AnyCodable([
      "success": true,
      "text": text,
      "length": text.count,
    ])
  }

  // MARK: - Get Element

  private func getElement(params: [String: AnyCodable]) async throws -> AnyCodable {
    guard let x = params["x"]?.doubleValue,
          let y = params["y"]?.doubleValue
    else {
      throw CommandError.invalidParam("x and y coordinates are required")
    }

    let point = CGPoint(x: x, y: y)

    var elementRef: AXUIElement?
    let systemWide = AXUIElementCreateSystemWide()
    let error = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &elementRef)

    guard error == .success, let element = elementRef else {
      return AnyCodable(["element": nil as String?])
    }

    let info = self.getElementInfo(element)

    return AnyCodable(["element": info])
  }

  // MARK: - Get Windows

  private func getWindows(params: [String: AnyCodable]) async throws -> AnyCodable {
    let appName = params["app"]?.stringValue

    var windows: [[String: Any]] = []

    let runningApps: [NSRunningApplication] = if let appName {
      NSWorkspace.shared.runningApplications.filter { $0.localizedName == appName }
    } else {
      NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    }

    for app in runningApps {
      let appElement = AXUIElementCreateApplication(app.processIdentifier)

      var windowsRef: CFTypeRef?
      AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

      if let windowArray = windowsRef as? [AXUIElement] {
        for window in windowArray {
          var windowInfo: [String: Any] = [
            "app": app.localizedName ?? "",
            "pid": app.processIdentifier,
          ]

          // Get window title
          var titleRef: CFTypeRef?
          AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
          if let title = titleRef as? String {
            windowInfo["title"] = title
          }

          // Get window position
          var positionRef: CFTypeRef?
          AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
          if let positionRef, CFGetTypeID(positionRef) == AXValueGetTypeID() {
            let positionValue = unsafeBitCast(positionRef, to: AXValue.self)
            var point = CGPoint.zero
            AXValueGetValue(positionValue, .cgPoint, &point)
            windowInfo["x"] = point.x
            windowInfo["y"] = point.y
          }

          // Get window size
          var sizeRef: CFTypeRef?
          AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
          if let sizeRef, CFGetTypeID(sizeRef) == AXValueGetTypeID() {
            let sizeValue = unsafeBitCast(sizeRef, to: AXValue.self)
            var size = CGSize.zero
            AXValueGetValue(sizeValue, .cgSize, &size)
            windowInfo["width"] = size.width
            windowInfo["height"] = size.height
          }

          windows.append(windowInfo)
        }
      }
    }

    return AnyCodable(["windows": windows, "count": windows.count])
  }

  // MARK: - Helpers

  private func getElementInfo(_ element: AXUIElement) -> [String: Any] {
    var info: [String: Any] = [:]

    // Get role
    var roleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
    if let role = roleRef as? String {
      info["role"] = role
    }

    // Get title
    var titleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
    if let title = titleRef as? String {
      info["title"] = title
    }

    // Get value
    var valueRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
    if let value = valueRef as? String {
      info["value"] = value
    }

    // Get description
    var descRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
    if let desc = descRef as? String {
      info["description"] = desc
    }

    return info
  }

  private func mouseEventTypes(for clickType: String) -> (CGMouseButton, CGEventType, CGEventType) {
    switch clickType {
    case "right":
      (.right, .rightMouseDown, .rightMouseUp)
    case "middle":
      (.center, .otherMouseDown, .otherMouseUp)
    default:
      (.left, .leftMouseDown, .leftMouseUp)
    }
  }

  private struct KeyCodeInfo {
    let keyCode: CGKeyCode
    let shift: Bool
  }

  private func keyCodeForCharacter(_ char: Character) -> KeyCodeInfo? {
    // Basic key code mapping for common characters
    let keyMap: [Character: (CGKeyCode, Bool)] = [
      "a": (0, false), "A": (0, true),
      "b": (11, false), "B": (11, true),
      "c": (8, false), "C": (8, true),
      "d": (2, false), "D": (2, true),
      "e": (14, false), "E": (14, true),
      "f": (3, false), "F": (3, true),
      "g": (5, false), "G": (5, true),
      "h": (4, false), "H": (4, true),
      "i": (34, false), "I": (34, true),
      "j": (38, false), "J": (38, true),
      "k": (40, false), "K": (40, true),
      "l": (37, false), "L": (37, true),
      "m": (46, false), "M": (46, true),
      "n": (45, false), "N": (45, true),
      "o": (31, false), "O": (31, true),
      "p": (35, false), "P": (35, true),
      "q": (12, false), "Q": (12, true),
      "r": (15, false), "R": (15, true),
      "s": (1, false), "S": (1, true),
      "t": (17, false), "T": (17, true),
      "u": (32, false), "U": (32, true),
      "v": (9, false), "V": (9, true),
      "w": (13, false), "W": (13, true),
      "x": (7, false), "X": (7, true),
      "y": (16, false), "Y": (16, true),
      "z": (6, false), "Z": (6, true),
      "0": (29, false), ")": (29, true),
      "1": (18, false), "!": (18, true),
      "2": (19, false), "@": (19, true),
      "3": (20, false), "#": (20, true),
      "4": (21, false), "$": (21, true),
      "5": (23, false), "%": (23, true),
      "6": (22, false), "^": (22, true),
      "7": (26, false), "&": (26, true),
      "8": (28, false), "*": (28, true),
      "9": (25, false), "(": (25, true),
      " ": (49, false),
      "\n": (36, false),
      "\t": (48, false),
      "-": (27, false), "_": (27, true),
      "=": (24, false), "+": (24, true),
      "[": (33, false), "{": (33, true),
      "]": (30, false), "}": (30, true),
      "\\": (42, false), "|": (42, true),
      ";": (41, false), ":": (41, true),
      "'": (39, false), "\"": (39, true),
      ",": (43, false), "<": (43, true),
      ".": (47, false), ">": (47, true),
      "/": (44, false), "?": (44, true),
      "`": (50, false), "~": (50, true),
    ]

    if let (keyCode, shift) = keyMap[char] {
      return KeyCodeInfo(keyCode: keyCode, shift: shift)
    }
    return nil
  }
}
