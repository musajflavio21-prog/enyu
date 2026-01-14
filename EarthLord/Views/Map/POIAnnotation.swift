//
//  POIAnnotation.swift
//  EarthLord
//
//  POI 地图标记
//  用于在 MKMapView 上显示 POI 位置
//

import MapKit

/// POI 地图标记（用于 MKMapView）
class POIAnnotation: NSObject, MKAnnotation {
    let poi: RealPOI

    var coordinate: CLLocationCoordinate2D {
        return poi.coordinate
    }

    var title: String? {
        return poi.name
    }

    var subtitle: String? {
        return poi.type.displayName
    }

    init(poi: RealPOI) {
        self.poi = poi
        super.init()
    }
}
