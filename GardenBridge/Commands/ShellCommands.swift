import Foundation

/// Handles shell command execution
actor ShellCommands: CommandExecutor {
    private let shellURL = URL(fileURLWithPath: "/bin/zsh")
    private let whichURL = URL(fileURLWithPath: "/usr/bin/which")
    
    func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
        switch command {
        case "shell.execute":
            return try await executeShell(params: params)
        case "shell.which":
            return try await whichCommand(params: params)
        default:
            throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown shell command: \(command)")
        }
    }
    
    // MARK: - Execute Shell Command
    
    private func executeShell(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let command = params["command"]?.stringValue else {
            throw CommandError.invalidParam("command")
        }
        
        let workingDirectory = params["cwd"]?.stringValue
        let timeout = params["timeout"]?.intValue ?? 30
        let timeoutDuration = Duration.seconds(timeout)
        let environment = params["env"]?.dictionaryValue as? [String: String]
        
        // Create process
        let process = Process()
        process.executableURL = shellURL
        process.arguments = ["-c", command]
        
        // Set working directory if specified
        if let cwd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: expandPath(cwd))
        }
        
        // Set environment if specified
        if let env = environment {
            process.environment = mergedEnvironment(with: env)
        }
        
        // Create pipes for output
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        // Run with timeout
        let startTime = Date()
        
        do {
            try process.run()
        } catch {
            throw CommandError(code: "EXEC_FAILED", message: "Failed to execute command: \(error.localizedDescription)")
        }
        
        // Wait with timeout
        let timeoutTask = Task {
            try? await Task.sleep(for: timeoutDuration)
            if process.isRunning {
                process.terminate()
            }
        }
        
        process.waitUntilExit()
        timeoutTask.cancel()
        
        let duration = Date().timeIntervalSince(startTime)
        let timedOut = duration >= Double(timeout)
        
        // Read output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        
        let exitCode = Int(process.terminationStatus)
        
        return AnyCodable([
            "exitCode": exitCode,
            "stdout": stdout,
            "stderr": stderr,
            "success": exitCode == 0,
            "timedOut": timedOut,
            "duration": duration
        ])
    }
    
    // MARK: - Which Command
    
    private func whichCommand(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let command = params["command"]?.stringValue else {
            throw CommandError.invalidParam("command")
        }
        
        let process = Process()
        process.executableURL = whichURL
        process.arguments = [command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw CommandError(code: "WHICH_FAILED", message: "Failed to run which command")
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let found = process.terminationStatus == 0 && path != nil && !path!.isEmpty
        
        return AnyCodable([
            "command": command,
            "found": found,
            "path": path as Any
        ])
    }

    private func expandPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private func mergedEnvironment(with overrides: [String: String]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        for (key, value) in overrides {
            environment[key] = value
        }
        return environment
    }
}
