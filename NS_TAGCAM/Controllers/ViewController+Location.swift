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
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
                if let placemark = placemarks?.first {
                    self?.address = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea, placemark.country]
                        .compactMap { $0 }
                        .joined(separator: ", ")
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
}
