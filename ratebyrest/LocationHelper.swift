import CoreLocation
import Observation

@Observable
final class LocationHelper: NSObject, CLLocationManagerDelegate {
    var latitude: Double?
    var longitude: Double?
    var denied = false

    private let manager = CLLocationManager()

    func request() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        Task { @MainActor in
            self.latitude = latitude
            self.longitude = longitude
            self.denied = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let denied = status == .denied || status == .restricted
        #if os(macOS)
        let allowed = status == .authorized || status == .authorizedAlways
        #else
        let allowed = status == .authorizedWhenInUse || status == .authorizedAlways
        #endif
        Task { @MainActor in
            self.denied = denied
            if allowed {
                self.manager.requestLocation()
            }
        }
    }
}
