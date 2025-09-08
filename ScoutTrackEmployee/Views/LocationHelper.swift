import CoreLocation

class LocationHelper {
    static func getAddressFromCoordinates(latitude: Double, longitude: Double, completion: @escaping (String) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)

        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            if let placemark = placemarks?.first {
                let addressParts = [
                    placemark.name,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.country,
                ].compactMap { $0 }
                completion(addressParts.joined(separator: ", "))
            } else {
                completion("Unknown Address")
            }
        }
    }
}
