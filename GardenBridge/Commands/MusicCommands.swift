import Foundation

/// Handles Apple Music control using AppleScript
actor MusicCommands: CommandExecutor {
  func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
    switch command {
    case "music.play":
      return try await self.play(params: params)
    case "music.pause":
      return try await self.pause()
    case "music.stop":
      return try await self.stop()
    case "music.next":
      return try await self.nextTrack()
    case "music.previous":
      return try await self.previousTrack()
    case "music.togglePlayPause":
      return try await self.togglePlayPause()
    case "music.setVolume":
      return try await self.setVolume(params: params)
    case "music.nowPlaying":
      return try await self.nowPlaying()
    case "music.search":
      return try await self.search(params: params)
    case "music.getPlaylists":
      return try await self.getPlaylists()
    case "music.playPlaylist":
      return try await self.playPlaylist(params: params)
    default:
      throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown music command: \(command)")
    }
  }

  // MARK: - Playback Control

  private func play(params: [String: AnyCodable]) async throws -> AnyCodable {
    if let track = params["track"]?.stringValue, !track.isEmpty {
      let escaped = self.escapeAppleScript(track)
      let script = """
      tell application \"Music\"
        set results to (search library playlist 1 for \"\(escaped)\")
        if (count of results) is 0 then
          return \"\"
        end if
        play item 1 of results
        return name of item 1 of results
      end tell
      """
      let result = try await self.runAppleScript(script)
      guard let name = result, !name.isEmpty else {
        throw CommandError.notFound
      }
      return AnyCodable(["track": name])
    }

    _ = try await self.runAppleScript("tell application \"Music\" to play")
    return AnyCodable(["success": true])
  }

  private func pause() async throws -> AnyCodable {
    _ = try await self.runAppleScript("tell application \"Music\" to pause")
    return AnyCodable(["success": true])
  }

  private func stop() async throws -> AnyCodable {
    _ = try await self.runAppleScript("tell application \"Music\" to stop")
    return AnyCodable(["success": true])
  }

  private func nextTrack() async throws -> AnyCodable {
    _ = try await self.runAppleScript("tell application \"Music\" to next track")
    return AnyCodable(["success": true])
  }

  private func previousTrack() async throws -> AnyCodable {
    _ = try await self.runAppleScript("tell application \"Music\" to previous track")
    return AnyCodable(["success": true])
  }

  private func togglePlayPause() async throws -> AnyCodable {
    let script = """
    tell application \"Music\"
      if player state is playing then
        pause
        return \"paused\"
      else
        play
        return \"playing\"
      end if
    end tell
    """
    let state = try await self.runAppleScript(script) ?? ""
    return AnyCodable(["state": state])
  }

  private func setVolume(params: [String: AnyCodable]) async throws -> AnyCodable {
    guard let volume = params["volume"]?.intValue else {
      throw CommandError.invalidParam("volume")
    }

    let clamped = max(0, min(100, volume))
    _ = try await self.runAppleScript("tell application \"Music\" to set sound volume to \(clamped)")
    return AnyCodable(["volume": clamped])
  }

  // MARK: - Now Playing

  private func nowPlaying() async throws -> AnyCodable {
    let script = """
    tell application \"Music\"
      if player state is stopped then
        return \"\"
      end if
      set t to current track
      set stateStr to (player state as string)
      set nameStr to name of t
      set artistStr to artist of t
      set albumStr to album of t
      set durationStr to duration of t
      set positionStr to player position
      return stateStr & \"||\" & nameStr & \"||\" & artistStr & \"||\" & albumStr & \"||\" & durationStr & \"||\" & positionStr
    end tell
    """

    guard let output = try await self.runAppleScript(script), !output.isEmpty else {
      return AnyCodable(["state": "stopped"])
    }

    let parts = output.components(separatedBy: "||")
    if parts.count < 6 {
      return AnyCodable(["state": "unknown"])
    }

    let duration = Double(parts[4]) ?? 0
    let position = Double(parts[5]) ?? 0

    return AnyCodable([
      "state": parts[0],
      "name": parts[1],
      "artist": parts[2],
      "album": parts[3],
      "duration": duration,
      "position": position,
    ])
  }

  // MARK: - Library

  private func search(params: [String: AnyCodable]) async throws -> AnyCodable {
    guard let query = params["query"]?.stringValue, !query.isEmpty else {
      throw CommandError.invalidParam("query")
    }

    let limit = params["limit"]?.intValue ?? 10
    let escaped = self.escapeAppleScript(query)
    let script = """
    tell application \"Music\"
      set results to (search library playlist 1 for \"\(escaped)\")
      set maxCount to \(limit)
      set output to \"\"
      repeat with i from 1 to (min(maxCount, count of results))
        set t to item i of results
        set output to output & name of t & \"||\" & artist of t & \"||\" & album of t & \"||\" & duration of t & "\\n"
      end repeat
      return output
    end tell
    """

    let output = try await self.runAppleScript(script) ?? ""
    let lines = output.split(separator: "\n")
    let tracks = lines.compactMap { line -> [String: Any]? in
      let parts = line.components(separatedBy: "||")
      guard parts.count >= 4 else { return nil }
      return [
        "name": parts[0],
        "artist": parts[1],
        "album": parts[2],
        "duration": Double(parts[3]) ?? 0,
      ]
    }

    return AnyCodable([
      "query": query,
      "count": tracks.count,
      "tracks": tracks,
    ])
  }

  private func getPlaylists() async throws -> AnyCodable {
    let script = """
    tell application \"Music\"
      set namesList to name of playlists
      set AppleScript's text item delimiters to \"||\"
      return namesList as text
    end tell
    """

    let output = try await self.runAppleScript(script) ?? ""
    let playlists = output.isEmpty ? [] : output.components(separatedBy: "||")

    return AnyCodable([
      "count": playlists.count,
      "playlists": playlists,
    ])
  }

  private func playPlaylist(params: [String: AnyCodable]) async throws -> AnyCodable {
    guard let name = params["name"]?.stringValue, !name.isEmpty else {
      throw CommandError.invalidParam("name")
    }

    let escaped = self.escapeAppleScript(name)
    let script = """
    tell application \"Music\"
      set matches to (every playlist whose name is \"\(escaped)\")
      if (count of matches) is 0 then
        return \"\"
      end if
      play item 1 of matches
      return name of item 1 of matches
    end tell
    """

    let output = try await self.runAppleScript(script) ?? ""
    guard !output.isEmpty else {
      throw CommandError.notFound
    }

    return AnyCodable(["playlist": output])
  }

  // MARK: - Helpers

  private func escapeAppleScript(_ input: String) -> String {
    input.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }

  private func runAppleScript(_ script: String) async throws -> String? {
    let result = await MainActor.run { () -> Result<String?, CommandError> in
      var errorInfo: NSDictionary?
      let appleScript = NSAppleScript(source: script)
      let eventDescriptor = appleScript?.executeAndReturnError(&errorInfo)

      if let error = errorInfo {
        let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
        let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
        if errorNumber == -1743 {
          return .failure(CommandError.permissionDenied)
        }
        return .failure(CommandError(code: "APPLESCRIPT_ERROR_\(errorNumber)", message: errorMessage))
      }

      return .success(eventDescriptor?.stringValue)
    }

    switch result {
    case let .success(output):
      return output
    case let .failure(error):
      throw error
    }
  }
}
