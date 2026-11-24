import CoreLocation
import MapKit
import SwiftUI

struct RouteView: View {
    let place: RestaurantPlace

    @State private var location = LocationHelper()
    @State private var mode: TravelMode = .automobile
    @State private var camera: MapCameraPosition = .automatic
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var distanceText = ""
    @State private var timeText = ""
    @State private var isCalculating = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $camera) {
                Marker(place.name, coordinate: place.coordinate)
                    .tint(Theme.accent)
                UserAnnotation()
                if routeCoordinates.count > 1 {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(Theme.accent, lineWidth: 5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Picker("Közlekedés", selection: $mode) {
                    ForEach(TravelMode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if isCalculating {
                    ProgressView("Útvonal számítása…")
                } else if !distanceText.isEmpty {
                    Text("\(distanceText) · \(timeText)")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                }

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }

                Button {
                    openInMaps()
                } label: {
                    Label("Megnyitás a Térképben", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .padding()
            .background(Theme.background)
        }
        .navigationTitle("Útvonal")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background)
        .task { location.request() }
        .onChange(of: location.latitude) { _, _ in Task { await calculate() } }
        .onChange(of: mode) { _, _ in Task { await calculate() } }
    }

    private func calculate() async {
        guard let latitude = location.latitude, let longitude = location.longitude else {
            message = location.denied
                ? "A helyzet ki van kapcsolva. Az útvonalat a Térkép appban tudod megnyitni."
                : "A helyzetre várunk az útvonalhoz."
            return
        }
        isCalculating = true
        message = nil
        defer { isCalculating = false }
        let source = MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: nil)
        let destination = MKMapItem(
            location: CLLocation(latitude: place.latitude, longitude: place.longitude),
            address: nil
        )
        destination.name = place.name
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = mode.transport
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                message = "Nincs útvonal a két pont között."
                return
            }
            routeCoordinates = coordinates(of: route.polyline)
            distanceText = (route.distance / 1000).formatted(
                .number.precision(.fractionLength(1)).locale(Locale(identifier: "hu_HU"))
            ) + " km"
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = route.expectedTravelTime >= 3600 ? [.hour, .minute] : [.minute]
            formatter.unitsStyle = .short
            formatter.calendar?.locale = Locale(identifier: "hu_HU")
            timeText = formatter.string(from: route.expectedTravelTime) ?? ""
            var rect = route.polyline.boundingMapRect
            let padX = max(rect.size.width * 0.35, 800)
            let padY = max(rect.size.height * 0.35, 800)
            rect = rect.insetBy(dx: -padX, dy: -padY)
            camera = .rect(rect)
        } catch {
            routeCoordinates = []
            distanceText = ""
            timeText = ""
            message = "Az útvonalat nem sikerült kiszámolni. Nyisd meg a Térképben."
        }
    }

    private func coordinates(of polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coordinates = Array(repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
        return coordinates
    }

    private func openInMaps() {
        let destination = MKMapItem(
            location: CLLocation(latitude: place.latitude, longitude: place.longitude),
            address: nil
        )
        destination.name = place.name
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: mode.launchOption
        ])
    }
}

private extension RestaurantPlace {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private enum TravelMode: String, CaseIterable, Identifiable {
    case automobile
    case walking

    var id: String { rawValue }
    var title: String { self == .automobile ? "Autó" : "Gyalog" }
    var transport: MKDirectionsTransportType { self == .automobile ? .automobile : .walking }
    var launchOption: String {
        self == .automobile ? MKLaunchOptionsDirectionsModeDriving : MKLaunchOptionsDirectionsModeWalking
    }
}
