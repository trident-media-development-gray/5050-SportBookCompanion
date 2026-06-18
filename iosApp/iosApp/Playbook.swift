import SwiftUI

// =====================================================================================
//  PlaybookView — drill library grouped by type, NavigationStack into a detail page.
// =====================================================================================
struct PlaybookView: View {
    @EnvironmentObject var b: Brain

    // group the playbook by category, in category order. inline, of course.
    private var grouped: [(cat: Int, drills: [Drill])] {
        var out: [(Int, [Drill])] = []
        for c in 0..<Brain.kinds.count {
            let d = b.playbook.filter { $0.cat == c }
            if !d.isEmpty { out.append((c, d)) }
        }
        return out.map { (cat: $0.0, drills: $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // banner
                    ZStack(alignment: .bottomLeading) {
                        Image("field").resizable().scaledToFill().frame(height: 120).clipped()
                            .overlay(LinearGradient(colors: [.clear, P.ink], startPoint: .top, endPoint: .bottom))
                        HStack {
                            Image("wordmark").resizable().scaledToFit().frame(height: 26)
                            Spacer()
                        }.padding(14)
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.stroke, lineWidth: 1))

                    Head(title: "The Playbook", sub: "\(b.playbook.count) drills • tap to run one")

                    ForEach(grouped, id: \.cat) { g in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: Brain.kindIcon[g.cat]).font(.system(size: 14, weight: .bold)).foregroundColor(Brain.kindTint[g.cat])
                                Text(Brain.kinds[g.cat]).font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
                            }
                            ForEach(g.drills) { d in
                                NavigationLink { DrillDetail(d: d) } label: { drillRow(d) }
                            }
                        }
                    }
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .background(AppBG())
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .tint(P.orange)
    }

    private func drillRow(_ d: Drill) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Brain.kindTint[d.cat].opacity(0.16)).frame(width: 46, height: 46)
                Image(systemName: Brain.kindIcon[d.cat]).font(.system(size: 18, weight: .bold)).foregroundColor(Brain.kindTint[d.cat])
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(d.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                HStack(spacing: 8) {
                    Text("\(d.minutes)m").font(.system(size: 12, weight: .semibold)).foregroundColor(P.ash)
                    Text("•").foregroundColor(P.ashDim)
                    Text(diffWord(d.difficulty)).font(.system(size: 12, weight: .semibold)).foregroundColor(P.orange)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(P.ashDim)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(P.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(P.stroke, lineWidth: 1)))
    }
}

// ---- detail -------------------------------------------------------------------------
struct DrillDetail: View {
    @EnvironmentObject var b: Brain
    @Environment(\.dismiss) private var dismiss
    var d: Drill
    @State private var logged = false
    @State private var full = false

    private let catArt = ["goalpost", "stars", "playbook", "field", "playbook", "helmet"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    Image(catArt[d.cat]).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 200)
                        .padding(.top, 10)
                    Chip(icon: Brain.kindIcon[d.cat], text: Brain.kinds[d.cat], tint: Brain.kindTint[d.cat])
                }

                Text(d.name).font(.system(size: 26, weight: .heavy)).foregroundColor(.white)
                HStack(spacing: 8) {
                    Chip(icon: "clock.fill", text: "\(d.minutes) min", tint: P.ash)
                    Chip(icon: "bolt.fill", text: diffWord(d.difficulty), tint: P.orange)
                    Chip(icon: "flame.fill", text: "RPE ~\(min(10, d.difficulty * 3))", tint: P.ember)
                }

                Panel { Text(d.detail).font(.system(size: 15)).foregroundColor(Color(0xCDCDD3)).lineSpacing(4) }

                VStack(alignment: .leading, spacing: 10) {
                    Text("COACHING CUES").font(.system(size: 12, weight: .heavy)).tracking(1).foregroundColor(P.ash)
                    ForEach(Array(d.coaching.enumerated()), id: \.offset) { i, cue in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)").font(.system(size: 13, weight: .black)).foregroundColor(.black)
                                .frame(width: 24, height: 24).background(Circle().fill(P.orange))
                            Text(cue).font(.system(size: 15)).foregroundColor(.white)
                            Spacer(minLength: 0)
                        }
                    }
                }

                Button {
                    if b.logDrill(d) {
                        Haptics.win(); logged = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
                    } else {
                        full = true   // today is already maxed out at 24h
                    }
                } label: {
                    HStack {
                        Image(systemName: logged ? "checkmark.circle.fill" : (full ? "exclamationmark.triangle.fill" : "plus.circle.fill"))
                        Text(logged ? "Logged to diary!" : (full ? "Today is full (24h)" : "Log this session"))
                    }
                    .font(.system(size: 17, weight: .heavy)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Capsule().fill(logged ? P.ok : (full ? P.gold : P.orange)))
                }
                .padding(.top, 4)

                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .background(AppBG())
        .navigationBarTitleDisplayMode(.inline)
    }
}
