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
