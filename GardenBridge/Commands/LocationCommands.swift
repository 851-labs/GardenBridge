@preconcurrency import CoreLocation
import Foundation

/// Handles location-related commands using CoreLocation
actor LocationCommands: CommandExecutor {
    private let defaultTimeout = Duration.seconds(10)

    func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
        switch command {
        case "location.get":
            return try await self.getLocation(params: params)
        default:
            throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown location command: \(command)")
        }
    }

    // MARK: - Get Location

    private func getLocation(params: [String: AnyCodable]) async throws -> AnyCodable {
        let accuracy = params["accuracy"]?.stringValue ?? "best"
        let timeout = params["timeout"]?.intValue.map { Duration.seconds($0) } ?? self.defaultTimeout
        let desiredAccuracy = desiredAccuracy(from: accuracy)

        // Create location manager on main thread
        let location = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
            CLLocation,
            Error,
        >) in
            Task { @MainActor in
                let manager = CLLocationManager()
                let wrapper = LocationDelegateWrapper(continuation: continuation)
                manager.delegate = wrapper

                manager.desiredAccuracy = desiredAccuracy

                // Request location
                manager.requestLocation()

                // Set timeout
                Task {
                    try? await Task.sleep(for: timeout)
                    if !wrapper.isCompleted {
                        wrapper.complete(with: CommandError(code: "TIMEOUT", message: "Location request timed out"))
                    }
                }
            }
        }

        let formatter = ISO8601DateFormatter()

        return AnyCodable([
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "altitude": location.altitude,
            "horizontalAccuracy": location.horizontalAccuracy,
            "verticalAccuracy": location.verticalAccuracy,
            "speed": location.speed,
            "course": location.course,
            "timestamp": formatter.string(from: location.timestamp),
        ])
    }

    private func desiredAccuracy(from value: String) -> CLLocationAccuracy {
        switch value {
        case "navigation": kCLLocationAccuracyBestForNavigation
        case "best": kCLLocationAccuracyBest
        case "nearestTenMeters": kCLLocationAccuracyNearestTenMeters
        case "hundredMeters": kCLLocationAccuracyHundredMeters
        case "kilometer": kCLLocationAccuracyKilometer
        case "threeKilometers": kCLLocationAccuracyThreeKilometers
        default: kCLLocationAccuracyBest
        }
    }
}

// MARK: - Location Delegate Wrapper

private class LocationDelegateWrapper: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var _isCompleted = false
    private let lock = NSLock()

    var isCompleted: Bool {
        self.lock.withLock { self._isCompleted }
    }

    init(continuation: CheckedContinuation<CLLocation, Error>) {
        self.continuation = continuation
        super.init()
    }

    func complete(with error: Error) {
        self.lock.withLock {
            guard !self._isCompleted else { return }
            self._isCompleted = true
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.lock.withLock {
            guard !self._isCompleted, let location = locations.last else { return }
            self._isCompleted = true
            self.continuation?.resume(returning: location)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.lock.withLock {
            guard !self._isCompleted else { return }
            self._isCompleted = true
            self.continuation?.resume(throwing: CommandError(
                code: "LOCATION_ERROR",
                message: error.localizedDescription))
            self.continuation = nil
        }
    }
}
