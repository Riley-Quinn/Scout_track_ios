import CoreLocation

class LocationHelper {
    static let shared = LocationHelper()
    private let geocoder = CLGeocoder()
    private var cache: [String: String] = [:] // Cache for repeated lookups

    func getAddress(latitude: String, longitude: String, completion: @escaping (String) -> Void) {
        let key = "\(latitude),\(longitude)"
        if let cached = cache[key] {
            completion(cached)
            return
        }

        guard let lat = Double(latitude), let lon = Double(longitude) else {
            completion("Invalid coordinates")
            return
        }

        let location = CLLocation(latitude: lat, longitude: lon)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                var address = ""
                if let name = placemark.name { address += name + ", " }
                if let subLocality = placemark.subLocality { address += subLocality + ", " }
                if let city = placemark.locality { address += city + ", " }
                if let state = placemark.administrativeArea { address += state + ", " }
                if let country = placemark.country { address += country }

                let finalAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
                self.cache[key] = finalAddress
                completion(finalAddress)
            } else if let error = error {
                print("Reverse geocode error: \(error.localizedDescription)")
                completion("Address not found")
            } else {
                completion("Address not found")
            }
        }
    }
}
