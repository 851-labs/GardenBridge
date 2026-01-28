# Changelog

## 1.0.10 - 2026-01-28

### Fixed
- Removed Sparkle installer launcher key for non-sandboxed build

## 1.0.9 - 2026-01-26

### Fixed
- Calendar/Reminders permission prompts now include required full access usage strings
- Simplified Local Network permission request flow to improve status handling

## 1.0.8 - 2026-01-26

### Fixed
- Media & Apple Music permission now properly triggers system prompt (uses iTunesLibrary framework instead of just opening Settings)

## 1.0.7 - 2026-01-26

### Fixed
- Photos permission prompt now appears correctly (fixed entitlement key for PHPhotoLibrary access)

## 1.0.6 - 2026-01-26

### Fixed
- Photos permission prompt not appearing due to app not being registered in System Settings

## 1.0.5 - 2026-01-26

### Fixed
- Reverted EventKit store reset that caused Calendar/Reminders status to incorrectly show "Not Determined" after granting access and clicking "Refresh All"

## 1.0.4 - 2026-01-26

### Fixed
- Calendar and Reminders permission status not updating after granting access in System Settings

## 1.0.3 - 2026-01-26

### Fixed
- MCP Apps UI resource not rendering in Claude.ai (added legacy `ui/resourceUri` key)

## 1.0.2 - 2026-01-26

### Added
- MCP Apps support for screen_capture tool

## 1.0.1 - 2026-01-26

### Fixed
- "Install in Claude Desktop" button now properly triggers the extension install dialog
- Bundled DXT file in app for offline installation

## 1.0.0 - 2026-01-25

### Added
- Initial release
- 32 MCP tools for macOS control (calendar, contacts, reminders, files, screen capture, shell, and more)
- HTTP server for MCP integration
- Claude Desktop extension support via DXT manifest
- Menu bar app with full macOS permissions management
- Sparkle auto-updates
