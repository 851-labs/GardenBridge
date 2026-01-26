import Foundation
import Network

/// HTTP server for local MCP server integration
/// Listens on localhost:18790 and forwards commands to CommandHandler
actor HTTPServer {
  private let commandHandler: CommandHandler
  private var listener: NWListener?
  private let port: UInt16 = 28790

  private let jsonEncoder = JSONEncoder()
  private let jsonDecoder = JSONDecoder()

  init(commandHandler: CommandHandler) {
    self.commandHandler = commandHandler
  }

  func start() async throws {
    let parameters = NWParameters.tcp
    parameters.allowLocalEndpointReuse = true

    // Only bind to localhost for security
    let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: self.port)!)
    self.listener = listener

    listener.stateUpdateHandler = { [weak self] state in
      Task { await self?.handleStateUpdate(state) }
    }

    listener.newConnectionHandler = { [weak self] connection in
      Task { await self?.handleConnection(connection) }
    }

    listener.start(queue: .global(qos: .userInitiated))
    print("[HTTPServer] Started on localhost:\(self.port)")
  }

  func stop() {
    self.listener?.cancel()
    self.listener = nil
    print("[HTTPServer] Stopped")
  }

  // MARK: - Connection Handling

  private func handleStateUpdate(_ state: NWListener.State) {
    switch state {
    case .ready:
      print("[HTTPServer] Ready and listening")
    case let .failed(error):
      print("[HTTPServer] Failed: \(error)")
    case .cancelled:
      print("[HTTPServer] Cancelled")
    default:
      break
    }
  }

  private func handleConnection(_ connection: NWConnection) {
    connection.stateUpdateHandler = { [weak self] state in
      if case .ready = state {
        self?.receiveRequest(connection)
      }
    }
    connection.start(queue: .global(qos: .userInitiated))
  }

  private nonisolated func receiveRequest(_ connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
      guard let self else { return }
      Task {
        await self.processRequest(connection: connection, data: data, error: error)
      }
    }
  }

  private func processRequest(connection: NWConnection, data: Data?, error: NWError?) {
    guard let data, error == nil else {
      connection.cancel()
      return
    }

    // Parse HTTP request
    guard let request = parseHTTPRequest(data) else {
      self.sendResponse(
        connection: connection,
        statusCode: 400,
        body: self.errorJSON(code: "BAD_REQUEST", message: "Invalid HTTP request"))
      return
    }

    // Handle screenshot requests: GET /screenshot/{id}
    if request.method == "GET", request.path.hasPrefix("/screenshot/") {
      let imageId = String(request.path.dropFirst("/screenshot/".count))
      Task {
        await self.handleScreenshotRequest(connection: connection, imageId: imageId)
      }
      return
    }

    // Only accept POST /invoke
    guard request.method == "POST", request.path == "/invoke" else {
      self.sendResponse(
        connection: connection,
        statusCode: 404,
        body: self.errorJSON(code: "NOT_FOUND", message: "Use POST /invoke"))
      return
    }

    // Parse JSON body
    guard let invokeRequest = parseInvokeRequest(request.body) else {
      self.sendResponse(
        connection: connection,
        statusCode: 400,
        body: self.errorJSON(code: "INVALID_JSON", message: "Invalid request body"))
      return
    }

    // Execute command
    Task {
      let response = await self.executeInvoke(command: invokeRequest.command, params: invokeRequest.params)
      self.sendResponse(connection: connection, statusCode: 200, body: response)
    }
  }

  // MARK: - Screenshot Serving

  private func handleScreenshotRequest(connection: NWConnection, imageId: String) async {
    guard let fileURL = await ScreenshotStorage.shared.get(id: imageId) else {
      self.sendResponse(
        connection: connection,
        statusCode: 404,
        body: self.errorJSON(code: "NOT_FOUND", message: "Screenshot not found"))
      return
    }

    do {
      let data = try Data(contentsOf: fileURL)
      let ext = fileURL.pathExtension.lowercased()
      let contentType = switch ext {
      case "jpg", "jpeg": "image/jpeg"
      case "png": "image/png"
      case "tiff": "image/tiff"
      default: "application/octet-stream"
      }
      self.sendImageResponse(connection: connection, data: data, contentType: contentType)
    } catch {
      self.sendResponse(
        connection: connection,
        statusCode: 500,
        body: self.errorJSON(code: "READ_ERROR", message: "Failed to read screenshot"))
    }
  }

  private nonisolated func sendImageResponse(connection: NWConnection, data: Data, contentType: String) {
    var response = "HTTP/1.1 200 OK\r\n"
    response += "Content-Type: \(contentType)\r\n"
    response += "Content-Length: \(data.count)\r\n"
    response += "Access-Control-Allow-Origin: *\r\n"
    response += "Cache-Control: public, max-age=300\r\n"
    response += "Connection: close\r\n"
    response += "\r\n"

    var responseData = response.data(using: .utf8)!
    responseData.append(data)

    connection.send(content: responseData, completion: .contentProcessed { _ in
      connection.cancel()
    })
  }

  // MARK: - Command Execution

  private func executeInvoke(command: String, params: [String: AnyCodable]?) async -> Data {
    let invoke = GatewayInvoke(
      type: "invoke",
      id: UUID().uuidString,
      command: command,
      params: params)

    let response = await commandHandler.handle(invoke: invoke)

    // Convert to simple JSON response
    let httpResponse = HTTPInvokeResponse(
      ok: response.ok,
      payload: response.payload,
      error: response.error)

    return (try? self.jsonEncoder.encode(httpResponse)) ?? self.errorJSON(
      code: "ENCODE_ERROR",
      message: "Failed to encode response")
  }

  // MARK: - HTTP Parsing

  private struct HTTPRequest {
    let method: String
    let path: String
    let body: Data
  }

  private func parseHTTPRequest(_ data: Data) -> HTTPRequest? {
    guard let string = String(data: data, encoding: .utf8) else { return nil }

    // Split headers and body
    let parts = string.components(separatedBy: "\r\n\r\n")
    guard parts.count >= 1 else { return nil }

    let headerSection = parts[0]
    let bodyString = parts.count > 1 ? parts[1] : ""

    // Parse request line
    let lines = headerSection.components(separatedBy: "\r\n")
    guard let requestLine = lines.first else { return nil }

    let requestParts = requestLine.components(separatedBy: " ")
    guard requestParts.count >= 2 else { return nil }

    let method = requestParts[0]
    let path = requestParts[1]
    let body = bodyString.data(using: .utf8) ?? Data()

    return HTTPRequest(method: method, path: path, body: body)
  }

  // MARK: - Request/Response Types

  private struct InvokeRequest: Codable {
    let command: String
    let params: [String: AnyCodable]?
  }

  private func parseInvokeRequest(_ data: Data) -> InvokeRequest? {
    try? self.jsonDecoder.decode(InvokeRequest.self, from: data)
  }

  private struct HTTPInvokeResponse: Codable {
    let ok: Bool
    let payload: AnyCodable?
    let error: GatewayError?
  }

  private func errorJSON(code: String, message: String) -> Data {
    let response = HTTPInvokeResponse(ok: false, payload: nil, error: GatewayError(code: code, message: message))
    return (try? self.jsonEncoder.encode(response)) ?? Data()
  }

  // MARK: - HTTP Response

  private nonisolated func sendResponse(connection: NWConnection, statusCode: Int, body: Data) {
    let statusText = switch statusCode {
    case 200: "OK"
    case 400: "Bad Request"
    case 404: "Not Found"
    default: "Error"
    }

    var response = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
    response += "Content-Type: application/json\r\n"
    response += "Content-Length: \(body.count)\r\n"
    response += "Access-Control-Allow-Origin: *\r\n"
    response += "Connection: close\r\n"
    response += "\r\n"

    var responseData = response.data(using: .utf8)!
    responseData.append(body)

    connection.send(content: responseData, completion: .contentProcessed { _ in
      connection.cancel()
    })
  }
}
