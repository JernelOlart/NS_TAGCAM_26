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
            updateWatermarkPreview()
            refreshMapSnapshot(for: location)
            Task {
                do {
                    guard let request = MKReverseGeocodingRequest(location: location) else { return }
                    let mapItems = try await request.mapItems
                    self.address = mapItems.first?.addressRepresentations?
                        .fullAddress(includingRegion: true, singleLine: true)
                        ?? mapItems.first?.address?.fullAddress
                        ?? self.address
                    self.updateWatermarkPreview()
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
