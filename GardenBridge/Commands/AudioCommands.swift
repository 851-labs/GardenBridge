import Foundation
@preconcurrency import AVFoundation

/// Storage for temporary audio recordings
actor AudioStorage {
  static let shared = AudioStorage()

  private var recordings: [String: URL] = [:]
  private let tempDirectory: URL

  private init() {
    self.tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("gardenbridge-audio")
    try? FileManager.default.createDirectory(at: self.tempDirectory, withIntermediateDirectories: true)
  }

  func store(url: URL, format: String) -> String {
    let id = UUID().uuidString
    self.recordings[id] = url
    Task {
      try? await Task.sleep(for: .seconds(600))
      await self.remove(id: id)
    }
    return id
  }

  func get(id: String) -> URL? {
    self.recordings[id]
  }

  func remove(id: String) {
    if let url = self.recordings.removeValue(forKey: id) {
      try? FileManager.default.removeItem(at: url)
    }
  }
}

/// Handles audio recording commands
actor AudioCommands: CommandExecutor {
  private let serverPort: UInt16 = 28790
  private var activeRecorder: AVAudioRecorder?
  private var activeDelegate: AudioRecorderDelegate?

  func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
    switch command {
    case "audio.record":
      return try await self.record(params: params)
    case "audio.getDevices":
      return try await self.getDevices()
    default:
      throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown audio command: \(command)")
    }
  }

  // MARK: - Devices

  private func getDevices() async throws -> AnyCodable {
    try await self.ensureAuthorization()

    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone, .external],
      mediaType: .audio,
      position: .unspecified)

    let devices = discovery.devices.map { device -> [String: Any] in
      [
        "id": device.uniqueID,
        "name": device.localizedName,
        "manufacturer": device.manufacturer,
        "modelID": device.modelID,
        "isConnected": device.isConnected,
      ]
    }

    return AnyCodable([
      "count": devices.count,
      "devices": devices,
    ])
  }

  // MARK: - Recording

  private func record(params: [String: AnyCodable]) async throws -> AnyCodable {
    try await self.ensureAuthorization()

    let duration = min(max(params["duration"]?.doubleValue ?? 5, 1), 300)
    let format = (params["format"]?.stringValue ?? "m4a").lowercased()

    if let requestedDevice = params["device"]?.stringValue {
      let defaultId = AVCaptureDevice.default(for: .audio)?.uniqueID
      if defaultId != requestedDevice {
        throw CommandError(code: "DEVICE_NOT_SUPPORTED", message: "Recording from specific devices is not supported")
      }
    }

    let fileURL = self.makeRecordingURL(format: format)
    let settings = self.settings(for: format)

    let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
    recorder.prepareToRecord()

    let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
      let delegate = AudioRecorderDelegate(continuation: continuation) { [weak self] in
        Task { await self?.clearActiveRecorder() }
      }

      self.activeRecorder = recorder
      self.activeDelegate = delegate
      recorder.delegate = delegate
      recorder.record(forDuration: duration)
    }

    let audioId = await AudioStorage.shared.store(url: result, format: format)
    let audioUrl = "http://localhost:\(self.serverPort)/audio/\(audioId)"

    return AnyCodable([
      "audioId": audioId,
      "audioUrl": audioUrl,
      "format": format,
      "duration": duration,
      "mimeType": self.mimeType(for: format),
    ])
  }

  // MARK: - Authorization

  private func ensureAuthorization() async throws {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      return
    case .notDetermined:
      let granted = await withCheckedContinuation { continuation in
        AVCaptureDevice.requestAccess(for: .audio) { allowed in
          continuation.resume(returning: allowed)
        }
      }
      if !granted {
        throw CommandError.permissionDenied
      }
    default:
      throw CommandError.permissionDenied
    }
  }

  // MARK: - Helpers

  private func makeRecordingURL(format: String) -> URL {
    let ext = format == "wav" ? "wav" : "m4a"
    let filename = "\(UUID().uuidString).\(ext)"
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gardenbridge-audio")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent(filename)
  }

  private func settings(for format: String) -> [String: Any] {
    if format == "wav" {
      return [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false,
      ]
    }

    return [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
  }

  private func mimeType(for format: String) -> String {
    format == "wav" ? "audio/wav" : "audio/m4a"
  }

  private func clearActiveRecorder() {
    self.activeRecorder = nil
    self.activeDelegate = nil
  }
}

private final class AudioRecorderDelegate: NSObject, AVAudioRecorderDelegate, @unchecked Sendable {
  private var continuation: CheckedContinuation<URL, Error>?
  private let onFinish: @Sendable () -> Void

  init(continuation: CheckedContinuation<URL, Error>, onFinish: @escaping @Sendable () -> Void) {
    self.continuation = continuation
    self.onFinish = onFinish
    super.init()
  }

  func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    if flag {
      self.continuation?.resume(returning: recorder.url)
    } else {
      self.continuation?.resume(throwing: CommandError(code: "RECORD_FAILED", message: "Audio recording failed"))
    }
    self.continuation = nil
    self.onFinish()
  }

  func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    if let error {
      self.continuation?.resume(throwing: error)
      self.continuation = nil
      self.onFinish()
    }
  }
}
