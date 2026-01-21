import Foundation
import CoreLocation

/// Handles location-related commands using CoreLocation
actor LocationCommands: CommandExecutor {
    private var locationManager: CLLocationManager?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var delegateWrapper: LocationDelegateWrapper?
    
    func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
        switch command {
        case "location.get":
            return try await getLocation(params: params)
        default:
            throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown location command: \(command)")
        }
    }
    
    // MARK: - Get Location
    
    private func getLocation(params: [String: AnyCodable]) async throws -> AnyCodable {
        let accuracy = params["accuracy"]?.stringValue ?? "best"
        let timeout = params["timeout"]?.intValue ?? 10
        
        // Create location manager on main thread
        let location = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
            Task { @MainActor in
                let manager = CLLocationManager()
                let wrapper = LocationDelegateWrapper(continuation: continuation)
                manager.delegate = wrapper
                
                // Set accuracy
                switch accuracy {
                case "navigation":
                    manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
                case "best":
                    manager.desiredAccuracy = kCLLocationAccuracyBest
                case "nearestTenMeters":
                    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                case "hundredMeters":
                    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                case "kilometer":
                    manager.desiredAccuracy = kCLLocationAccuracyKilometer
                case "threeKilometers":
                    manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
                default:
                    manager.desiredAccuracy = kCLLocationAccuracyBest
                }
                
                // Request location
                manager.requestLocation()
                
                // Set timeout
                Task {
                    try? await Task.sleep(for: .seconds(timeout))
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
            "timestamp": formatter.string(from: location.timestamp)
        ])
    }
}

// MARK: - Location Delegate Wrapper

@MainActor
private class LocationDelegateWrapper: NSObject, CLLocationManagerDelegate {
    private var continuation: CheckedContinuation<CLLocation, Error>?
    var isCompleted = false
    
    init(continuation: CheckedContinuation<CLLocation, Error>) {
        self.continuation = continuation
        super.init()
    }
    
    func complete(with error: Error) {
        guard !isCompleted else { return }
        isCompleted = true
        continuation?.resume(throwing: error)
        continuation = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isCompleted, let location = locations.last else { return }
        isCompleted = true
        continuation?.resume(returning: location)
        continuation = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !isCompleted else { return }
        isCompleted = true
        continuation?.resume(throwing: CommandError(code: "LOCATION_ERROR", message: error.localizedDescription))
        continuation = nil
    }
}
