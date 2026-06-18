import SwiftUI

// =====================================================================================
//  ProgressScreen — stats wall + hand-rolled bar chart + kind breakdown + achievements.
//  (named ...Screen so it doesn't collide with SwiftUI.ProgressView)
// =====================================================================================
struct ProgressScreen: View {
    @EnvironmentObject var b: Brain

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Head(title: "Progress").padding(.top, 8)

                // ---- stat tiles ----
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    stat("Sessions", "\(b.totalSess)", "book.fill", P.orange)
                    stat("Hours", String(format: "%.1f", Double(b.totalMins) / 60), "clock.fill", P.gold)
                    stat("Day Streak", "\(b.streak)", "flame.fill", P.ember)
                    stat("Badges", "\(b.unlockedCount)/\(b.achievements.count)", "rosette", P.orange2)
                }

                // ---- weekly bars ----
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Last 7 Days").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            Spacer()
                            Text("\(b.weekMins) min").font(.system(size: 13, weight: .bold)).foregroundColor(P.orange)
                        }
                        let bars = b.weekBars
                        let peak = max(1, bars.map { $0.mins }.max() ?? 1)
                        HStack(alignment: .bottom, spacing: 10) {
                            ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                                VStack(spacing: 6) {
                                    Text(bar.mins > 0 ? "\(bar.mins)" : "")
                                        .font(.system(size: 10, weight: .bold)).foregroundColor(P.ash)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(bar.today
                                              ? LinearGradient(colors: [P.gold, P.ember], startPoint: .top, endPoint: .bottom)
                                              : LinearGradient(colors: [P.orange.opacity(0.85), P.orange.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                                        .frame(height: max(4, CGFloat(bar.mins) / CGFloat(peak) * 110))
                                    Text(bar.label).font(.system(size: 11, weight: bar.today ? .heavy : .regular))
                                        .foregroundColor(bar.today ? P.orange : P.ashDim)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 150)
                    }
                }

                // ---- breakdown by kind ----
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Where Your Time Goes").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        let total = max(1, b.totalMins)
                        ForEach(b.byKind, id: \.idx) { row in
                            if row.mins > 0 {
                                VStack(spacing: 5) {
                                    HStack {
                                        Text(Brain.kinds[row.idx]).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                        Spacer()
                                        Text("\(row.mins)m • \(Int(Double(row.mins) / Double(total) * 100))%")
                                            .font(.system(size: 12, weight: .semibold)).foregroundColor(P.ash)
                                    }
                                    GeometryReader { g in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(P.panel2).frame(height: 9)
                                            Capsule().fill(Brain.kindTint[row.idx])
                                                .frame(width: max(9, g.size.width * CGFloat(row.mins) / CGFloat(total)), height: 9)
                                        }
                                    }.frame(height: 9)
                                }
                            }
                        }
                        if b.totalMins == 0 {
                            Text("Log some sessions to see your breakdown.").font(.system(size: 13)).foregroundColor(P.ashDim)
                        }
                    }
                }

                // ---- achievements ----
                Head(title: "Achievements", sub: "\(b.unlockedCount) of \(b.achievements.count) unlocked")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(b.achievements) { a in achCard(a) }
                }

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func stat(_ label: String, _ val: String, _ icon: String, _ tint: Color) -> some View {
        Panel(pad: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(tint)
                    Spacer()
                }
                Text(val).font(.system(size: 30, weight: .black)).foregroundColor(.white)
                Text(label.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1).foregroundColor(P.ash)
            }
        }
    }

    private func achCard(_ a: Brain.Ach) -> some View {
        Panel(pad: 14) {
            VStack(spacing: 8) {
                Image(a.art).resizable().scaledToFit().frame(height: 64)
                    .grayscale(a.done ? 0 : 1).opacity(a.done ? 1 : 0.45)
                    .shadow(color: a.done ? P.gold.opacity(0.5) : .clear, radius: 10)
                Text(a.title).font(.system(size: 14, weight: .heavy)).foregroundColor(a.done ? .white : P.ash)
                Text(a.blurb).font(.system(size: 11)).foregroundColor(P.ashDim).multilineTextAlignment(.center).lineLimit(2).frame(height: 28)
                if a.done {
                    Chip(icon: "checkmark.seal.fill", text: "Unlocked", tint: P.ok)
                } else {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(P.panel2).frame(height: 6)
                            Capsule().fill(P.orange).frame(width: max(6, g.size.width * a.pct), height: 6)
                        }
                    }.frame(height: 6)
                }
            }.frame(maxWidth: .infinity)
        }
    }
}
