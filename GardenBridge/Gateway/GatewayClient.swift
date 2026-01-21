import Foundation

/// WebSocket client for connecting to Clawdbot Gateway
actor GatewayClient {
    private let connectionState: ConnectionState
    private let commandHandler: CommandHandler
    private let deviceIdentity: DeviceIdentity

    private let connectDelay = Duration.milliseconds(500)
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pendingRequests: [String: CheckedContinuation<GatewayResponse, Error>] = [:]
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?

    private var challengeNonce: String?
    private var challengeTimestamp: Int64?

    init(connectionState: ConnectionState, commandHandler: CommandHandler) {
        self.connectionState = connectionState
        self.commandHandler = commandHandler
        self.deviceIdentity = DeviceIdentity()
    }

    // MARK: - Public Methods

    func connect() async {
        await self.updateStatus(.connecting)

        guard let url = await connectionState.gatewayURL else {
            await self.updateStatus(.error("Invalid gateway URL"))
            return
        }

        // Create URL session and WebSocket task
        self.urlSession = URLSession(configuration: .default)
        self.webSocketTask = self.urlSession?.webSocketTask(with: url)
        self.webSocketTask?.resume()

        // Start receiving messages
        self.receiveTask = Task {
            await self.receiveMessages()
        }

        // Wait for challenge event, then send connect request
        // The challenge should arrive shortly after connection
        try? await Task.sleep(for: self.connectDelay)

        // Send connect request
        await self.sendConnectRequest()
    }

    func disconnect() async {
        self.receiveTask?.cancel()
        self.pingTask?.cancel()
        self.webSocketTask?.cancel(with: .goingAway, reason: nil)
        self.webSocketTask = nil
        self.urlSession = nil

        await self.updateStatus(.disconnected)
    }

    // MARK: - Private Methods

    private func receiveMessages() async {
        guard let webSocket = webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await webSocket.receive()

                switch message {
                case let .string(text):
                    await self.handleMessage(text)
                case let .data(data):
                    if let text = String(data: data, encoding: .utf8) {
                        await self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                if !Task.isCancelled {
                    print("WebSocket receive error: \(error)")
                    await self.updateStatus(.error("Connection lost: \(error.localizedDescription)"))
                }
                break
            }
        }
    }

    private func handleMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else { return }

        guard let envelope = decodeMessageEnvelope(from: data) else {
            print("Failed to decode message envelope: \(text)")
            return
        }

        switch envelope.type {
        case "event":
            await self.handleEvent(data: data, event: envelope.event)

        case "res":
            await self.handleResponse(data: data, id: envelope.id)

        case "invoke":
            await self.handleInvoke(data: data)

        case "ping":
            await self.sendPong()

        default:
            print("Unknown message type: \(envelope.type)")
        }
    }

    private func handleEvent(data: Data, event: String?) async {
        guard let event else { return }

        switch event {
        case "connect.challenge":
            // Decode challenge
            struct ChallengeEvent: Codable {
                let payload: ConnectChallengePayload
            }

            if let challenge = try? jsonDecoder.decode(ChallengeEvent.self, from: data) {
                self.challengeNonce = challenge.payload.nonce
                self.challengeTimestamp = challenge.payload.ts
            }

        default:
            print("Received event: \(event)")
        }
    }

    private func handleResponse(data: Data, id: String?) async {
        guard let id,
              let response = try? jsonDecoder.decode(GatewayResponse.self, from: data)
        else {
            return
        }

        // Check for hello-ok response
        if response.ok, let payload = response.payload {
            if let dict = payload.dictionaryValue,
               let type = dict["type"] as? String,
               type == "hello-ok"
            {
                await self.handleHelloOk(payload: payload)
            }
        }

        // Resume any pending request continuation
        if let continuation = pendingRequests.removeValue(forKey: id) {
            continuation.resume(returning: response)
        }
    }

    private func handleHelloOk(payload: AnyCodable) async {
        // Extract device token if present
        if let dict = payload.dictionaryValue,
           let auth = dict["auth"] as? [String: Any],
           let deviceToken = auth["deviceToken"] as? String
        {
            await self.updateDeviceToken(deviceToken)
        }

        // Update status to paired
        await self.updateStatus(.paired)

        // Start ping task
        self.pingTask = Task {
            await self.sendPings()
        }
    }

    private func handleInvoke(data: Data) async {
        guard let invoke = try? jsonDecoder.decode(GatewayInvoke.self, from: data) else {
            print("Failed to decode invoke message")
            return
        }

        // Handle the command
        let response = await commandHandler.handle(invoke: invoke)

        // Send response
        await self.sendInvokeResponse(response)
    }

    private func sendConnectRequest() async {
        let deviceInfo = await deviceIdentity.createDeviceInfo(
            nonce: self.challengeNonce,
            timestamp: self.challengeTimestamp)

        let deviceToken = await MainActor.run { self.connectionState.deviceToken }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let params = await ConnectParams(
            minProtocol: GATEWAY_PROTOCOL_VERSION,
            maxProtocol: GATEWAY_PROTOCOL_VERSION,
            client: ClientInfo(
                id: "gardenbridge-macos",
                version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                platform: "macos",
                mode: "node"),
            role: "node",
            scopes: [],
            caps: NodeCapability.allCases.map(\.rawValue),
            commands: NodeCommand.allCases.map(\.rawValue),
            permissions: self.commandHandler.getPermissions(),
            auth: AuthInfo(token: nil, deviceToken: deviceToken),
            locale: Locale.current.identifier,
            userAgent: "GardenBridge/\(appVersion) macOS",
            device: deviceInfo)

        let request = GatewayRequest(
            method: "connect",
            params: [
                "minProtocol": AnyCodable(params.minProtocol),
                "maxProtocol": AnyCodable(params.maxProtocol),
                "client": AnyCodable([
                    "id": params.client.id,
                    "version": params.client.version,
                    "platform": params.client.platform,
                    "mode": params.client.mode,
                ]),
                "role": AnyCodable(params.role),
                "scopes": AnyCodable(params.scopes),
                "caps": AnyCodable(params.caps),
                "commands": AnyCodable(params.commands),
                "permissions": AnyCodable(params.permissions),
                "auth": AnyCodable([
                    "token": params.auth?.token as Any,
                    "deviceToken": params.auth?.deviceToken as Any,
                ]),
                "locale": AnyCodable(params.locale),
                "userAgent": AnyCodable(params.userAgent),
                "device": AnyCodable([
                    "id": params.device.id,
                    "publicKey": params.device.publicKey as Any,
                    "signature": params.device.signature as Any,
                    "signedAt": params.device.signedAt as Any,
                    "nonce": params.device.nonce as Any,
                ]),
            ])

        await self.sendRequest(request)

        // Update status to connected (awaiting pairing)
        await self.updateStatus(.connected)
    }

    // MARK: - Main Actor Updates

    private func updateStatus(_ status: GatewayConnectionStatus) async {
        await MainActor.run {
            self.connectionState.setStatus(status)
        }
    }

    private func updateDeviceToken(_ token: String) async {
        await MainActor.run {
            self.connectionState.deviceToken = token
            self.connectionState.saveSettings()
        }
    }

    private func sendRequest(_ request: GatewayRequest) async {
        guard let webSocket = webSocketTask else { return }

        do {
            let data = try jsonEncoder.encode(request)
            if let text = String(data: data, encoding: .utf8) {
                try await webSocket.send(.string(text))
            }
        } catch {
            print("Failed to send request: \(error)")
        }
    }

    private func sendInvokeResponse(_ response: GatewayInvokeResponse) async {
        guard let webSocket = webSocketTask else { return }

        do {
            let data = try jsonEncoder.encode(response)
            if let text = String(data: data, encoding: .utf8) {
                try await webSocket.send(.string(text))
            }
        } catch {
            print("Failed to send invoke response: \(error)")
        }
    }

    private func sendPong() async {
        guard let webSocket = webSocketTask else { return }

        let pong = ["type": "pong"]

        do {
            let data = try JSONSerialization.data(withJSONObject: pong)
            if let text = String(data: data, encoding: .utf8) {
                try await webSocket.send(.string(text))
            }
        } catch {
            print("Failed to send pong: \(error)")
        }
    }

    private func sendPings() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(15))

            guard let webSocket = webSocketTask else { break }

            let ping = ["type": "ping"]

            do {
                let data = try JSONSerialization.data(withJSONObject: ping)
                if let text = String(data: data, encoding: .utf8) {
                    try await webSocket.send(.string(text))
                }
            } catch {
                print("Failed to send ping: \(error)")
                break
            }
        }
    }

    private func decodeMessageEnvelope(from data: Data) -> MessageEnvelope? {
        try? self.jsonDecoder.decode(MessageEnvelope.self, from: data)
    }
}

private struct MessageEnvelope: Codable {
    let type: String
    let id: String?
    let event: String?
}
