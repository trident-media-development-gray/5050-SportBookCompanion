import SwiftUI
import Foundation

// =====================================================================================
//  Weather — the app's only network feature. Open-Meteo, no API key, no account,
//  no location services (the user picks a city by hand). Two endpoints: geocode + now.
// =====================================================================================

// ---- models -------------------------------------------------------------------------
struct WxNow {
    var tempF: Double
    var feelsF: Double
    var windMph: Double
    var precip: Double      // mm in the current hour
    var code: Int           // WMO weather code
}

struct WxCity: Identifiable, Hashable {
    var id: String { "\(lat),\(lon)" }
    var name: String
    var region: String      // admin1 (state/province) — may be empty
    var country: String
    var lat: Double
    var lon: Double
    var pretty: String { region.isEmpty ? "\(name), \(country)" : "\(name), \(region)" }
}

enum WxError: Error { case badURL, http }

// ---- service: tiny async wrappers around the two JSON endpoints ---------------------
enum Wx {
    // search cities by name (Open-Meteo geocoding)
    static func search(_ q: String) async throws -> [WxCity] {
        let term = q.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty,
              let enc = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(enc)&count=12&language=en&format=json")
        else { throw WxError.badURL }

        let data = try await Net.get(url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = root["results"] as? [[String: Any]] else { return [] }
        return arr.compactMap { r in
            guard let name = r["name"] as? String,
                  let lat = r["latitude"] as? Double,
                  let lon = r["longitude"] as? Double else { return nil }
            return WxCity(name: name,
                          region: (r["admin1"] as? String) ?? "",
                          country: (r["country"] as? String) ?? "",
                          lat: lat, lon: lon)
        }
    }

    // current conditions for a coordinate
    static func current(lat: Double, lon: Double) async throws -> WxNow {
        guard let url = URL(string:
            "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)" +
            "&current=temperature_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m" +
            "&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=mm&timezone=auto")
        else { throw WxError.badURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cur = root["current"] as? [String: Any] else { throw WxError.http }
        return WxNow(
            tempF: (cur["temperature_2m"] as? Double) ?? 0,
            feelsF: (cur["apparent_temperature"] as? Double) ?? 0,
            windMph: (cur["wind_speed_10m"] as? Double) ?? 0,
            precip: (cur["precipitation"] as? Double) ?? 0,
            code: (cur["weather_code"] as? Int) ?? 0)
    }

    // ---- WMO code -> human label + SF Symbol ----------------------------------------
    static func face(_ code: Int) -> (icon: String, word: String) {
        switch code {
        case 0:        return ("sun.max.fill", "Clear")
        case 1, 2:     return ("cloud.sun.fill", "Partly cloudy")
        case 3:        return ("cloud.fill", "Overcast")
        case 45, 48:   return ("cloud.fog.fill", "Fog")
        case 51...57:  return ("cloud.drizzle.fill", "Drizzle")
        case 61...67:  return ("cloud.rain.fill", "Rain")
        case 71...77:  return ("cloud.snow.fill", "Snow")
        case 80...82:  return ("cloud.heavyrain.fill", "Showers")
        case 85, 86:   return ("cloud.snow.fill", "Snow showers")
        case 95...99:  return ("cloud.bolt.rain.fill", "Storms")
        default:       return ("cloud.fill", "Cloudy")
        }
    }

    // ---- the actual value-add: should you be on the field today? ---------------------
    static func verdict(_ w: WxNow) -> (text: String, good: Bool) {
        if w.code >= 95 { return ("Lightning risk — train indoors", false) }
        if w.code >= 71 && w.code <= 86 { return ("Snow out there — bring it inside", false) }
        if w.precip >= 1.0 || (w.code >= 61 && w.code <= 67) { return ("Wet field — indoor day", false) }
        if w.windMph >= 25 { return ("Heavy wind — tough for ball work", false) }
        if w.feelsF >= 95 { return ("Hot — hydrate, shorten reps", false) }
        if w.feelsF <= 25 { return ("Frigid — long warm-up first", false) }
        return ("Great day for field work", true)
    }
}

// =====================================================================================
//  ConditionsCard — Home card. Loads on appear / when the saved city changes.
// =====================================================================================
struct ConditionsCard: View {
    @EnvironmentObject var b: Brain
    @State private var wx: WxNow? = nil
    @State private var loading = false
    @State private var failed = false
    @State private var pickOpen = false

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Training Conditions").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Button { pickOpen = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill").font(.system(size: 12, weight: .bold))
                            Text(b.hasCity ? b.cityName : "Set city").font(.system(size: 12, weight: .semibold))
                        }.foregroundColor(P.orange)
                    }
                }

                if !b.hasCity {
                    Button { pickOpen = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "location.magnifyingglass").font(.system(size: 16, weight: .bold))
                            Text("Pick your city to see field conditions").font(.system(size: 13, weight: .semibold))
                        }.foregroundColor(P.ash)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(P.panel2))
                    }
                } else if let w = wx {
                    let f = Wx.face(w.code)
                    let v = Wx.verdict(w)
                    HStack(spacing: 14) {
                        Image(systemName: f.icon).font(.system(size: 38))
                            .foregroundStyle(LinearGradient(colors: [P.gold, P.orange2], startPoint: .top, endPoint: .bottom))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(w.tempF))°").font(.system(size: 30, weight: .black)).foregroundColor(.white)
                            Text(f.word).font(.system(size: 12, weight: .semibold)).foregroundColor(P.ash)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            condChip("thermometer.medium", "Feels \(Int(w.feelsF))°")
                            condChip("wind", "\(Int(w.windMph)) mph")
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: v.good ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(v.text).font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(v.good ? P.ok : P.gold)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill((v.good ? P.ok : P.gold).opacity(0.12)))
                } else if loading {
                    HStack { ProgressView().tint(P.orange); Text("Checking the skies…").font(.system(size: 13)).foregroundColor(P.ash) }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                } else if failed {
                    Button { Task { await load() } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise"); Text("Couldn't load weather — tap to retry")
                        }.font(.system(size: 13, weight: .semibold)).foregroundColor(P.ash)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                }
            }
        }
        .task(id: cityKey) { await load() }
        .sheet(isPresented: $pickOpen) { CityPicker() }
    }

    private var cityKey: String { "\(b.cityLat),\(b.cityLon)" }

    private func condChip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 12, weight: .semibold))
        }.foregroundColor(P.ash)
    }

    private func load() async {
        guard b.hasCity else { return }
        loading = true; failed = false
        do { wx = try await Wx.current(lat: b.cityLat, lon: b.cityLon) }
        catch { failed = true }
        loading = false
    }
}

// =====================================================================================
//  CityPicker — search Open-Meteo geocoding, tap to save into the brain.
// =====================================================================================
struct CityPicker: View {
    @EnvironmentObject var b: Brain
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [WxCity] = []
    @State private var searching = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBG()
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(P.ash)
                        TextField("", text: $query, prompt: Text("Search a city").foregroundColor(P.ashDim))
                            .foregroundColor(.white).autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit { Task { await run() } }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(P.panel2))
                    .padding(.horizontal, 16).padding(.top, 12)

                    if searching { ProgressView().tint(P.orange).padding(.top, 20) }

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(results) { c in
                                Button {
                                    b.setCity(c.name, c.lat, c.lon); Haptics.tap(); dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(c.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                            Text(c.pretty).font(.system(size: 12)).foregroundColor(P.ash)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(P.ashDim)
                                    }
                                    .padding(14)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(P.panel).overlay(RoundedRectangle(cornerRadius: 14).stroke(P.stroke, lineWidth: 1)))
                                }
                            }
                        }.padding(.horizontal, 16)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Choose City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(P.ash)
                }
            }
        }
        .tint(P.orange)
    }

    private func run() async {
        searching = true
        results = (try? await Wx.search(query)) ?? []
        searching = false
    }
}
