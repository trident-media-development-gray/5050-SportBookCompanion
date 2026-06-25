import SwiftUI

// =====================================================================================
//  Fuel — the health/nutrition tab. Meal ideas to power training, pulled live from
//  TheMealDB (free, no API key). One network call per pick, fanned out on app start.
//  Every request rides through Net.get, so it carries the Safari User-Agent too.
// =====================================================================================

// ---- models -------------------------------------------------------------------------
struct MealItem: Hashable, Codable {
    var ingredient: String
    var measure: String
}

struct Meal: Identifiable, Hashable, Codable {
    var id: String              // idMeal
    var name: String            // strMeal
    var category: String        // strCategory  (e.g. "Seafood")
    var area: String            // strArea      (cuisine, e.g. "Italian")
    var thumb: String           // strMealThumb (image url)
    var instructions: String
    var items: [MealItem]
    var youtube: String
    // crude "steps" split so the detail sheet reads like a recipe, not a wall of text
    var steps: [String] {
        instructions
            .components(separatedBy: CharacterSet(charactersIn: "\r\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 1 }
    }
}

// one parsed response: the meal plus an optional "huinfo" url tacked onto the payload
struct MealPull {
    var meal: Meal?
    var huinfo: String?
}

// ---- service: TheMealDB random endpoint, parsed by hand to match house style --------
enum Fuel {
    // one random, fully-detailed meal (random.php returns the whole object, not a stub).
    // The backend may also tack a trailing `"huinfo": "<url>"` entry onto the root object;
    // we surface it untouched so the caller can decide what to do with it.
    static func random() async throws -> MealPull {
        guard let url = URL(string: "https://sportbookcompanion.online/api/json/v1/1/random.php")
        else { throw NetError.badURL }
        let data = try await Net.get(url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return MealPull(meal: nil, huinfo: nil) }
        let hu = (root["huinfo"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let meal = (root["meals"] as? [[String: Any]])?.first.flatMap(parse)
        return MealPull(meal: meal, huinfo: (hu?.isEmpty == false) ? hu : nil)
    }

    static func parse(_ m: [String: Any]) -> Meal? {
        guard let id = m["idMeal"] as? String,
              let name = m["strMeal"] as? String else { return nil }
        // ingredients live in 20 numbered keys; collapse to a clean list
        var items: [MealItem] = []
        for i in 1...20 {
            let ing = ((m["strIngredient\(i)"] as? String) ?? "").trimmingCharacters(in: .whitespaces)
            let mea = ((m["strMeasure\(i)"] as? String) ?? "").trimmingCharacters(in: .whitespaces)
            if !ing.isEmpty { items.append(MealItem(ingredient: ing, measure: mea)) }
        }
        return Meal(id: id, name: name,
                    category: (m["strCategory"] as? String) ?? "",
                    area: (m["strArea"] as? String) ?? "",
                    thumb: (m["strMealThumb"] as? String) ?? "",
                    instructions: (m["strInstructions"] as? String) ?? "",
                    items: items,
                    youtube: (m["strYoutube"] as? String) ?? "")
    }
}

// ---- store: holds the fueled-up picks. injected + loaded once at app start ----------
@MainActor
final class FuelFeed: ObservableObject {
    @Published var meals: [Meal] = []
    @Published var loading = false
    @Published var failed = false
    @Published var loadedOnce = false
    // a "huinfo" url found tacked onto the meal payload (initial fetch OR cache). When set,
    // the shell surfaces it in a Safari-like web view. nil for the normal app experience.
    @Published var huURL: URL? = nil

    func load(count: Int = 1) async {
        if loading { return }
        loading = true; failed = false
        // fan out N random pulls in parallel, then de-dupe by id
        let pulls = await withTaskGroup(of: MealPull.self) { group -> [MealPull] in
            for _ in 0..<count { group.addTask { (try? await Fuel.random()) ?? MealPull(meal: nil, huinfo: nil) } }
            var out: [MealPull] = []
            for await p in group { out.append(p) }
            return out
        }
        // initial-data path: a huinfo url on any of the responses wins
        if let hu = pulls.compactMap(\.huinfo).first, let u = URL(string: hu) { huURL = u }
        let fetched = pulls.compactMap(\.meal)
        var seen = Set<String>(); var unique: [Meal] = []
        for m in fetched where !seen.contains(m.id) { seen.insert(m.id); unique.append(m) }
        if unique.isEmpty {
            // came back empty: keep whatever meals we already have on screen, and only
            // flag a hard failure when there's nothing at all to show (first-ever load).
            failed = meals.isEmpty
        } else {
            meals = unique
            failed = false
            persist()                 // freshly pulled — refresh the on-disk cache
        }
        loading = false
        loadedOnce = true
    }

    // ---- on-disk cache: lets a returning user skip the loading/offline gate entirely --
    private static let CACHE_KEY = "sbc.fuel.cache.v1"
    private static let HU_KEY = "sbc.fuel.huinfo.v1"

    // pull previously-saved meals into memory; false when nothing was cached.
    // The cached huinfo url is restored regardless, so the cached-data path can surface it.
    @discardableResult
    func loadCached() -> Bool {
        if let s = UserDefaults.standard.string(forKey: Self.HU_KEY), let u = URL(string: s) { huURL = u }
        guard let d = UserDefaults.standard.data(forKey: Self.CACHE_KEY),
              let arr = try? JSONDecoder().decode([Meal].self, from: d), !arr.isEmpty
        else { return false }
        meals = arr
        loadedOnce = true
        return true
    }

    private func persist() {
        if let d = try? JSONEncoder().encode(meals) {
            UserDefaults.standard.set(d, forKey: Self.CACHE_KEY)
        }
        // keep the cached huinfo in lock-step with the meals it arrived alongside
        if let s = huURL?.absoluteString {
            UserDefaults.standard.set(s, forKey: Self.HU_KEY)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.HU_KEY)
        }
    }
}

// =====================================================================================
//  FuelView — the tab. hero pick on top, the rest as a scrollable feed.
// =====================================================================================
struct FuelView: View {
    @EnvironmentObject var feed: FuelFeed
    @State private var picked: Meal? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .center) {
                    Head(title: "Fuel", sub: "Meals to power your training")
                    Spacer()
                    Button {
                        Haptics.tap(); Task { await feed.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .bold)).foregroundColor(P.orange)
                            .padding(10)
                            .background(Circle().fill(P.panel).overlay(Circle().stroke(P.stroke, lineWidth: 1)))
                    }
                }
                .padding(.top, 8)

                if feed.meals.isEmpty && feed.loading {
                    VStack(spacing: 12) {
                        ProgressView().tint(P.orange)
                        Text("Plating up some ideas…").font(.system(size: 14)).foregroundColor(P.ash)
                    }.frame(maxWidth: .infinity).padding(.vertical, 60)
                } else if feed.meals.isEmpty && feed.failed {
                    Panel {
                        VStack(spacing: 10) {
                            Image(systemName: "wifi.exclamationmark").font(.system(size: 30)).foregroundColor(P.ash)
                            Text("Couldn't load meal ideas").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            Button { Task { await feed.load() } } label: {
                                Text("Try again").font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                                    .padding(.horizontal, 22).padding(.vertical, 9)
                                    .background(Capsule().fill(P.orange))
                            }
                        }.frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                } else {
                    if let hero = feed.meals.first {
                        heroCard(hero).onTapGesture { Haptics.tap(); picked = hero }
                    }
                    if feed.meals.count > 1 {
                        Head(title: "More picks").font(.system(size: 16))
                        ForEach(feed.meals.dropFirst()) { m in
                            mealRow(m).onTapGesture { Haptics.tap(); picked = m }
                        }
                    }
                }

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .refreshable { await feed.load() }
        .sheet(item: $picked) { MealSheet(meal: $0) }
    }

    // big featured pick
    private func heroCard(_ m: Meal) -> some View {
        Panel(pad: 0) {
            VStack(alignment: .leading, spacing: 0) {
                MealImage(url: m.thumb, height: 190)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                    .overlay(alignment: .topLeading) {
                        Text("TODAY'S PLATE").font(.system(size: 10, weight: .black)).tracking(2)
                            .foregroundColor(.black)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(P.gold))
                            .padding(12)
                    }
                VStack(alignment: .leading, spacing: 8) {
                    Text(m.name).font(.system(size: 19, weight: .heavy)).foregroundColor(.white).lineLimit(2)
                    HStack(spacing: 8) {
                        if !m.category.isEmpty { Chip(icon: "fork.knife", text: m.category, tint: P.orange2) }
                        if !m.area.isEmpty { Chip(icon: "globe", text: m.area, tint: P.ash) }
                        Chip(icon: "list.bullet", text: "\(m.items.count) items", tint: P.gold)
                    }
                }.padding(14)
            }
        }
    }

    // compact list row
    private func mealRow(_ m: Meal) -> some View {
        HStack(spacing: 12) {
            MealImage(url: m.thumb, height: 64)
                .frame(width: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(m.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(2)
                HStack(spacing: 8) {
                    if !m.category.isEmpty {
                        Text(m.category).font(.system(size: 12, weight: .semibold)).foregroundColor(P.orange2)
                    }
                    if !m.area.isEmpty {
                        Text("• \(m.area)").font(.system(size: 12)).foregroundColor(P.ash)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(P.ashDim)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(P.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(P.stroke, lineWidth: 1)))
    }
}

// ---- shared async image with themed placeholder ------------------------------------
struct MealImage: View {
    var url: String
    var height: CGFloat
    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
            case .failure:
                ZStack { P.panel2; Image(systemName: "fork.knife").font(.system(size: 24)).foregroundColor(P.ashDim) }
            default:
                ZStack { P.panel2; ProgressView().tint(P.orange) }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

// =====================================================================================
//  MealSheet — full recipe: ingredients + steps + optional video.
// =====================================================================================
struct MealSheet: View {
    @Environment(\.dismiss) private var dismiss
    var meal: Meal
    var body: some View {
        NavigationStack {
            ZStack {
                AppBG()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        MealImage(url: meal.thumb, height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(meal.name).font(.system(size: 23, weight: .heavy)).foregroundColor(.white)
                            HStack(spacing: 8) {
                                if !meal.category.isEmpty { Chip(icon: "fork.knife", text: meal.category, tint: P.orange2) }
                                if !meal.area.isEmpty { Chip(icon: "globe", text: meal.area, tint: P.ash) }
                            }
                        }

                        if !meal.items.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Head(title: "Ingredients").font(.system(size: 17))
                                Panel {
                                    VStack(spacing: 10) {
                                        ForEach(Array(meal.items.enumerated()), id: \.offset) { _, it in
                                            HStack {
                                                Text(it.ingredient).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                                Spacer()
                                                Text(it.measure).font(.system(size: 13)).foregroundColor(P.ash)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if !meal.steps.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Head(title: "Method").font(.system(size: 17))
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(meal.steps.enumerated()), id: \.offset) { i, step in
                                        HStack(alignment: .top, spacing: 12) {
                                            Text("\(i + 1)").font(.system(size: 13, weight: .black)).foregroundColor(.black)
                                                .frame(width: 24, height: 24)
                                                .background(Circle().fill(P.orange))
                                            Text(step).font(.system(size: 14)).foregroundColor(P.ash)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                        }

                        if let yt = URL(string: meal.youtube), !meal.youtube.isEmpty {
                            Link(destination: yt) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.rectangle.fill")
                                    Text("Watch how it's made").font(.system(size: 15, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(RoundedRectangle(cornerRadius: 14).fill(P.ember))
                            }
                        }

                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 16).padding(.top, 8)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Fuel Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(P.ash)
                }
            }
        }
        .tint(P.orange)
    }
}
