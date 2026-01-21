import Foundation
@preconcurrency import AVFoundation
import AppKit

/// Handles camera capture commands using AVFoundation
actor CameraCommands: CommandExecutor {
    private var activeDelegate: PhotoCaptureDelegate?
    
    func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
        switch command {
        case "camera.snap":
            return try await capturePhoto(params: params)
        case "camera.list":
            return try await listCameras()
        default:
            throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown camera command: \(command)")
        }
    }
    
    // MARK: - Capture Photo
    
    private func capturePhoto(params: [String: AnyCodable]) async throws -> AnyCodable {
        let cameraId = params["camera"]?.stringValue
        let format = params["format"]?.stringValue ?? "jpeg"
        _ = params["quality"]?.doubleValue ?? 0.9
        
        // Get available cameras
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        
        let devices = discoverySession.devices
        
        guard !devices.isEmpty else {
            throw CommandError(code: "NO_CAMERA", message: "No camera available")
        }
        
        // Find the requested camera or use default
        let device: AVCaptureDevice
        if let cameraId = cameraId {
            guard let found = devices.first(where: { $0.uniqueID == cameraId }) else {
                throw CommandError(code: "CAMERA_NOT_FOUND", message: "Camera not found: \(cameraId)")
            }
            device = found
        } else {
            device = devices.first!
        }
        
        // Create capture session
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        // Add input
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            throw CommandError(code: "CAMERA_INPUT_ERROR", message: "Failed to create camera input")
        }
        
        guard session.canAddInput(input) else {
            throw CommandError(code: "CAMERA_INPUT_ERROR", message: "Cannot add camera input to session")
        }
        
        session.addInput(input)
        
        // Add output
        let output = AVCapturePhotoOutput()
        
        guard session.canAddOutput(output) else {
            throw CommandError(code: "CAMERA_OUTPUT_ERROR", message: "Cannot add photo output to session")
        }
        
        session.addOutput(output)
        
        // Start session
        session.startRunning()
        
        // Wait a moment for camera to warm up
        try await Task.sleep(for: .milliseconds(500))
        
        // Capture photo using delegate
        let photo = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AVCapturePhoto, Error>) in
            let delegate = PhotoCaptureDelegate(continuation: continuation) { [weak self] in
                Task {
                    await self?.storeActiveDelegate(nil)
                }
            }
            Task {
                await storeActiveDelegate(delegate)
            }
            let settings = AVCapturePhotoSettings()
            output.capturePhoto(with: settings, delegate: delegate)
        }
        
        // Stop session
        session.stopRunning()
        
        // Get image data
        guard let imageData = photo.fileDataRepresentation() else {
            throw CommandError(code: "CAPTURE_FAILED", message: "Failed to get image data")
        }
        
        // Convert to requested format if needed
        let finalData: Data
        let mimeType: String
        
        if format.lowercased() == "png" {
            if let image = NSImage(data: imageData),
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                finalData = pngData
                mimeType = "image/png"
            } else {
                finalData = imageData
                mimeType = "image/jpeg"
            }
        } else {
            finalData = imageData
            mimeType = "image/jpeg"
        }
        
        return AnyCodable([
            "format": format,
            "mimeType": mimeType,
            "camera": device.localizedName,
            "base64": finalData.base64EncodedString()
        ])
    }
    
    // MARK: - List Cameras
    
    private func listCameras() async throws -> AnyCodable {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        
        let cameras = discoverySession.devices.map { device -> [String: Any] in
            [
                "id": device.uniqueID,
                "name": device.localizedName,
                "manufacturer": device.manufacturer,
                "modelID": device.modelID,
                "position": positionString(device.position),
                "isConnected": device.isConnected
            ]
        }
        
        return AnyCodable([
            "cameras": cameras,
            "count": cameras.count
        ])
    }
    
    private func positionString(_ position: AVCaptureDevice.Position) -> String {
        switch position {
        case .front: return "front"
        case .back: return "back"
        case .unspecified: return "unspecified"
        @unknown default: return "unknown"
        }
    }

    private func storeActiveDelegate(_ delegate: PhotoCaptureDelegate?) async {
        activeDelegate = delegate
    }
}

// MARK: - Photo Capture Delegate

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<AVCapturePhoto, Error>?
    private let onFinish: @Sendable () -> Void

    init(continuation: CheckedContinuation<AVCapturePhoto, Error>, onFinish: @escaping @Sendable () -> Void) {
        self.continuation = continuation
        self.onFinish = onFinish
        super.init()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume(returning: photo)
        }
        continuation = nil
        onFinish()
    }
}
