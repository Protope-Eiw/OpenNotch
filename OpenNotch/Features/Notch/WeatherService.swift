import Combine
import Foundation

final class WeatherService: ObservableObject {
    @Published var temperature: Double? = nil
    @Published var symbolName: String = "cloud"
    @Published var conditionText: String = ""
    @Published var fetchFailed: Bool = false

    private var lastFetch: Date = .distantPast
    private var lastLat: Double?
    private var lastLon: Double?
    private let cacheTTL: TimeInterval = 1800
    private let coordinateThreshold: Double = 0.5
    private var refreshTimer: Timer?

    init() {
        temperature = UserDefaults.standard.object(forKey: AppStorageKeys.Overview.weatherTemperature) as? Double
        symbolName = UserDefaults.standard.string(forKey: AppStorageKeys.Overview.weatherSymbolName) ?? "cloud"
        conditionText = UserDefaults.standard.string(forKey: AppStorageKeys.Overview.weatherConditionText) ?? ""
        lastFetch = UserDefaults.standard.object(forKey: AppStorageKeys.Overview.weatherLastFetch) as? Date ?? .distantPast
        lastLat = UserDefaults.standard.object(forKey: AppStorageKeys.Overview.weatherLastLat) as? Double
        lastLon = UserDefaults.standard.object(forKey: AppStorageKeys.Overview.weatherLastLon) as? Double
    }

    func requestAndFetch() {
        fetchFailed = false
        Task { await fetch() }
    }

    @MainActor
    private func fetch() async {
        guard let location = await resolveLocation() else {
            fetchFailed = true
            return
        }

        if let lastLat, let lastLon,
           abs(lastLat - location.lat) < coordinateThreshold,
           abs(lastLon - location.lon) < coordinateThreshold,
           Date().timeIntervalSince(lastFetch) < cacheTTL {
            return
        }

        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(location.lat)&longitude=\(location.lon)&current=temperature_2m,weather_code"
        guard let url = URL(string: urlStr) else { fetchFailed = true; return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Response: Decodable {
                struct Current: Decodable {
                    let temperature2m: Double
                    let weatherCode: Int
                    enum CodingKeys: String, CodingKey {
                        case temperature2m = "temperature_2m"
                        case weatherCode = "weather_code"
                    }
                }
                let current: Current
            }

            guard let resp = try? JSONDecoder().decode(Response.self, from: data) else {
                fetchFailed = true
                return
            }

            lastFetch = Date()
            lastLat = location.lat
            lastLon = location.lon
            fetchFailed = false
            temperature = resp.current.temperature2m
            (symbolName, conditionText) = info(for: resp.current.weatherCode)
            persist()
            scheduleNextRefresh()
        } catch {
            fetchFailed = true
        }
    }

    private func resolveLocation() async -> (lat: Double, lon: Double)? {
        guard let url = URL(string: "http://ip-api.com/json/") else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct IPLocation: Decodable {
                let lat: Double
                let lon: Double
            }
            let location = try JSONDecoder().decode(IPLocation.self, from: data)
            return (location.lat, location.lon)
        } catch {
            return nil
        }
    }

    private func persist() {
        UserDefaults.standard.set(temperature, forKey: AppStorageKeys.Overview.weatherTemperature)
        UserDefaults.standard.set(symbolName, forKey: AppStorageKeys.Overview.weatherSymbolName)
        UserDefaults.standard.set(conditionText, forKey: AppStorageKeys.Overview.weatherConditionText)
        UserDefaults.standard.set(lastFetch, forKey: AppStorageKeys.Overview.weatherLastFetch)
        UserDefaults.standard.set(lastLat, forKey: AppStorageKeys.Overview.weatherLastLat)
        UserDefaults.standard.set(lastLon, forKey: AppStorageKeys.Overview.weatherLastLon)
    }

    private func scheduleNextRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: cacheTTL, repeats: false) { [weak self] _ in
            self?.requestAndFetch()
        }
    }

    private func info(for code: Int) -> (String, String) {
        switch code {
        case 0, 1:    return ("sun.max.fill", L10n.app("weather.clear", fallback: "Clear"))
        case 2:       return ("cloud.sun.fill", L10n.app("weather.partlyCloudy", fallback: "Partly Cloudy"))
        case 3:       return ("cloud.fill", L10n.app("weather.overcast", fallback: "Overcast"))
        case 45, 48:  return ("cloud.fog.fill", L10n.app("weather.foggy", fallback: "Foggy"))
        case 51...67: return ("cloud.drizzle.fill", L10n.app("weather.rainy", fallback: "Rainy"))
        case 71...77: return ("cloud.snow.fill", L10n.app("weather.snowy", fallback: "Snowy"))
        case 80...82: return ("cloud.rain.fill", L10n.app("weather.showers", fallback: "Showers"))
        case 85, 86:  return ("cloud.snow.fill", L10n.app("weather.snowShowers", fallback: "Snow Showers"))
        case 95...99: return ("cloud.bolt.rain.fill", L10n.app("weather.thunderstorm", fallback: "Thunderstorm"))
        default:      return ("cloud", "")
        }
    }
}
