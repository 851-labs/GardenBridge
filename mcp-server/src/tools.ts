/**
 * Tool definitions for GardenBridge MCP server
 */

import { Tool } from "@modelcontextprotocol/sdk/types.js";

export const tools: Tool[] = [
  // Calendar tools
  {
    name: "calendar_list",
    description: "List calendar events within a date range",
    inputSchema: {
      type: "object",
      properties: {
        startDate: { type: "string", description: "Start date (ISO 8601)" },
        endDate: { type: "string", description: "End date (ISO 8601)" },
        calendarId: { type: "string", description: "Optional calendar ID to filter" },
      },
      required: ["startDate", "endDate"],
    },
  },
  {
    name: "calendar_create",
    description: "Create a new calendar event",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Event title" },
        startDate: { type: "string", description: "Start date (ISO 8601)" },
        endDate: { type: "string", description: "End date (ISO 8601)" },
        location: { type: "string", description: "Event location" },
        notes: { type: "string", description: "Event notes" },
        calendarId: { type: "string", description: "Calendar ID" },
      },
      required: ["title", "startDate", "endDate"],
    },
  },
  {
    name: "calendar_update",
    description: "Update an existing calendar event",
    inputSchema: {
      type: "object",
      properties: {
        eventId: { type: "string", description: "Event ID to update" },
        title: { type: "string", description: "New title" },
        startDate: { type: "string", description: "New start date (ISO 8601)" },
        endDate: { type: "string", description: "New end date (ISO 8601)" },
        location: { type: "string", description: "New location" },
        notes: { type: "string", description: "New notes" },
      },
      required: ["eventId"],
    },
  },
  {
    name: "calendar_delete",
    description: "Delete a calendar event",
    inputSchema: {
      type: "object",
      properties: {
        eventId: { type: "string", description: "Event ID to delete" },
      },
      required: ["eventId"],
    },
  },
  {
    name: "calendar_get_calendars",
    description: "Get list of available calendars",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },

  // Contacts tools
  {
    name: "contacts_search",
    description: "Search contacts by name",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Search query" },
        limit: { type: "number", description: "Max results (default 20)" },
      },
      required: ["query"],
    },
  },
  {
    name: "contacts_get",
    description: "Get detailed contact information",
    inputSchema: {
      type: "object",
      properties: {
        contactId: { type: "string", description: "Contact ID" },
      },
      required: ["contactId"],
    },
  },
  {
    name: "contacts_birthdays",
    description: "Get contacts with upcoming birthdays",
    inputSchema: {
      type: "object",
      properties: {
        days: { type: "number", description: "Days ahead to look (default 30)" },
      },
    },
  },

  // Reminders tools
  {
    name: "reminders_list",
    description: "List reminders",
    inputSchema: {
      type: "object",
      properties: {
        listId: { type: "string", description: "Reminder list ID" },
        includeCompleted: { type: "boolean", description: "Include completed reminders" },
      },
    },
  },
  {
    name: "reminders_create",
    description: "Create a new reminder",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Reminder title" },
        notes: { type: "string", description: "Reminder notes" },
        dueDate: { type: "string", description: "Due date (ISO 8601)" },
        priority: { type: "number", description: "Priority (0=none, 1=high, 5=medium, 9=low)" },
        listId: { type: "string", description: "Reminder list ID" },
      },
      required: ["title"],
    },
  },
  {
    name: "reminders_complete",
    description: "Mark a reminder as complete",
    inputSchema: {
      type: "object",
      properties: {
        reminderId: { type: "string", description: "Reminder ID" },
      },
      required: ["reminderId"],
    },
  },
  {
    name: "reminders_delete",
    description: "Delete a reminder",
    inputSchema: {
      type: "object",
      properties: {
        reminderId: { type: "string", description: "Reminder ID" },
      },
      required: ["reminderId"],
    },
  },
  {
    name: "reminders_get_lists",
    description: "Get available reminder lists",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },

  // Location tools
  {
    name: "location_get",
    description: "Get current device location",
    inputSchema: {
      type: "object",
      properties: {
        timeout: { type: "number", description: "Timeout in seconds (default 10)" },
      },
    },
  },

  // Music tools
  {
    name: "music_play",
    description: "Start music playback (optionally by track name)",
    inputSchema: {
      type: "object",
      properties: {
        track: { type: "string", description: "Track name or search query" },
      },
    },
  },
  {
    name: "music_pause",
    description: "Pause music playback",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "music_stop",
    description: "Stop music playback",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "music_next",
    description: "Skip to next track",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "music_previous",
    description: "Go to previous track",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "music_toggle_play_pause",
    description: "Toggle play/pause",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "music_set_volume",
    description: "Set music volume (0-100)",
    inputSchema: {
      type: "object",
      properties: {
        volume: { type: "number", description: "Volume from 0 to 100" },
      },
      required: ["volume"],
    },
  },
  {
    name: "music_now_playing",
    description: "Get current track info",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "music_search",
    description: "Search music library",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Search query" },
        limit: { type: "number", description: "Max results (default 10)" },
      },
      required: ["query"],
    },
  },
  {
    name: "music_get_playlists",
    description: "Get user playlists",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "music_play_playlist",
    description: "Play playlist by name",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Playlist name" },
      },
      required: ["name"],
    },
  },

  // Photos tools
  {
    name: "photos_list",
    description: "List photos with optional filters",
    inputSchema: {
      type: "object",
      properties: {
        startDate: { type: "string", description: "Start date (ISO 8601)" },
        endDate: { type: "string", description: "End date (ISO 8601)" },
        album: { type: "string", description: "Album name" },
        limit: { type: "number", description: "Max results (default 50)" },
      },
    },
  },
  {
    name: "photos_get",
    description: "Get a photo by id",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string", description: "Photo identifier" },
        size: { type: "number", description: "Max dimension in pixels" },
        format: { type: "string", description: "Format: jpeg, png, tiff" },
      },
      required: ["id"],
    },
  },
  {
    name: "photos_search",
    description: "Search photos by date or location",
    inputSchema: {
      type: "object",
      properties: {
        startDate: { type: "string", description: "Start date (ISO 8601)" },
        endDate: { type: "string", description: "End date (ISO 8601)" },
        latitude: { type: "number", description: "Latitude" },
        longitude: { type: "number", description: "Longitude" },
        radius: { type: "number", description: "Radius in meters (default 1000)" },
        limit: { type: "number", description: "Max results (default 50)" },
      },
    },
  },
  {
    name: "photos_get_albums",
    description: "List photo albums",
    inputSchema: {
      type: "object",
      properties: {
        type: { type: "string", description: "Album type: user, smart, all" },
      },
    },
  },

  // Audio tools
  {
    name: "audio_record",
    description: "Record audio (max 5 minutes)",
    inputSchema: {
      type: "object",
      properties: {
        duration: { type: "number", description: "Duration in seconds" },
        device: { type: "string", description: "Audio input device id" },
        format: { type: "string", description: "Format: m4a or wav" },
      },
      required: ["duration"],
    },
  },
  {
    name: "audio_get_devices",
    description: "List available audio input devices",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },

  // Bluetooth tools
  {
    name: "bluetooth_scan",
    description: "Scan for BLE devices",
    inputSchema: {
      type: "object",
      properties: {
        duration: { type: "number", description: "Scan duration in seconds (default 5)" },
        serviceUUIDs: { type: "array", items: { type: "string" }, description: "Service UUID filters" },
      },
    },
  },
  {
    name: "bluetooth_devices",
    description: "Get devices from the last scan",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "bluetooth_status",
    description: "Get Bluetooth adapter status",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },

  // File system tools
  {
    name: "file_read",
    description: "Read contents of a file",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "File path (supports ~ for home)" },
        encoding: { type: "string", description: "Encoding (utf8 or base64)" },
      },
      required: ["path"],
    },
  },
  {
    name: "file_write",
    description: "Write contents to a file",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "File path (supports ~ for home)" },
        content: { type: "string", description: "Content to write" },
        encoding: { type: "string", description: "Encoding (utf8 or base64)" },
      },
      required: ["path", "content"],
    },
  },
  {
    name: "file_list",
    description: "List files in a directory",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Directory path (supports ~ for home)" },
        recursive: { type: "boolean", description: "List recursively" },
        showHidden: { type: "boolean", description: "Show hidden files" },
      },
      required: ["path"],
    },
  },
  {
    name: "file_exists",
    description: "Check if a file or directory exists",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Path to check (supports ~ for home)" },
      },
      required: ["path"],
    },
  },
  {
    name: "file_delete",
    description: "Delete a file",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "File path to delete" },
      },
      required: ["path"],
    },
  },
  {
    name: "file_info",
    description: "Get file metadata (size, dates, permissions)",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "File path (supports ~ for home)" },
      },
      required: ["path"],
    },
  },

  // Accessibility tools
  {
    name: "accessibility_click",
    description: "Click at screen coordinates",
    inputSchema: {
      type: "object",
      properties: {
        x: { type: "number", description: "X coordinate" },
        y: { type: "number", description: "Y coordinate" },
        button: { type: "string", description: "Mouse button (left, right, middle)" },
        clickType: { type: "string", description: "Click type (single, double, drag)" },
      },
      required: ["x", "y"],
    },
  },
  {
    name: "accessibility_type",
    description: "Type text using keyboard",
    inputSchema: {
      type: "object",
      properties: {
        text: { type: "string", description: "Text to type" },
      },
      required: ["text"],
    },
  },
  {
    name: "accessibility_get_element",
    description: "Get UI element at screen coordinates",
    inputSchema: {
      type: "object",
      properties: {
        x: { type: "number", description: "X coordinate" },
        y: { type: "number", description: "Y coordinate" },
      },
      required: ["x", "y"],
    },
  },
  {
    name: "accessibility_get_windows",
    description: "Get list of open windows",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },

  // Screen capture tools
  {
    name: "screen_capture",
    description: "Capture a screenshot",
    inputSchema: {
      type: "object",
      properties: {
        displayId: { type: "number", description: "Display ID (use screen_list to get IDs)" },
        format: { type: "string", description: "Image format (png, jpeg, tiff)" },
        quality: { type: "number", description: "JPEG quality (0-100)" },
      },
    },
  },
  {
    name: "screen_list",
    description: "List available displays",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },

  // Camera tools
  {
    name: "camera_snap",
    description: "Capture a photo from camera",
    inputSchema: {
      type: "object",
      properties: {
        deviceId: { type: "string", description: "Camera device ID (use camera_list to get IDs)" },
      },
    },
  },
  {
    name: "camera_list",
    description: "List available cameras",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },

  // Notification tools
  {
    name: "notification_send",
    description: "Send a macOS notification",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Notification title" },
        body: { type: "string", description: "Notification body" },
        sound: { type: "boolean", description: "Play sound" },
      },
      required: ["title", "body"],
    },
  },

  // Shell tools
  {
    name: "shell_execute",
    description: "Execute a shell command",
    inputSchema: {
      type: "object",
      properties: {
        command: { type: "string", description: "Command to execute" },
        args: { type: "array", items: { type: "string" }, description: "Command arguments" },
        cwd: { type: "string", description: "Working directory" },
        timeout: { type: "number", description: "Timeout in seconds (default 30)" },
        env: { type: "object", description: "Environment variables" },
      },
      required: ["command"],
    },
  },
  {
    name: "shell_which",
    description: "Find the path of an executable",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Executable name" },
      },
      required: ["name"],
    },
  },

  // AppleScript tools
  {
    name: "applescript_execute",
    description: "Execute AppleScript code",
    inputSchema: {
      type: "object",
      properties: {
        script: { type: "string", description: "AppleScript code to execute" },
      },
      required: ["script"],
    },
  },
];

// Map tool names to GardenBridge command names
export const toolToCommand: Record<string, string> = {
  calendar_list: "calendar.list",
  calendar_create: "calendar.create",
  calendar_update: "calendar.update",
  calendar_delete: "calendar.delete",
  calendar_get_calendars: "calendar.getCalendars",
  contacts_search: "contacts.search",
  contacts_get: "contacts.get",
  contacts_birthdays: "contacts.birthdays",
  reminders_list: "reminders.list",
  reminders_create: "reminders.create",
  reminders_complete: "reminders.complete",
  reminders_delete: "reminders.delete",
  reminders_get_lists: "reminders.getLists",
  location_get: "location.get",
  music_play: "music.play",
  music_pause: "music.pause",
  music_stop: "music.stop",
  music_next: "music.next",
  music_previous: "music.previous",
  music_toggle_play_pause: "music.togglePlayPause",
  music_set_volume: "music.setVolume",
  music_now_playing: "music.nowPlaying",
  music_search: "music.search",
  music_get_playlists: "music.getPlaylists",
  music_play_playlist: "music.playPlaylist",
  photos_list: "photos.list",
  photos_get: "photos.get",
  photos_search: "photos.search",
  photos_get_albums: "photos.getAlbums",
  audio_record: "audio.record",
  audio_get_devices: "audio.getDevices",
  bluetooth_scan: "bluetooth.scan",
  bluetooth_devices: "bluetooth.devices",
  bluetooth_status: "bluetooth.status",
  file_read: "file.read",
  file_write: "file.write",
  file_list: "file.list",
  file_exists: "file.exists",
  file_delete: "file.delete",
  file_info: "file.info",
  accessibility_click: "accessibility.click",
  accessibility_type: "accessibility.type",
  accessibility_get_element: "accessibility.getElement",
  accessibility_get_windows: "accessibility.getWindows",
  screen_capture: "screen.capture",
  screen_list: "screen.list",
  camera_snap: "camera.snap",
  camera_list: "camera.list",
  notification_send: "notification.send",
  shell_execute: "shell.execute",
  shell_which: "shell.which",
  applescript_execute: "applescript.execute",
};
