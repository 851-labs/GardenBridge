#!/usr/bin/env node
/**
 * GardenBridge MCP Server
 *
 * Exposes GardenBridge capabilities to Claude via MCP protocol.
 * Requires GardenBridge.app to be running on localhost:28790.
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

import { invoke } from "./client.js";
import { tools, toolToCommand } from "./tools.js";

const server = new Server(
  {
    name: "gardenbridge",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  const command = toolToCommand[name];
  if (!command) {
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({ error: `Unknown tool: ${name}` }),
        },
      ],
      isError: true,
    };
  }

  try {
    const result = await invoke(command, args as Record<string, unknown>);

    if (!result.ok) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: result.error?.message || "Command failed",
              code: result.error?.code,
            }),
          },
        ],
        isError: true,
      };
    }

    // Handle image responses (screenshots, camera)
    if (
      result.payload &&
      typeof result.payload === "object" &&
      "data" in result.payload &&
      "format" in result.payload
    ) {
      const payload = result.payload as { data: string; format: string };
      const mimeType =
        payload.format === "png"
          ? "image/png"
          : payload.format === "jpeg"
            ? "image/jpeg"
            : "image/tiff";

      return {
        content: [
          {
            type: "image",
            data: payload.data,
            mimeType,
          },
        ],
      };
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result.payload, null, 2),
        },
      ],
    };
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unknown error occurred";

    // Check if it's a connection error
    if (message.includes("ECONNREFUSED") || message.includes("fetch failed")) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error:
                "Cannot connect to GardenBridge. Make sure GardenBridge.app is running.",
              details: message,
            }),
          },
        ],
        isError: true,
      };
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({ error: message }),
        },
      ],
      isError: true,
    };
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("GardenBridge MCP server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
