import Foundation
import CoreLocation

/**
 * Zone data model for proximity calculation
 */
public struct Zone {
    let id: String
    let name: String
    let type: ZoneType
    let center: CLLocationCoordinate2D?
    let radius: Double?
    let points: [CLLocationCoordinate2D]
    
    var isCircle: Bool { return type == .circle }
    var isPolygon: Bool { return type == .polygon }
}

public enum ZoneType: String {
    case circle
    case polygon
}
