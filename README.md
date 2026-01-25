# GardenBridge

A macOS menu bar application that acts as a Clawdbot Gateway Node, enabling AI assistants to interact with macOS system capabilities through a WebSocket-based protocol.

## Overview

GardenBridge connects your Mac to the Clawdbot Gateway, allowing remote AI systems to execute commands and access local system resources with appropriate permissions. It functions as an intelligent automation node that brings AI capabilities to macOS.

## Features

### Calendar & Events
- List, create, update, and delete calendar events
- Query available calendars
- Support for location, notes, and URL fields

### Contacts
- Search contacts by name
- Retrieve detailed contact information (emails, phones, addresses, social profiles)
- Birthday tracking with upcoming notification support

### Reminders
- Full CRUD operations for reminders
- Priority and due date management
- Calendar-aware organization

### File System
- Read/write files (text and binary)
- Directory listing with recursive and hidden file support
- File metadata retrieval

### Screen & Camera
- Screenshot capture via ScreenCaptureKit
- Multiple formats (PNG, JPEG, TIFF) with quality control
- Camera frame capture

### System Automation
- **Accessibility**: Click, type, and inspect UI elements
- **AppleScript**: Execute scripts with dynamic parameters
- **Shell**: Run terminal commands with output capture
- **Notifications**: Send macOS notifications

### Location & Device Info
- Location services integration
- Bluetooth and local network detection

## Requirements

- macOS 14.0+
- Xcode 15.0+ (for development)

## Installation

1. Clone the repository
2. Open `GardenBridge.xcodeproj` in Xcode
3. Build and run the application
4. Grant necessary permissions when prompted

## Configuration

### Gateway Connection

By default, GardenBridge connects to `ws://127.0.0.1:18789`. You can configure the gateway host and port in Settings > Connection.

Options:
- **Auto-connect on launch**: Automatically connect when the app starts
- **Custom host/port**: Configure for remote gateway connections

## Permissions

GardenBridge requires various macOS permissions depending on which features you use:

| Permission | Purpose |
|------------|---------|
| Calendar | Access and manage calendar events |
| Contacts | Search and read contact information |
| Reminders | Manage reminders |
| Location | Location-based features |
| Photos | Photo library access |
| Camera | Capture camera frames |
| Microphone | Audio capabilities |
| Screen Recording | Screenshot capture |
| Accessibility | UI automation and inspection |
| Full Disk Access | Extended file system access |
| Notifications | Send system notifications |
| Bluetooth | Device detection |
| Local Network | Network service discovery |

Permissions can be managed in Settings > Permissions, which provides direct links to System Settings.

## Architecture

```
GardenBridge/
├── App/                    # App lifecycle and state management
├── Views/                  # SwiftUI views (MenuBar, Settings, Onboarding)
├── Gateway/                # WebSocket client and protocol
├── Commands/               # Command handlers for each capability
├── Permissions/            # Permission management
└── Resources/              # App configuration and entitlements
```

### Key Components

- **GatewayClient**: Actor-based WebSocket client with challenge-response authentication
- **CommandHandler**: Central router dispatching commands to specialized handlers
- **PermissionManager**: Tracks and manages all macOS permissions

### Protocol

- WebSocket-based communication
- JSON message format with request/response semantics
- Device identity with HMAC signing
- 15-second heartbeat keep-alive

## Development

### Code Style

The project uses:
- **SwiftFormat** for code formatting
- **SwiftLint** for linting
- **Lefthook** for git hooks

### Building

```bash
# Open in Xcode
open GardenBridge.xcodeproj

# Or build from command line
xcodebuild -project GardenBridge.xcodeproj -scheme GardenBridge build
```

## License

Proprietary - 851 Labs
