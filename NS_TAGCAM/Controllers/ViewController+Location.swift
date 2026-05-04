import Foundation
import CoreLocation

extension ViewController: CLLocationManagerDelegate {
    func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        if let location = currentLocation {
            Task {
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    if let placemark = placemarks.first {
                        self.address = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea, placemark.country]
                            .compactMap { $0 }
                            .joined(separator: ", ")
                    }
                } catch {
                    print("Geocoding error: \(error)")
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
}
