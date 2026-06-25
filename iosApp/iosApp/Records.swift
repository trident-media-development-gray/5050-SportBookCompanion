import SwiftUI

// =====================================================================================
//  Records — personal records / combine numbers. New in v1.1. Every mark is dated and
//  kept, so we can show your current best AND the trend over time. All on-device.
// =====================================================================================

// one dated measurement for a metric
struct PRMark: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var metric: String        // key into PR.catalog
    var t: Double             // epoch seconds
    var value: Double
}

// the fixed catalog of trackable records — combine tests + the big lifts
enum PR {
    struct Def: Identifiable, Hashable {
        let id: String
        let name: String
        let unit: String        // "lb", "in", "sec", "reps"
        let lowerBetter: Bool   // sprints/shuttles: smaller is better
        let icon: String
        let tint: Color
    }
    static let catalog: [Def] = [
        Def(id: "bench",    name: "Bench Press 1RM",  unit: "lb",   lowerBetter: false, icon: "dumbbell.fill",            tint: P.gold),
        Def(id: "squat",    name: "Back Squat 1RM",   unit: "lb",   lowerBetter: false, icon: "figure.strengthtraining.traditional", tint: P.orange2),
        Def(id: "dead",     name: "Deadlift 1RM",     unit: "lb",   lowerBetter: false, icon: "scalemass.fill",           tint: P.ember),
        Def(id: "clean",    name: "Power Clean 1RM",  unit: "lb",   lowerBetter: false, icon: "bolt.fill",                tint: P.orange),
        Def(id: "bench225", name: "225 Bench Reps",   unit: "reps", lowerBetter: false, icon: "repeat",                   tint: P.gold),
        Def(id: "forty",    name: "40-Yard Dash",     unit: "sec",  lowerBetter: true,  icon: "hare.fill",                tint: Color(0x4FA8FF)),
        Def(id: "shuttle",  name: "Pro Shuttle",      unit: "sec",  lowerBetter: true,  icon: "arrow.left.arrow.right",   tint: Color(0x4FA8FF)),
        Def(id: "vert",     name: "Vertical Jump",    unit: "in",   lowerBetter: false, icon: "arrow.up.to.line",         tint: P.ok),
        Def(id: "broad",    name: "Broad Jump",       unit: "in",   lowerBetter: false, icon: "figure.jumprope",          tint: P.ok)
    ]
    static func def(_ id: String) -> Def? { catalog.first { $0.id == id } }

    // pretty-print a value for a unit (times keep 2 decimals, the rest are whole)
    static func fmt(_ v: Double, _ unit: String) -> String {
        unit == "sec" ? String(format: "%.2f", v) : String(Int(v.rounded()))
    }
}

// =====================================================================================
//  RecordsView — one card per metric: current best, latest, trend, mini sparkline.
// =====================================================================================
struct RecordsView: View {
    @EnvironmentObject var b: Brain
    @Environment(\.dismiss) private var dismiss
    @State private var logging: PR.Def? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppBG()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Head(title: "Personal Records", sub: "Your combine numbers & big lifts").padding(.top, 6)
                        ForEach(PR.catalog) { d in card(d) }
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.foregroundColor(P.ash) }
            }
            .sheet(item: $logging) { d in AddRecordSheet(def: d) }
        }
        .tint(P.orange)
    }

    private func card(_ d: PR.Def) -> some View {
        let best = b.best(d.id, lowerBetter: d.lowerBetter)
        let hist = b.history(d.id)
        return Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(d.tint.opacity(0.16)).frame(width: 42, height: 42)
                        Image(systemName: d.icon).font(.system(size: 18, weight: .bold)).foregroundColor(d.tint)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        if let best {
                            Text("Best \(PR.fmt(best.value, d.unit)) \(d.unit) • \(b.ago(best.t))")
                                .font(.system(size: 12)).foregroundColor(P.ash)
                        } else {
                            Text("No mark yet").font(.system(size: 12)).foregroundColor(P.ashDim)
                        }
                    }
                    Spacer()
                    Button { logging = d } label: {
                        Image(systemName: "plus").font(.system(size: 15, weight: .heavy)).foregroundColor(.black)
                            .frame(width: 34, height: 34).background(Circle().fill(d.tint))
                    }
                }
                if hist.count >= 2 {
                    HStack(spacing: 10) {
                        Spark(values: hist.map { $0.value }, lowerBetter: d.lowerBetter, tint: d.tint)
                            .frame(height: 34).frame(maxWidth: .infinity)
                        if let best, let first = hist.first {
                            let delta = best.value - first.value
                            let improved = d.lowerBetter ? delta < 0 : delta > 0
                            Text("\(improved ? "▲" : "▼") \(PR.fmt(abs(delta), d.unit))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(improved ? P.ok : P.ash)
                        }
                    }
                }
            }
        }
        .contextMenu {
            if let best { Button(role: .destructive) { b.removeRecord(best) } label: { Label("Delete best mark", systemImage: "trash") } }
        }
    }
}

// tiny inline sparkline of a metric's history
struct Spark: View {
    var values: [Double]
    var lowerBetter: Bool
    var tint: Color
    var body: some View {
        GeometryReader { g in
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(0.0001, hi - lo)
            let pts = values.enumerated().map { i, v -> CGPoint in
                let x = values.count <= 1 ? 0 : CGFloat(i) / CGFloat(values.count - 1) * g.size.width
                let norm = (v - lo) / span                 // 0..1, high value = top
                let y = (1 - CGFloat(norm)) * g.size.height
                return CGPoint(x: x, y: y)
            }
            Path { p in
                guard let first = pts.first else { return }
                p.move(to: first); pts.dropFirst().forEach { p.addLine(to: $0) }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

// =====================================================================================
//  AddRecordSheet — log a new dated mark for one metric.
// =====================================================================================
struct AddRecordSheet: View {
    @EnvironmentObject var b: Brain
    @Environment(\.dismiss) private var dismiss
    let def: PR.Def
    @State private var text = ""
    @State private var when = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBG()
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        Image(systemName: def.icon).font(.system(size: 22, weight: .bold)).foregroundColor(def.tint)
                        Text(def.name).font(.system(size: 20, weight: .heavy)).foregroundColor(.white)
                    }.padding(.top, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("VALUE (\(def.unit.uppercased()))").font(.system(size: 12, weight: .heavy)).tracking(1).foregroundColor(P.ash)
                        HStack {
                            TextField("", text: $text, prompt: Text(def.unit == "sec" ? "4.52" : "0").foregroundColor(P.ashDim))
                                .keyboardType(.decimalPad)
                                .font(.system(size: 30, weight: .black)).foregroundColor(.white)
                            Text(def.unit).font(.system(size: 18, weight: .bold)).foregroundColor(P.ash)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(P.panel2))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("WHEN").font(.system(size: 12, weight: .heavy)).tracking(1).foregroundColor(P.ash)
                        DatePicker("", selection: $when, in: ...Date(), displayedComponents: .date)
                            .labelsHidden().datePickerStyle(.compact).tint(P.orange)
                    }

                    if let best = b.best(def.id, lowerBetter: def.lowerBetter) {
                        Text("Current best: \(PR.fmt(best.value, def.unit)) \(def.unit)")
                            .font(.system(size: 13)).foregroundColor(P.ashDim)
                    }
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("New Mark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(P.ash) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.font(.system(size: 16, weight: .heavy)).foregroundColor(P.orange)
                        .disabled(Double(text) == nil)
                }
            }
        }
    }

    private func save() {
        guard let v = Double(text.replacingOccurrences(of: ",", with: ".")), v > 0 else { return }
        b.addRecord(def.id, v, t: when.timeIntervalSince1970)
        Haptics.win()
        dismiss()
    }
}
