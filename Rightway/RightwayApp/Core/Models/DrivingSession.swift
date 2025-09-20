import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(MapKit)
import MapKit
#endif

struct DrivingSession: Identifiable, Codable, Hashable {
    struct RouteSample: Codable, Hashable {
        let timestamp: Date
        let latitude: Double
        let longitude: Double
    }

    struct AudioTrack: Codable, Hashable {
        let isEnabled: Bool
        var fileURL: URL?
        var startTimestamp: Date?
    }

    let id: UUID
    let sequenceNumber: Int
    let startedAt: Date
    var endedAt: Date?
    var amountPaid: Decimal?
    var noteID: UUID?
    var routeSamples: [RouteSample]
    var audio: AudioTrack
    var routeTrackingEnabled: Bool
    var audioWaypoints: [AudioWaypoint]

    init(id: UUID = UUID(),
         sequenceNumber: Int,
         startedAt: Date = .init(),
         endedAt: Date? = nil,
         amountPaid: Decimal? = nil,
         noteID: UUID? = nil,
         routeSamples: [RouteSample] = [],
         audio: AudioTrack = .init(isEnabled: false, fileURL: nil, startTimestamp: nil),
         routeTrackingEnabled: Bool = true,
         audioWaypoints: [AudioWaypoint] = []) {
        self.id = id
        self.sequenceNumber = sequenceNumber
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.amountPaid = amountPaid
        self.noteID = noteID
        self.routeSamples = routeSamples
        self.audio = audio
        self.routeTrackingEnabled = routeTrackingEnabled
        self.audioWaypoints = audioWaypoints
    }

    var duration: TimeInterval {
        guard let end = endedAt else { return Date().timeIntervalSince(startedAt) }
        return end.timeIntervalSince(startedAt)
    }

    var isActive: Bool { endedAt == nil }

    var totalDistanceMeters: Double {
#if canImport(CoreLocation)
        guard routeSamples.count > 1 else { return 0 }
        var distance: CLLocationDistance = 0
        for index in 1..<routeSamples.count {
            let previous = routeSamples[index - 1]
            let current = routeSamples[index]
            let startLocation = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
            let endLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            distance += endLocation.distance(from: startLocation)
        }
        return distance
#else
        return 0
#endif
    }

    struct AudioWaypoint: Identifiable, Codable, Hashable {
        let id: UUID
        let timestamp: Date
        let timeOffset: TimeInterval
        let latitude: Double
        let longitude: Double

        init(id: UUID = UUID(), timestamp: Date, timeOffset: TimeInterval, latitude: Double, longitude: Double) {
            self.id = id
            self.timestamp = timestamp
            self.timeOffset = timeOffset
            self.latitude = latitude
            self.longitude = longitude
        }

#if canImport(MapKit)
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
#endif
    }
}
