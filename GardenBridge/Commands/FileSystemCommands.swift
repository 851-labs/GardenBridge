import Foundation

/// Handles file system commands
actor FileSystemCommands: CommandExecutor {
    private let fileManager = FileManager.default

    func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
        switch command {
        case "file.read":
            return try await self.readFile(params: params)
        case "file.write":
            return try await self.writeFile(params: params)
        case "file.list":
            return try await self.listDirectory(params: params)
        case "file.exists":
            return try await self.fileExists(params: params)
        case "file.delete":
            return try await self.deleteFile(params: params)
        case "file.info":
            return try await self.fileInfo(params: params)
        default:
            throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown file command: \(command)")
        }
    }

    // MARK: - Read File

    private func readFile(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let path = params["path"]?.stringValue else {
            throw CommandError.invalidParam("path")
        }

        let expandedPath = self.expandPath(path)

        guard self.fileManager.fileExists(atPath: expandedPath) else {
            throw CommandError.notFound
        }

        let encoding = params["encoding"]?.stringValue ?? "utf8"

        // Check if binary read is requested
        if params["binary"]?.boolValue == true {
            let data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
            return AnyCodable([
                "content": data.base64EncodedString(),
                "encoding": "base64",
                "size": data.count,
            ])
        }

        // Text read
        let stringEncoding = stringEncoding(for: encoding)

        let content = try String(contentsOfFile: expandedPath, encoding: stringEncoding)

        return AnyCodable([
            "content": content,
            "encoding": encoding,
            "size": content.count,
        ])
    }

    // MARK: - Write File

    private func writeFile(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let path = params["path"]?.stringValue else {
            throw CommandError.invalidParam("path")
        }

        guard let content = params["content"]?.stringValue else {
            throw CommandError.invalidParam("content")
        }

        let expandedPath = self.expandPath(path)
        let url = URL(fileURLWithPath: expandedPath)

        // Create parent directory if needed
        let parentDir = url.deletingLastPathComponent()
        if !self.fileManager.fileExists(atPath: parentDir.path) {
            try self.fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // Check if content is base64 encoded binary
        if params["binary"]?.boolValue == true {
            guard let data = Data(base64Encoded: content) else {
                throw CommandError(code: "INVALID_BASE64", message: "Content is not valid base64")
            }
            try data.write(to: url)
        } else {
            let encoding = params["encoding"]?.stringValue ?? "utf8"
            let stringEncoding = stringEncoding(for: encoding)

            let append = params["append"]?.boolValue ?? false

            if append, self.fileManager.fileExists(atPath: expandedPath) {
                let handle = try FileHandle(forWritingTo: url)
                handle.seekToEndOfFile()
                if let data = content.data(using: stringEncoding) {
                    handle.write(data)
                }
                try handle.close()
            } else {
                try content.write(toFile: expandedPath, atomically: true, encoding: stringEncoding)
            }
        }

        return AnyCodable([
            "success": true,
            "path": expandedPath,
        ])
    }

    // MARK: - List Directory

    private func listDirectory(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let path = params["path"]?.stringValue else {
            throw CommandError.invalidParam("path")
        }

        let expandedPath = self.expandPath(path)
        let recursive = params["recursive"]?.boolValue ?? false
        let includeHidden = params["includeHidden"]?.boolValue ?? false

        var isDirectory: ObjCBool = false
        guard self.fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw CommandError(code: "NOT_DIRECTORY", message: "Path is not a directory")
        }

        var items: [[String: Any]] = []

        if recursive {
            if let enumerator = fileManager.enumerator(atPath: expandedPath) {
                while let item = enumerator.nextObject() as? String {
                    if !includeHidden, item.hasPrefix(".") {
                        continue
                    }
                    let fullPath = (expandedPath as NSString).appendingPathComponent(item)
                    if let info = getFileInfo(path: fullPath) {
                        var itemInfo = info
                        itemInfo["name"] = item
                        items.append(itemInfo)
                    }
                }
            }
        } else {
            let contents = try fileManager.contentsOfDirectory(atPath: expandedPath)
            for item in contents {
                if !includeHidden, item.hasPrefix(".") {
                    continue
                }
                let fullPath = (expandedPath as NSString).appendingPathComponent(item)
                if let info = getFileInfo(path: fullPath) {
                    var itemInfo = info
                    itemInfo["name"] = item
                    items.append(itemInfo)
                }
            }
        }

        return AnyCodable([
            "items": items,
            "count": items.count,
            "path": expandedPath,
        ])
    }

    // MARK: - File Exists

    private func fileExists(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let path = params["path"]?.stringValue else {
            throw CommandError.invalidParam("path")
        }

        let expandedPath = self.expandPath(path)
        var isDirectory: ObjCBool = false
        let exists = self.fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory)

        return AnyCodable([
            "exists": exists,
            "isDirectory": isDirectory.boolValue,
            "path": expandedPath,
        ])
    }

    // MARK: - Delete File

    private func deleteFile(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let path = params["path"]?.stringValue else {
            throw CommandError.invalidParam("path")
        }

        let expandedPath = self.expandPath(path)

        guard self.fileManager.fileExists(atPath: expandedPath) else {
            throw CommandError.notFound
        }

        try self.fileManager.removeItem(atPath: expandedPath)

        return AnyCodable([
            "success": true,
            "path": expandedPath,
        ])
    }

    // MARK: - File Info

    private func fileInfo(params: [String: AnyCodable]) async throws -> AnyCodable {
        guard let path = params["path"]?.stringValue else {
            throw CommandError.invalidParam("path")
        }

        let expandedPath = self.expandPath(path)

        guard let info = getFileInfo(path: expandedPath) else {
            throw CommandError.notFound
        }

        return AnyCodable(info)
    }

    // MARK: - Helpers

    private func getFileInfo(path: String) -> [String: Any]? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path) else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        var isDirectory: ObjCBool = false
        self.fileManager.fileExists(atPath: path, isDirectory: &isDirectory)

        var info: [String: Any] = [
            "path": path,
            "isDirectory": isDirectory.boolValue,
            "size": attributes[.size] as? Int ?? 0,
        ]

        if let creationDate = attributes[.creationDate] as? Date {
            info["createdAt"] = formatter.string(from: creationDate)
        }

        if let modificationDate = attributes[.modificationDate] as? Date {
            info["modifiedAt"] = formatter.string(from: modificationDate)
        }

        if let permissions = attributes[.posixPermissions] as? Int {
            info["permissions"] = String(format: "%o", permissions)
        }

        return info
    }

    private func expandPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private func stringEncoding(for encoding: String) -> String.Encoding {
        switch encoding.lowercased() {
        case "utf8", "utf-8": .utf8
        case "ascii": .ascii
        case "utf16", "utf-16": .utf16
        case "latin1", "iso-8859-1": .isoLatin1
        default: .utf8
        }
    }
}
