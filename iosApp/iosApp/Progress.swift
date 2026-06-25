import SwiftUI

// =====================================================================================
//  ProgressScreen — stats wall + hand-rolled bar chart + kind breakdown + achievements.
//  (named ...Screen so it doesn't collide with SwiftUI.ProgressView)
// =====================================================================================
struct ProgressScreen: View {
    @EnvironmentObject var b: Brain
    @State private var zoom: Shot? = nil

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
                    stat("Avg RPE", b.avgRpe > 0 ? String(format: "%.1f", b.avgRpe) : "—", "gauge.medium", P.heat(b.avgRpe / 10))
                    stat("This Week", "\(b.weekMins)m", "calendar", P.ok)
                }

                // ---- week-over-week trend ----
                TrendPanel()

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

                // ---- insights wall ----
                InsightsPanel()

                // ---- weekday pattern ----
                WeekdayPanel()

                // ---- streak calendar (last 5 weeks) ----
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Training Calendar").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            Spacer()
                            Text("last 35 days").font(.system(size: 12)).foregroundColor(P.ash)
                        }
                        StreakGrid()
                        HStack(spacing: 14) {
                            legendDot(P.panel2, "rest")
                            legendDot(P.orange.opacity(0.55), "light")
                            legendDot(P.ember, "hard")
                            Spacer()
                        }.padding(.top, 2)
                    }
                }

                // ---- progress photos ----
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Progress Photos").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            Spacer()
                            Text("\(b.shots.count)").font(.system(size: 13, weight: .bold)).foregroundColor(P.orange)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // add tile
                                PhotoPicker(hasImage: false, onPick: { b.addShot($0) }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "plus").font(.system(size: 22, weight: .heavy)).foregroundColor(P.orange)
                                        Text("Add").font(.system(size: 11, weight: .bold)).foregroundColor(P.ash)
                                    }
                                    .frame(width: 96, height: 128)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(P.panel2)
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.stroke, style: StrokeStyle(lineWidth: 1, dash: [5]))))
                                }
                                ForEach(b.shots) { sh in shotTile(sh) }
                            }
                        }
                        if b.shots.isEmpty {
                            Text("Snap a photo every few weeks to watch yourself change.")
                                .font(.system(size: 12)).foregroundColor(P.ashDim)
                        }
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

                // ---- mood breakdown ----
                MoodPanel()

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
        .sheet(item: $zoom) { sh in ShotViewer(shot: sh) }
    }

    // a single progress-photo thumbnail: tap to zoom, long-press to delete
    private func shotTile(_ sh: Shot) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let img = ImageStore.load(sh.file) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 96, height: 128).clipped()
            } else {
                Rectangle().fill(P.panel2).frame(width: 96, height: 128)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
            Text(b.ago(sh.t)).font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(6)
        }
        .frame(width: 96, height: 128)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.stroke, lineWidth: 1))
        .onTapGesture { zoom = sh }
        .contextMenu {
            Button(role: .destructive) { b.removeShot(sh) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func legendDot(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 12, height: 12)
            Text(t).font(.system(size: 11)).foregroundColor(P.ash)
        }
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

// =====================================================================================
//  StreakGrid — GitHub-style heat grid of the last 35 days. heat == minutes that day.
// =====================================================================================
struct StreakGrid: View {
    @EnvironmentObject var b: Brain
    var body: some View {
        let todayKey = b.dayKey(Date().timeIntervalSince1970)
        // build minutes-per-day for the last 35 days (oldest -> today)
        let mins: [Int: Int] = b.sessions.reduce(into: [:]) { acc, s in acc[b.dayKey(s.t), default: 0] += s.mins }
        let cols = 7
        let rows = 5
        return VStack(spacing: 6) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(0..<cols, id: \.self) { c in
                        let back = (rows * cols - 1) - (r * cols + c)   // 34..0
                        let key = todayKey - back
                        let m = mins[key] ?? 0
                        RoundedRectangle(cornerRadius: 4)
                            .fill(cellColor(m))
                            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                            .overlay(RoundedRectangle(cornerRadius: 4)
                                .stroke(key == todayKey ? P.gold : .clear, lineWidth: 1.5))
                    }
                }
            }
        }
    }
    private func cellColor(_ m: Int) -> Color {
        if m == 0 { return P.panel2 }
        return P.orange.opacity(0.45).interp(P.ember, min(1, Double(m) / 90.0))
    }
}

// =====================================================================================
//  ShotViewer — full-screen progress photo with its date.
// =====================================================================================
struct ShotViewer: View {
    @EnvironmentObject var b: Brain
    @Environment(\.dismiss) private var dismiss
    var shot: Shot
    var body: some View {
        ZStack {
            P.ink.ignoresSafeArea()
            VStack(spacing: 14) {
                if let img = ImageStore.load(shot.file) {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 18))
                }
                Text(b.longDate(shot.t)).font(.system(size: 14, weight: .semibold)).foregroundColor(P.ash)
                Button { dismiss() } label: {
                    Text("Done").font(.system(size: 16, weight: .bold)).foregroundColor(.black)
                        .padding(.horizontal, 30).padding(.vertical, 12)
                        .background(Capsule().fill(P.orange))
                }
            }.padding(20)
        }
    }
}
