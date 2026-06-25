import SwiftUI

// =====================================================================================
//  Stats — extra analytics panels for the Progress screen. New in v1.1. Every panel
//  reads straight off the brain's derived numbers; nothing cached, nothing stored.
// =====================================================================================

// ---- week-over-week trend: this week's minutes vs last week's ------------------------
struct TrendPanel: View {
    @EnvironmentObject var b: Brain
    var body: some View {
        let pct = b.weekTrendPct
        let up = pct >= 0
        return Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text("This Week vs Last").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(b.weekMins)").font(.system(size: 34, weight: .black)).foregroundColor(.white)
                    Text("min").font(.system(size: 14, weight: .semibold)).foregroundColor(P.ash)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.system(size: 13, weight: .black))
                        Text("\(abs(Int(pct * 100)))%").font(.system(size: 15, weight: .heavy))
                    }
                    .foregroundColor(up ? P.ok : P.ember)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill((up ? P.ok : P.ember).opacity(0.14)))
                }
                // two mini bars to compare the weeks
                let peak = max(1, max(b.weekMins, b.lastWeekMins))
                miniBar("This week", b.weekMins, peak, P.orange)
                miniBar("Last week", b.lastWeekMins, peak, P.ashDim)
            }
        }
    }
    private func miniBar(_ label: String, _ mins: Int, _ peak: Int, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(P.ash).frame(width: 72, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(P.panel2).frame(height: 10)
                    Capsule().fill(tint).frame(width: max(10, g.size.width * CGFloat(mins) / CGFloat(peak)), height: 10)
                }
            }.frame(height: 10)
            Text("\(mins)m").font(.system(size: 12, weight: .bold)).foregroundColor(.white).frame(width: 44, alignment: .trailing)
        }
    }
}

// ---- insights: a wall of one-line "headline" numbers ---------------------------------
struct InsightsPanel: View {
    @EnvironmentObject var b: Brain
    var body: some View {
        Panel {
            VStack(spacing: 0) {
                row("flame.fill", P.ember, "Longest streak", "\(b.longestStreak) days")
                line
                row("clock.fill", P.gold, "Avg session", "\(b.avgSessionMins) min")
                line
                row("calendar", P.ok, "This month", "\(b.thisMonthMins) min")
                line
                row("star.fill", P.orange, "Best day ever", "\(b.bestDayMins) min")
                line
                row("gauge.medium", P.heat(b.avgIntensity / 5), "Avg intensity", b.avgIntensity > 0 ? String(format: "%.1f / 5", b.avgIntensity) : "—")
                line
                row(b.favoriteKind != nil ? Brain.kindIcon[b.favoriteKind!] : "questionmark",
                    b.favoriteKind != nil ? Brain.kindTint[b.favoriteKind!] : P.ash,
                    "Go-to training", b.favoriteKind != nil ? Brain.kinds[b.favoriteKind!] : "—")
                line
                row("checkmark.circle.fill", P.orange2, "Consistency", "\(Int(b.consistency * 100))%")
            }
        }
    }
    private var line: some View { Divider().overlay(P.stroke).padding(.vertical, 10) }
    private func row(_ icon: String, _ tint: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundColor(tint).frame(width: 24)
            Text(label).font(.system(size: 14)).foregroundColor(P.ash)
            Spacer()
            Text(value).font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
        }
    }
}

// ---- weekday pattern: which days of the week you actually show up --------------------
struct WeekdayPanel: View {
    @EnvironmentObject var b: Brain
    var body: some View {
        let data = b.byWeekday
        let peak = max(1, data.map { $0.mins }.max() ?? 1)
        let topIdx = data.enumerated().max { $0.element.mins < $1.element.mins }?.offset
        return Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Weekly Pattern").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    if let i = topIdx, data[i].mins > 0 {
                        Text("busiest: \(fullDay(i))").font(.system(size: 12)).foregroundColor(P.ash)
                    }
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.offset) { i, d in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(i == topIdx && d.mins > 0
                                      ? LinearGradient(colors: [P.gold, P.ember], startPoint: .top, endPoint: .bottom)
                                      : LinearGradient(colors: [P.orange.opacity(0.8), P.orange.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                .frame(height: max(4, CGFloat(d.mins) / CGFloat(peak) * 90))
                            Text(d.label).font(.system(size: 11, weight: i == topIdx ? .heavy : .regular))
                                .foregroundColor(i == topIdx ? P.orange : P.ashDim)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120)
            }
        }
    }
    private func fullDay(_ i: Int) -> String { ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][i] }
}

// ---- mood breakdown: how your sessions tend to feel ----------------------------------
struct MoodPanel: View {
    @EnvironmentObject var b: Brain
    var body: some View {
        let counts = b.moodCounts
        let total = max(1, counts.reduce(0, +))
        return Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text("How It Feels").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                if counts.reduce(0, +) == 0 {
                    Text("Log sessions to see your mood mix.").font(.system(size: 13)).foregroundColor(P.ashDim)
                } else {
                    ForEach(0..<Brain.moodFace.count, id: \.self) { i in
                        HStack(spacing: 10) {
                            Text(Brain.moodFace[i]).font(.system(size: 20)).frame(width: 28)
                            Text(Brain.moodWord[i]).font(.system(size: 13, weight: .semibold)).foregroundColor(.white).frame(width: 60, alignment: .leading)
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(P.panel2).frame(height: 9)
                                    Capsule().fill(P.heat(Double(i) / 4))
                                        .frame(width: max(counts[i] > 0 ? 9 : 0, g.size.width * CGFloat(counts[i]) / CGFloat(total)), height: 9)
                                }
                            }.frame(height: 9)
                            Text("\(counts[i])").font(.system(size: 12, weight: .bold)).foregroundColor(P.ash).frame(width: 28, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}
