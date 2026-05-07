import Combine
import CoreLocation
import Foundation

final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var temperature: Double? = nil
    @Published var symbolName: String = "cloud"
    @Published var conditionText: String = ""

    private let locationManager = CLLocationManager()
    private var lastFetch: Date = .distantPast
    private let cacheTTL: TimeInterval = 1800 // 30 min

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestAndFetch() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            break
        default:
            if Date().timeIntervalSince(lastFetch) > cacheTTL {
                locationManager.requestLocation()
            }
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined, status != .denied, status != .restricted else { return }
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        lastFetch = Date()
        Task { await fetch(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    // MARK: Fetch

    @MainActor
    private func fetch(lat: Double, lon: Double) async {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code"
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return }

        struct Response: Codable {
            struct Current: Codable {
                let temperature2m: Double
                let weatherCode: Int
                enum CodingKeys: String, CodingKey {
                    case temperature2m = "temperature_2m"
                    case weatherCode = "weather_code"
                }
            }
            let current: Current
        }

        guard let resp = try? JSONDecoder().decode(Response.self, from: data) else { return }
        temperature = resp.current.temperature2m
        (symbolName, conditionText) = info(for: resp.current.weatherCode)
    }

    private func info(for code: Int) -> (String, String) {
        switch code {
        case 0, 1:    return ("sun.max.fill", "晴")
        case 2:       return ("cloud.sun.fill", "多云")
        case 3:       return ("cloud.fill", "阴")
        case 45, 48:  return ("cloud.fog.fill", "雾")
        case 51...67: return ("cloud.drizzle.fill", "雨")
        case 71...77: return ("cloud.snow.fill", "雪")
        case 80...82: return ("cloud.rain.fill", "阵雨")
        case 85, 86:  return ("cloud.snow.fill", "阵雪")
        case 95...99: return ("cloud.bolt.rain.fill", "雷雨")
        default:      return ("cloud", "")
        }
    }
}
