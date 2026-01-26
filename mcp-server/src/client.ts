/**
 * HTTP client for communicating with GardenBridge
 */

const GARDENBRIDGE_URL = "http://localhost:28790";

export interface InvokeResponse {
  ok: boolean;
  payload?: unknown;
  error?: {
    code: string;
    message: string;
  };
}

export async function invoke(
  command: string,
  params?: Record<string, unknown>
): Promise<InvokeResponse> {
  const response = await fetch(`${GARDENBRIDGE_URL}/invoke`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ command, params }),
  });

  if (!response.ok) {
    return {
      ok: false,
      error: {
        code: "HTTP_ERROR",
        message: `HTTP ${response.status}: ${response.statusText}`,
      },
    };
  }

  return response.json();
}

export async function checkConnection(): Promise<boolean> {
  try {
    const result = await invoke("file.exists", { path: "/" });
    return result.ok;
  } catch {
    return false;
  }
}
