import SwiftUI

// =====================================================================================
//  HomeView — the dashboard. one big scroll, everything inline, recomputed constantly.
// =====================================================================================
struct HomeView: View {
    @EnvironmentObject var b: Brain

    // the "smart" suggestion: whichever training kind you've neglected most this app's life
    private var suggestion: Drill {
        let leastKind = b.byKind.last?.idx ?? 2
        return b.playbook.first { $0.cat == leastKind } ?? b.playbook[0]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ---- header row ----
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(b.greeting()).font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
                        HStack(spacing: 8) {
                            Chip(icon: "shield.lefthalf.filled", text: Brain.positions[min(b.position, Brain.positions.count - 1)], tint: P.orange2)
                            Text(weekdayLine()).font(.system(size: 13)).foregroundColor(P.ash)
                        }
                    }
                    Spacer()
                    Button { b.tab = 4 } label: {
                        Image("helmet").resizable().scaledToFit().frame(width: 52, height: 52)
                            .padding(6)
                            .background(Circle().fill(P.panel).overlay(Circle().stroke(P.stroke, lineWidth: 1)))
                    }
                }
                .padding(.top, 8)

                // ---- streak + weekly goal hero ----
                Panel {
                    HStack(spacing: 16) {
                        // streak
                        VStack(spacing: 2) {
                            ZStack {
                                Image(systemName: "flame.fill").font(.system(size: 54))
                                    .foregroundStyle(LinearGradient(colors: [P.gold, P.ember], startPoint: .top, endPoint: .bottom))
                                    .shadow(color: P.ember.opacity(0.6), radius: 10)
                                Text("\(b.streak)").font(.system(size: 22, weight: .black)).foregroundColor(.white).offset(y: 4)
                            }
                            Text(b.streak == 1 ? "DAY STREAK" : "DAY STREAK").font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(P.ash)
                        }
                        .frame(width: 92)

                        Rectangle().fill(P.stroke).frame(width: 1, height: 84)

                        // weekly ring
                        Ring(pct: b.weekGoalPct, size: 84, line: 9) {
                            VStack(spacing: 0) {
                                Text("\(b.weekMins)").font(.system(size: 20, weight: .heavy)).foregroundColor(.white)
                                Text("/ \(b.goalMins)m").font(.system(size: 10, weight: .semibold)).foregroundColor(P.ash)
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("THIS WEEK").font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(P.ash)
                            Text("\(b.weekCount) / \(b.goalSess) sessions").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            Text(b.weekGoalPct >= 1 ? "Goal smashed 🔥" : "\(b.goalMins - b.weekMins)m to goal")
                                .font(.system(size: 12)).foregroundColor(b.weekGoalPct >= 1 ? P.ok : P.orange2)
                        }
                        Spacer(minLength: 0)
                    }
                }

                // ---- today's focus (suggested drill) ----
                VStack(alignment: .leading, spacing: 10) {
                    Head(title: "Today's Focus", sub: "Balance your week")
                    Panel {
                        HStack(spacing: 14) {
                            Image("playbook").resizable().scaledToFit().frame(width: 58, height: 58)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.name).font(.system(size: 17, weight: .heavy)).foregroundColor(.white)
                                Text(Brain.kinds[suggestion.cat]).font(.system(size: 12, weight: .semibold)).foregroundColor(Brain.kindTint[suggestion.cat])
                                HStack(spacing: 8) {
                                    Chip(icon: "clock.fill", text: "\(suggestion.minutes)m", tint: P.ash)
                                    Chip(icon: "bolt.fill", text: diffWord(suggestion.difficulty), tint: P.orange)
                                }.padding(.top, 2)
                            }
                            Spacer(minLength: 0)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Button {
                                Haptics.win(); b.logDrill(suggestion)
                            } label: {
                                Text("Log it").font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                                    .padding(.horizontal, 18).padding(.vertical, 9)
                                    .background(Capsule().fill(P.orange))
                            }
                        }
                    }
                }

                // ---- load meter ----
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Training Load").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            Spacer()
                            Text(loadWord(b.loadIndex)).font(.system(size: 13, weight: .bold)).foregroundColor(P.heat(b.loadIndex))
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(P.panel2).frame(height: 12)
                                Capsule().fill(LinearGradient(colors: [P.gold, P.orange, P.ember], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(12, g.size.width * b.loadIndex), height: 12)
                            }
                        }.frame(height: 12)
                        Text("Avg RPE \(String(format: "%.1f", b.avgRpe)) • \(b.weekMins) min logged this week")
                            .font(.system(size: 12)).foregroundColor(P.ash)
                    }
                }

                // ---- recent ----
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Head(title: "Recent")
                        Button("See all") { b.tab = 1 }.font(.system(size: 13, weight: .semibold)).foregroundColor(P.orange)
                    }
                    if b.sorted.isEmpty {
                        Panel { Text("No sessions yet — tap ➕ to log your first.").font(.system(size: 14)).foregroundColor(P.ash) }
                    } else {
                        ForEach(Array(b.sorted.prefix(3))) { s in SessRow(s: s) }
                    }
                }

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func weekdayLine() -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }
}

// shared row, lives here, used in Home + Diary
struct SessRow: View {
    @EnvironmentObject var b: Brain
    var s: Sess
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Brain.kindTint[s.kind].opacity(0.16))
                    .frame(width: 46, height: 46)
                Image(systemName: Brain.kindIcon[s.kind]).font(.system(size: 19, weight: .bold))
                    .foregroundColor(Brain.kindTint[s.kind])
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(s.drill ?? Brain.kinds[s.kind]).font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(s.mins)m").font(.system(size: 12, weight: .semibold)).foregroundColor(P.ash)
                    Text("•").foregroundColor(P.ashDim)
                    Text("RPE \(s.rpe)").font(.system(size: 12, weight: .semibold)).foregroundColor(P.heat(Double(s.rpe) / 10))
                    Text("•").foregroundColor(P.ashDim)
                    Text(b.ago(s.t)).font(.system(size: 12)).foregroundColor(P.ashDim)
                }
            }
            Spacer(minLength: 0)
            Text(Brain.moodFace[s.mood]).font(.system(size: 22))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(P.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(P.stroke, lineWidth: 1)))
    }
}

// little helpers used around home
func diffWord(_ d: Int) -> String { d <= 1 ? "Easy" : (d == 2 ? "Moderate" : "Hard") }
func loadWord(_ x: Double) -> String { x < 0.33 ? "Light" : (x < 0.7 ? "Building" : "High") }
