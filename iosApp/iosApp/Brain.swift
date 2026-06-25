import SwiftUI
import Foundation
import UIKit

// =====================================================================================
//  Sport Book Companion — the whole brain lives here. one file, one object, no mercy.
//  (intentionally not "clean": everything that touches state touches THIS thing.)
// =====================================================================================

// ---- color soup -------------------------------------------------------------------
extension Color {
    init(_ rgb: UInt32, _ a: Double = 1) {
        self.init(.sRGB,
                  red: Double((rgb >> 16) & 0xFF) / 255.0,
                  green: Double((rgb >> 8) & 0xFF) / 255.0,
                  blue: Double(rgb & 0xFF) / 255.0,
                  opacity: a)
    }
}

enum P { // palette. short name on purpose.
    static let ink     = Color(0x09090B)
    static let ink2    = Color(0x0E0E11)
    static let panel   = Color(0x161619)
    static let panel2  = Color(0x1F1F24)
    static let stroke  = Color(0xFFFFFF, 0.08)
    static let orange  = Color(0xFF6A12)
    static let orange2 = Color(0xFF8A33)
    static let ember   = Color(0xFF4D00)
    static let gold    = Color(0xFFC24B)
    static let ash     = Color(0x8B8B93)
    static let ashDim  = Color(0x5A5A62)
    static let ok      = Color(0x3FD27E)
    static func heat(_ x: Double) -> Color { // 0..1 -> ash->orange->ember
        let c = min(max(x, 0), 1)
        if c < 0.5 { return ash.interp(orange, c * 2) }
        return orange.interp(ember, (c - 0.5) * 2)
    }
}
extension Color {
    func interp(_ o: Color, _ t: Double) -> Color {
        let a = UIColor(self); let b = UIColor(o)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(min(max(t, 0), 1))
        return Color(.sRGB,
                     red: Double(r1 + (r2 - r1) * k),
                     green: Double(g1 + (g2 - g1) * k),
                     blue: Double(b1 + (b2 - b1) * k),
                     opacity: Double(a1 + (a2 - a1) * k))
    }
}

// ---- the one true model -----------------------------------------------------------
struct Sess: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var t: Double                 // epoch seconds. yes it's just called t.
    var kind: Int                 // 0..5 index into Brain.kinds
    var mins: Int
    var intensity: Int            // 1..5
    var rpe: Int                  // 1..10 perceived exertion
    var mood: Int                 // 0..4
    var note: String
    var drill: String?            // set when it came out of the playbook
    var tags: [String]
    var photo: String? = nil      // filename in Documents; optional so old saves still decode
}

// progress / locker photo — a dated shot you take to track how you look & feel over time
struct Shot: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var t: Double                 // epoch seconds
    var file: String              // filename in Documents
    var note: String
}

struct Drill: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var cat: Int                  // same index space as kinds
    var detail: String
    var minutes: Int
    var difficulty: Int           // 1..3
    var coaching: [String]        // bullet cues
}

// ---- god object -------------------------------------------------------------------
final class Brain: ObservableObject {

    static let shared = Brain()   // both a singleton AND injected. on purpose.

    // mutable jungle ----------------------------------------------------------------
    @Published var sessions: [Sess] = []        { didSet { dump() } }
    @Published var athlete: String = "Athlete"  { didSet { dump() } }
    @Published var position: Int = 0            { didSet { dump() } } // index into positions
    @Published var goalMins: Int = 180          { didSet { dump() } } // weekly target minutes
    @Published var goalSess: Int = 4            { didSet { dump() } } // weekly target sessions
    @Published var seenBoot: Bool = false       { didSet { dump() } }
    @Published var avatar: String? = nil        { didSet { dump() } } // profile photo filename
    @Published var shots: [Shot] = []           { didSet { dump() } } // progress photo locker
    @Published var cityName: String = ""        { didSet { dump() } } // weather city (manual, no GPS)
    @Published var cityLat: Double = 0          { didSet { dump() } }
    @Published var cityLon: Double = 0          { didSet { dump() } }
    @Published var records: [PRMark] = []       { didSet { dump() } } // personal records / combine numbers

    // transient ui state that has no business being in the store, but here we are
    @Published var tab: Int = 0
    @Published var booted: Bool = false
    @Published var addOpen: Bool = false
    @Published var celebrate: String? = nil      // achievement id currently being celebrated

    // static-ish lookup tables ------------------------------------------------------
    static let kinds      = ["Strength", "Speed & Agility", "Position Drills", "Conditioning", "Film Study", "Recovery"]
    static let kindIcon   = ["dumbbell.fill", "bolt.fill", "figure.american.football", "flame.fill", "play.rectangle.fill", "leaf.fill"]
    static let kindTint: [Color] = [P.gold, P.orange2, P.orange, P.ember, Color(0x4FA8FF), P.ok]
    static let positions  = ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "DB", "K/P", "ATH"]
    static let moodFace   = ["🥵", "😮‍💨", "😐", "🙂", "🔥"]
    static let moodWord   = ["Cooked", "Heavy", "Okay", "Good", "Dialed"]

    // sample playbook. lives in the brain because where else, honestly.
    let playbook: [Drill] = Brain.seedDrills()

    private let KEY = "sbc.brain.v1"

    private init() { load() }

    // ---- persistence: hand-rolled, swallow-the-error school of thought ------------
    private func dump() {
        var box: [String: Any] = [:]
        if let d = try? JSONEncoder().encode(sessions) { box["s"] = d.base64EncodedString() }
        box["a"] = athlete
        box["p"] = position
        box["gm"] = goalMins
        box["gs"] = goalSess
        box["sb"] = seenBoot
        box["av"] = avatar ?? ""
        if let d = try? JSONEncoder().encode(shots) { box["sh"] = d.base64EncodedString() }
        box["cn"] = cityName
        box["clat"] = cityLat
        box["clon"] = cityLon
        if let d = try? JSONEncoder().encode(records) { box["pr"] = d.base64EncodedString() }
        if let blob = try? JSONSerialization.data(withJSONObject: box) {
            UserDefaults.standard.set(blob, forKey: KEY)
        }
    }
    private func load() {
        guard let blob = UserDefaults.standard.data(forKey: KEY),
              let box = (try? JSONSerialization.jsonObject(with: blob)) as? [String: Any] else {
            return   // fresh install: start with an empty diary
        }
        if let b64 = box["s"] as? String, let d = Data(base64Encoded: b64),
           let arr = try? JSONDecoder().decode([Sess].self, from: d) { sessions = arr }
        athlete  = (box["a"] as? String) ?? "Athlete"
        position = (box["p"] as? Int) ?? 0
        goalMins = (box["gm"] as? Int) ?? 180
        goalSess = (box["gs"] as? Int) ?? 4
        seenBoot = (box["sb"] as? Bool) ?? false
        let av = (box["av"] as? String) ?? ""; avatar = av.isEmpty ? nil : av
        if let b64 = box["sh"] as? String, let d = Data(base64Encoded: b64),
           let arr = try? JSONDecoder().decode([Shot].self, from: d) { shots = arr }
        cityName = (box["cn"] as? String) ?? ""
        cityLat  = (box["clat"] as? Double) ?? 0
        cityLon  = (box["clon"] as? Double) ?? 0
        if let b64 = box["pr"] as? String, let d = Data(base64Encoded: b64),
           let arr = try? JSONDecoder().decode([PRMark].self, from: d) { records = arr }
    }
    var hasCity: Bool { !cityName.isEmpty }

    // =================================================================================
    //  DERIVED EVERYTHING. all computed live, no caching, recomputed on every read,
    //  because clean would be to memoize and we were told not to be clean.
    // =================================================================================

    var sorted: [Sess] { sessions.sorted { $0.t > $1.t } }

    func dayKey(_ t: Double) -> Int {
        let d = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: t))
        return Int(d.timeIntervalSince1970 / 86400.0)
    }

    var streak: Int {
        let days = Set(sessions.map { dayKey($0.t) })
        if days.isEmpty { return 0 }
        let today = dayKey(Date().timeIntervalSince1970)
        // allow the streak to be "alive" if you trained today OR yesterday
        var cursor = days.contains(today) ? today : (days.contains(today - 1) ? today - 1 : -999)
        if cursor == -999 { return 0 }
        var n = 0
        while days.contains(cursor) { n += 1; cursor -= 1 }
        return n
    }

    var totalMins: Int { sessions.reduce(0) { $0 + $1.mins } }
    var totalSess: Int { sessions.count }

    // minutes per weekday for the last 7 days, oldest..today
    var weekBars: [(label: String, mins: Int, today: Bool)] {
        let f = DateFormatter(); f.dateFormat = "EEEEE" // single letter
        var out: [(String, Int, Bool)] = []
        let todayKey = dayKey(Date().timeIntervalSince1970)
        for back in stride(from: 6, through: 0, by: -1) {
            let day = todayKey - back
            let mins = sessions.filter { dayKey($0.t) == day }.reduce(0) { $0 + $1.mins }
            let date = Date(timeIntervalSince1970: Double(day) * 86400.0 + 43200)
            out.append((f.string(from: date), mins, day == todayKey))
        }
        return out.map { ($0.0, $0.1, $0.2) }
    }

    var weekMins: Int {
        let todayKey = dayKey(Date().timeIntervalSince1970)
        return sessions.filter { todayKey - dayKey($0.t) < 7 }.reduce(0) { $0 + $1.mins }
    }
    var weekCount: Int {
        let todayKey = dayKey(Date().timeIntervalSince1970)
        return sessions.filter { todayKey - dayKey($0.t) < 7 }.count
    }
    var weekGoalPct: Double { goalMins <= 0 ? 0 : min(1.0, Double(weekMins) / Double(goalMins)) }
    var weekSessPct: Double { goalSess <= 0 ? 0 : min(1.0, Double(weekCount) / Double(goalSess)) }

    var avgRpe: Double {
        let r = sessions.map { $0.rpe }
        return r.isEmpty ? 0 : Double(r.reduce(0, +)) / Double(r.count)
    }

    // a single 0..1 "load" number mashing volume + intensity, no science whatsoever
    var loadIndex: Double {
        let w = weekMins
        let i = avgRpe
        return min(1.0, (Double(w) / 320.0) * 0.7 + (i / 10.0) * 0.3)
    }

    // breakdown of minutes by kind -> for the donut-ish bars
    var byKind: [(idx: Int, mins: Int)] {
        var acc = Array(repeating: 0, count: Brain.kinds.count)
        for s in sessions where s.kind >= 0 && s.kind < acc.count { acc[s.kind] += s.mins }
        return acc.enumerated().map { (idx: $0.offset, mins: $0.element) }.sorted { $0.mins > $1.mins }
    }

    // =================================================================================
    //  MORE STATS — all derived live from raw sessions. v1.1 analytics wall.
    // =================================================================================

    // longest run of consecutive training days you've ever put together
    var longestStreak: Int {
        let days = Set(sessions.map { dayKey($0.t) }).sorted()
        if days.isEmpty { return 0 }
        var best = 1, run = 1
        for i in 1..<days.count {
            run = days[i] == days[i - 1] + 1 ? run + 1 : 1
            best = max(best, run)
        }
        return best
    }

    var avgSessionMins: Int { sessions.isEmpty ? 0 : totalMins / sessions.count }
    var avgIntensity: Double {
        let a = sessions.map { $0.intensity }
        return a.isEmpty ? 0 : Double(a.reduce(0, +)) / Double(a.count)
    }

    // distinct days trained, and how consistent you've been since you started
    var trainedDaysCount: Int { Set(sessions.map { dayKey($0.t) }).count }
    var consistency: Double {
        guard let first = sessions.map({ dayKey($0.t) }).min() else { return 0 }
        let span = max(1, dayKey(Date().timeIntervalSince1970) - first + 1)
        return min(1.0, Double(trainedDaysCount) / Double(span))
    }

    // most minutes ever logged in a single calendar day
    var bestDayMins: Int {
        var acc: [Int: Int] = [:]
        for s in sessions { acc[dayKey(s.t), default: 0] += s.mins }
        return acc.values.max() ?? 0
    }

    // minutes the previous full week (days 7..13 back) — for the week-over-week trend
    var lastWeekMins: Int {
        let t = dayKey(Date().timeIntervalSince1970)
        return sessions.filter { let d = t - dayKey($0.t); return d >= 7 && d < 14 }.reduce(0) { $0 + $1.mins }
    }
    var weekTrendPct: Double {   // +/- change vs last week, -1..+big
        lastWeekMins == 0 ? (weekMins > 0 ? 1 : 0) : (Double(weekMins) - Double(lastWeekMins)) / Double(lastWeekMins)
    }

    // minutes logged in the current calendar month
    var thisMonthMins: Int {
        let cal = Calendar.current; let now = Date()
        return sessions.filter { cal.isDate(Date(timeIntervalSince1970: $0.t), equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.mins }
    }

    // minutes by weekday, Mon..Sun (so the bars read like a week)
    var byWeekday: [(label: String, mins: Int)] {
        var acc = Array(repeating: 0, count: 7)   // 0=Mon .. 6=Sun
        let cal = Calendar.current
        for s in sessions {
            let wd = cal.component(.weekday, from: Date(timeIntervalSince1970: s.t)) // 1=Sun..7=Sat
            acc[(wd + 5) % 7] += s.mins
        }
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        return labels.enumerated().map { (label: $0.element, mins: acc[$0.offset]) }
    }

    // how sessions felt — count per mood face
    var moodCounts: [Int] {
        var a = Array(repeating: 0, count: Brain.moodFace.count)
        for s in sessions where s.mood >= 0 && s.mood < a.count { a[s.mood] += 1 }
        return a
    }

    // your go-to training type (most minutes), or nil if nothing logged
    var favoriteKind: Int? { byKind.first.flatMap { $0.mins > 0 ? $0.idx : nil } }

    // ---- ACHIEVEMENTS: computed from raw sessions, gnarly tuple list -------------
    struct Ach: Identifiable { let id: String; let title: String; let blurb: String; let art: String; let done: Bool; let pct: Double }
    var achievements: [Ach] {
        let total = totalSess
        let mins = totalMins
        let st = streak
        let prs = sessions.filter { $0.tags.contains("pr") }.count
        let film = sessions.filter { $0.kind == 4 }.count
        let speed = sessions.filter { $0.kind == 1 }.count
        let recov = sessions.filter { $0.kind == 5 }.count
        let kindsSeen = Set(sessions.map { $0.kind }).count
        let photos = sessions.filter { $0.photo != nil }.count + shots.count
        let recs = records.count
        func a(_ id: String, _ t: String, _ b: String, _ art: String, _ have: Int, _ need: Int) -> Ach {
            Ach(id: id, title: t, blurb: b, art: art, done: have >= need, pct: need == 0 ? 1 : min(1, Double(have) / Double(need)))
        }
        return [
            a("first", "First Snap", "Log your first session", "football", total, 1),
            a("ten", "Two-A-Days", "Log 10 sessions", "badgeOne", total, 10),
            a("fifty", "Half Century", "Log 50 sessions", "stars", total, 50),
            a("century", "Centurion", "Log 100 sessions", "trophy", total, 100),
            a("streak3", "Hat Trick", "3-day training streak", "stars", st, 3),
            a("streak7", "Iron Week", "7-day training streak", "trophy", st, 7),
            a("streak30", "Iron Month", "30-day training streak", "goalpost", st, 30),
            a("grind", "Grinder", "Log 1000 total minutes", "goalpost", mins, 1000),
            a("grind5k", "Iron Will", "Log 5000 total minutes", "goalpost", mins, 5000),
            a("all6", "Total Athlete", "Train all 6 categories", "playbook", kindsSeen, 6),
            a("film", "Film Rat", "5 film study sessions", "playbook", film, 5),
            a("speed", "Burner", "10 speed & agility sessions", "football", speed, 10),
            a("recover", "Recovery King", "10 recovery sessions", "stars", recov, 10),
            a("photo", "Game Film", "Attach your first photo", "helmet", photos, 1),
            a("record", "Record Setter", "Log a personal record", "badgeOne", recs, 1),
            a("pr", "New PR", "Tag a session as a PR", "helmet", prs, 1)
        ]
    }
    var unlockedCount: Int { achievements.filter { $0.done }.count }

    // =================================================================================
    //  MUTATORS — also where achievement-unlock side effects fire. tangled on purpose.
    // =================================================================================
    static let DAY_CAP_MIN = 24 * 60   // a day is 24 hours. that's the whole budget.

    // minutes already logged on the same calendar day as `t` (optionally ignoring one id)
    func minutesOnDay(of t: Double, ignoring id: UUID? = nil) -> Int {
        let dk = dayKey(t)
        return sessions.filter { dayKey($0.t) == dk && $0.id != id }.reduce(0) { $0 + $1.mins }
    }

    @discardableResult
    func add(_ s: Sess) -> Bool {
        // hard reality gate: can't push a single day over 24h of training
        if minutesOnDay(of: s.t) + s.mins > Brain.DAY_CAP_MIN { return false }
        let before = Set(achievements.filter { $0.done }.map { $0.id })
        sessions.append(s)
        let after = achievements.filter { $0.done }.map { $0.id }
        if let fresh = after.first(where: { !before.contains($0) }) {
            celebrate = fresh
        }
        return true
    }
    func remove(_ s: Sess) { ImageStore.delete(s.photo); sessions.removeAll { $0.id == s.id } }
    func update(_ s: Sess) { if let i = sessions.firstIndex(where: { $0.id == s.id }) { sessions[i] = s } }

    // ---- photos: avatar + progress locker. all writes go straight to disk + the store --
    func setAvatar(_ img: UIImage) { ImageStore.delete(avatar); avatar = ImageStore.save(img) }
    func clearAvatar() { ImageStore.delete(avatar); avatar = nil }
    func addShot(_ img: UIImage, note: String = "") {
        if let f = ImageStore.save(img) { shots.insert(Shot(t: Date().timeIntervalSince1970, file: f, note: note), at: 0) }
    }
    func removeShot(_ s: Shot) { ImageStore.delete(s.file); shots.removeAll { $0.id == s.id } }

    // ---- weather city (manual pick, no location services) -----------------------------
    func setCity(_ name: String, _ lat: Double, _ lon: Double) { cityName = name; cityLat = lat; cityLon = lon }

    // ---- personal records: store every mark, derive best/latest on the fly ------------
    func addRecord(_ metric: String, _ value: Double, t: Double = Date().timeIntervalSince1970) {
        records.insert(PRMark(metric: metric, t: t, value: value), at: 0)
    }
    func removeRecord(_ m: PRMark) { records.removeAll { $0.id == m.id } }
    func history(_ metric: String) -> [PRMark] { records.filter { $0.metric == metric }.sorted { $0.t < $1.t } }
    func latest(_ metric: String) -> PRMark? { records.filter { $0.metric == metric }.max { $0.t < $1.t } }
    func best(_ metric: String, lowerBetter: Bool) -> PRMark? {
        let h = records.filter { $0.metric == metric }
        return lowerBetter ? h.min { $0.value < $1.value } : h.max { $0.value < $1.value }
    }

    @discardableResult
    func logDrill(_ d: Drill) -> Bool {
        add(Sess(t: Date().timeIntervalSince1970, kind: d.cat, mins: d.minutes,
                 intensity: min(5, d.difficulty + 2), rpe: min(10, d.difficulty * 3),
                 mood: 3, note: "From playbook: \(d.name)", drill: d.name, tags: ["playbook"]))
    }

    func wipe() {
        for s in sessions { ImageStore.delete(s.photo) }   // don't orphan jpegs on disk
        for sh in shots { ImageStore.delete(sh.file) }
        ImageStore.delete(avatar)
        sessions = []; athlete = "Athlete"; position = 0; goalMins = 180; goalSess = 4
        seenBoot = false; avatar = nil; shots = []
        cityName = ""; cityLat = 0; cityLon = 0; records = []
    }

    // ---- formatting helpers crammed in here too -----------------------------------
    func ago(_ t: Double) -> String {
        let s = Date().timeIntervalSince1970 - t
        if s < 3600 { return "\(max(1, Int(s / 60)))m ago" }
        if s < 86400 { return "\(Int(s / 3600))h ago" }
        let d = Int(s / 86400)
        if d == 1 { return "Yesterday" }
        if d < 7 { return "\(d)d ago" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: Date(timeIntervalSince1970: t))
    }
    func longDate(_ t: Double) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d • h:mm a"
        return f.string(from: Date(timeIntervalSince1970: t))
    }
    func greeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "Morning" : (h < 18 ? "Afternoon" : "Evening")
        return "\(part), \(athlete.isEmpty ? "Athlete" : athlete)"
    }

    // ---- the seed playbook --------------------------------------------------------
    static func seedDrills() -> [Drill] {
        return [
            Drill(id: "rt", name: "Route Tree Ladder", cat: 2, detail: "Run the full 9-route tree off the line. Sharp breaks, sell every stem.", minutes: 35, difficulty: 2, coaching: ["Sink hips at the break", "Eyes back late", "Snap the head around"]),
            Drill(id: "pa", name: "Pro Agility 5-10-5", cat: 1, detail: "Classic short-shuttle. Explode out of the stance, plant outside foot, flip hips.", minutes: 25, difficulty: 2, coaching: ["Stay low through the turn", "Touch the line", "Drive the back arm"]),
            Drill(id: "tb", name: "Trap Bar Deadlift", cat: 0, detail: "Heavy hinge for lower-body power. 5x3 building to a top set.", minutes: 45, difficulty: 3, coaching: ["Brace the core", "Push the floor away", "Lockout tall"]),
            Drill(id: "sl", name: "Sled Push 20yd", cat: 3, detail: "Loaded sprints for conditioning + acceleration mechanics.", minutes: 30, difficulty: 3, coaching: ["Shin angle 45°", "Punch the knees", "Don't stand up early"]),
            Drill(id: "co", name: "Cone Footwork Series", cat: 1, detail: "W-drill, T-drill, and figure-8 for change of direction.", minutes: 20, difficulty: 1, coaching: ["Short choppy steps", "Eyes up", "Stay on the balls of your feet"]),
            Drill(id: "fb", name: "Bag Drill Hi-Knees", cat: 2, detail: "Get-off and footwork over the bags. Knees up, no false steps.", minutes: 15, difficulty: 1, coaching: ["Drive the knees", "Stay square", "Finish through the last bag"]),
            Drill(id: "fs", name: "Opponent Film Breakdown", cat: 4, detail: "Chart tendencies: down & distance, formation, hot reads.", minutes: 40, difficulty: 1, coaching: ["Note pre-snap tells", "Tag every blitz look", "Write 3 takeaways"]),
            Drill(id: "yo", name: "Mobility + Yoga Flow", cat: 5, detail: "Hips, ankles, t-spine. Bring the heart rate down and recover.", minutes: 30, difficulty: 1, coaching: ["Breathe into the stretch", "No bouncing", "Hold 30s each side"]),
            Drill(id: "pl", name: "Plyo Box Jumps", cat: 0, detail: "Triple-extension power. Step down, never jump down.", minutes: 25, difficulty: 2, coaching: ["Land soft", "Full hip extension", "Reset every rep"]),
            Drill(id: "ts", name: "Tempo Sprints 6x100", cat: 3, detail: "Sub-max sprints at 75% with walk-back recovery.", minutes: 35, difficulty: 2, coaching: ["Tall posture", "Relax the face & hands", "Smooth turnover"]),
            // ---- expanded library (v1.1) ------------------------------------------------
            Drill(id: "bp", name: "Bench Press 5x5", cat: 0, detail: "Upper-body pressing strength. Five sets of five across a tough top weight.", minutes: 40, difficulty: 3, coaching: ["Pin the shoulder blades", "Bar to the lower chest", "Drive the feet"]),
            Drill(id: "fs2", name: "Front Squat 4x6", cat: 0, detail: "Quad-dominant strength + brutal core bracing. Keep the elbows up.", minutes: 40, difficulty: 3, coaching: ["Elbows high", "Sit between the hips", "Stay tall out of the hole"]),
            Drill(id: "pc", name: "Power Clean 5x3", cat: 0, detail: "Full-body triple extension for explosive force. Speed over weight.", minutes: 35, difficulty: 3, coaching: ["Bar close to the body", "Violent hip snap", "Catch in a quarter squat"]),
            Drill(id: "lad", name: "Speed Ladder Circuit", cat: 1, detail: "In-and-outs, lateral shuffles, Icky shuffle. Fast feet, clean eyes.", minutes: 18, difficulty: 1, coaching: ["Stay on the balls", "Pump the arms", "Don't look down"]),
            Drill(id: "rx", name: "Reaction Ball Drops", cat: 1, detail: "Partner drops a reaction ball — break, react, secure it. Pure first-step.", minutes: 20, difficulty: 2, coaching: ["Athletic stance", "React, don't guess", "Low and balanced"]),
            Drill(id: "bl", name: "Blocking Sled Series", cat: 2, detail: "Fire off the ball into the sled. Hand placement, leg drive, finish.", minutes: 30, difficulty: 2, coaching: ["Hands inside", "Roll the hips", "Run the feet on contact"]),
            Drill(id: "cb", name: "Catch & Tuck Gauntlet", cat: 2, detail: "Ball after ball at game speed — look it in, tuck high & tight.", minutes: 25, difficulty: 2, coaching: ["Eyes to the tuck", "Late hands", "Pluck away from the body"]),
            Drill(id: "gas", name: "Gassers (4x53yd)", cat: 3, detail: "Field-width conditioning. Down-and-back twice, on the whistle.", minutes: 20, difficulty: 3, coaching: ["Touch every line", "Pace the first rep", "Finish through"]),
            Drill(id: "hl", name: "Hill Sprints 8x", cat: 3, detail: "Short steep sprints for power endurance. Walk down to recover.", minutes: 30, difficulty: 3, coaching: ["Aggressive arms", "Forward lean", "Full recovery between"]),
            Drill(id: "sc", name: "Self-Scout Cut-ups", cat: 4, detail: "Grade your own last performance. Wins, losses, and one fix per series.", minutes: 30, difficulty: 1, coaching: ["Be honest", "Grade technique not result", "One concrete fix"]),
            Drill(id: "in", name: "Install Walkthrough", cat: 4, detail: "Whiteboard the new install. Know your job and the guy next to you.", minutes: 25, difficulty: 1, coaching: ["Say it out loud", "Know the adjustments", "Quiz yourself after"]),
            Drill(id: "fr", name: "Foam Roll + Soft Tissue", cat: 5, detail: "Roll the quads, IT band, calves, and back. Ten slow passes each.", minutes: 20, difficulty: 1, coaching: ["Slow on the hot spots", "Breathe, don't brace", "Hydrate after"]),
            Drill(id: "cs", name: "Contrast Shower & Sleep Prep", cat: 5, detail: "Hot/cold contrast, then wind down. Recovery is a skill you train.", minutes: 25, difficulty: 1, coaching: ["End on cold", "Screens off", "Same bedtime nightly"])
        ]
    }
}

// shared singleton handle so spaghetti views can grab it without injection too
let theBrain = Brain.shared
