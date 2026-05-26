import CoreLocation
import Combine
import os

@MainActor
final class LocationManager: NSObject, ObservableObject {

    static let shared = LocationManager()

    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?

    private let manager = CLLocationManager()
    private let logger = Logger(subsystem: "com.bingedate", category: "LocationManager")

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    /// Konumu backend'e gönderir (fire-and-forget).
    func syncToBackend() {
        guard let loc = lastLocation else { return }
        Task {
            let req = UpdateUserRequest(
                isim: nil, yas: nil, cinsiyet: nil, hedef_cinsiyet: nil, now_watching: nil,
                konum: KoordinatRequest(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
            )
            _ = try? await APIClient.shared.updateMe(req)
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            let isFirst = lastLocation == nil
            lastLocation = loc
            if isFirst {
                syncToBackend()
                manager.stopUpdatingLocation() // tek seferlik; büyük değişimde tekrar tetiklenir
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authStatus = manager.authorizationStatus
            if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let logger = Logger(subsystem: "com.bingedate", category: "LocationManager")
        logger.warning("Location update failed: \(error.localizedDescription)")
    }
}
