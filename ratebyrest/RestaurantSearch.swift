import CoreLocation
import Foundation
import MapKit

enum RestaurantSearch {
    static func search(city: City, countryName: String) async throws -> [RestaurantPlace] {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude),
            latitudinalMeters: 22_000,
            longitudinalMeters: 22_000
        )
        var items = try await mapItems(query: "restaurant", region: region, restaurantsOnly: true)
        if items.isEmpty {
            items = try await mapItems(query: "restaurant", region: region, restaurantsOnly: false)
        }
        var seen = Set<String>()
        var places: [RestaurantPlace] = []
        for item in items {
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { continue }
            let coordinate = item.location.coordinate
            let key = RestaurantPlace.makeKey(
                name: name,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            guard seen.insert(key).inserted else { continue }
            let address = item.address?.shortAddress
                ?? item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
                ?? city.name
            places.append(
                RestaurantPlace(
                    placeKey: key,
                    name: name,
                    address: address,
                    city: city.name,
                    countryCode: city.countryCode,
                    countryName: countryName,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
        }
        return places.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func mapItems(
        query: String,
        region: MKCoordinateRegion,
        restaurantsOnly: Bool
    ) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest
        if restaurantsOnly {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant])
        }
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems
    }
}
