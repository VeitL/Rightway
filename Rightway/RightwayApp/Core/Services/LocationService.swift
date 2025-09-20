import Combine
import Foundation

enum LocationAuthorizationStatus {
    case notDetermined
    case restricted
    case denied
    case authorized
}

protocol LocationService {
    var isAvailable: Bool { get }
    var authorizationStatus: LocationAuthorizationStatus { get }
    var routeSamplePublisher: AnyPublisher<DrivingSession.RouteSample, Never> { get }
    func requestAuthorization() async -> Bool
    func startTracking()
    func stopTracking()
}

#if canImport(CoreLocation) && !os(macOS)
import CoreLocation

final class CoreLocationService: NSObject, LocationService {
    private let manager = CLLocationManager()
    private let subject = PassthroughSubject<DrivingSession.RouteSample, Never>()
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    private var lastDispatchedLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
#if os(iOS)
        manager.activityType = .automotiveNavigation
#endif
    }

    var isAvailable: Bool { CLLocationManager.locationServicesEnabled() }

    var authorizationStatus: LocationAuthorizationStatus {
        switch manager.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorizedAlways, .authorizedWhenInUse: return .authorized
        @unknown default: return .restricted
        }
    }

    var routeSamplePublisher: AnyPublisher<DrivingSession.RouteSample, Never> {
        subject.eraseToAnyPublisher()
    }

    func requestAuthorization() async -> Bool {
        switch authorizationStatus {
        case .authorized: return true
        case .restricted, .denied: return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    func startTracking() {
        guard authorizationStatus == .authorized else { return }
#if os(iOS)
        manager.allowsBackgroundLocationUpdates = false
        manager.requestLocation()
#endif
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        lastDispatchedLocation = nil
    }
}

extension CoreLocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if let continuation = authorizationContinuation {
            authorizationContinuation = nil
            continuation.resume(returning: authorizationStatus == .authorized)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        guard location.horizontalAccuracy >= 0 else { return }
        if let last = lastDispatchedLocation,
           location.timestamp.timeIntervalSince(last.timestamp) < 2,
           location.distance(from: last) < 3 {
            return
        }
        lastDispatchedLocation = location
        let sample = DrivingSession.RouteSample(timestamp: Date(),
                                                latitude: location.coordinate.latitude,
                                                longitude: location.coordinate.longitude)
        subject.send(sample)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("Location update failed: \(error.localizedDescription)")
    }
}
#else
final class StubLocationService: LocationService {
    var isAvailable: Bool { false }
    var authorizationStatus: LocationAuthorizationStatus { .restricted }
    var routeSamplePublisher: AnyPublisher<DrivingSession.RouteSample, Never> {
        Empty().eraseToAnyPublisher()
    }
    func requestAuthorization() async -> Bool { false }
    func startTracking() {}
    func stopTracking() {}
}
#endif
