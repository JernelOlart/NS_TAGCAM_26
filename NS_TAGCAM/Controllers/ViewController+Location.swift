import Foundation
import CoreLocation
import MapKit

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
                    if #available(iOS 26.0, *) {
                        guard let request = MKReverseGeocodingRequest(location: location) else { return }
                        let mapItems = try await request.mapItems
                        self.address = mapItems.first?.addressRepresentations?
                            .fullAddress(includingRegion: true, singleLine: true)
                            ?? mapItems.first?.address?.fullAddress
                            ?? self.address
                    } else {
                        let placemarks = try await geocoder.reverseGeocodeLocation(location)
                        let placemark = placemarks.first
                        let addressComponents = [
                            placemark?.thoroughfare,
                            placemark?.locality,
                            placemark?.administrativeArea,
                            placemark?.country
                        ]
                        let formattedAddress = addressComponents
                            .compactMap { $0 }
                            .joined(separator: ", ")
                        if !formattedAddress.isEmpty {
                            self.address = formattedAddress
                        }
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
