import SwiftUI

// =====================================================================================
//  ProfileView — identity + weekly goals + the nuke button. binds straight to the brain.
// =====================================================================================
struct ProfileView: View {
    @EnvironmentObject var b: Brain
    @State private var askReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // ---- avatar / identity ----
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(RadialGradient(colors: [P.orange.opacity(0.35), .clear], center: .center, startRadius: 4, endRadius: 70))
                            .frame(width: 140, height: 140)
                        Image("helmet").resizable().scaledToFit().frame(width: 120, height: 120)
                            .shadow(color: P.ember.opacity(0.5), radius: 16)
                    }
                    TextField("", text: $b.athlete, prompt: Text("Your name").foregroundColor(P.ashDim))
                        .multilineTextAlignment(.center)
                        .font(.system(size: 22, weight: .heavy)).foregroundColor(.white)
                    Text("\(b.totalSess) sessions • \(b.streak) day streak").font(.system(size: 13)).foregroundColor(P.ash)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                // ---- position ----
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("POSITION").font(.system(size: 12, weight: .heavy)).tracking(1).foregroundColor(P.ash)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(0..<Brain.positions.count, id: \.self) { i in
                                    Button { Haptics.tap(); b.position = i } label: {
                                        Text(Brain.positions[i]).font(.system(size: 14, weight: .heavy))
                                            .foregroundColor(b.position == i ? .black : P.ash)
                                            .frame(width: 54, height: 40)
                                            .background(RoundedRectangle(cornerRadius: 12).fill(b.position == i ? P.orange : P.panel2))
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- weekly goals ----
                Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("WEEKLY GOALS").font(.system(size: 12, weight: .heavy)).tracking(1).foregroundColor(P.ash)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("Minutes").font(.system(size: 14, weight: .semibold)).foregroundColor(.white); Spacer()
                                Text("\(b.goalMins)m").font(.system(size: 14, weight: .bold)).foregroundColor(P.orange) }
                            Slider(value: Binding(get: { Double(b.goalMins) }, set: { b.goalMins = Int($0) }), in: 60...600, step: 30).tint(P.orange)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("Sessions").font(.system(size: 14, weight: .semibold)).foregroundColor(.white); Spacer()
                                Text("\(b.goalSess)").font(.system(size: 14, weight: .bold)).foregroundColor(P.orange) }
                            HStack(spacing: 10) {
                                HStack(spacing: 3) {
                                    ForEach(0..<b.goalSess, id: \.self) { _ in
                                        Circle().fill(P.orange).frame(width: 8, height: 8)
                                    }
                                }
                                Spacer(minLength: 8)
                                Stepper("", value: $b.goalSess, in: 1...14).labelsHidden().fixedSize()
                            }
                        }
                    }
                }

                // ---- about ----
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow("Version", "1.0 (1)")
                        Divider().overlay(P.stroke)
                        infoRow("Bundle", "sport.diary.companion.iosapp")
                        Divider().overlay(P.stroke)
                        HStack {
                            Image("stars").resizable().scaledToFit().frame(height: 28)
                            Text("Train like it's the fourth quarter.").font(.system(size: 13, weight: .medium)).foregroundColor(P.ash)
                            Spacer()
                        }
                    }
                }

                // ---- danger ----
                Button(role: .destructive) { askReset = true } label: {
                    Label("Reset all data", systemImage: "trash.fill")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(P.ember)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(P.ember.opacity(0.10)).overlay(RoundedRectangle(cornerRadius: 14).stroke(P.ember.opacity(0.3), lineWidth: 1)))
                }

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .alert("Reset everything?", isPresented: $askReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { withAnimation { b.wipe(); b.tab = 0 } }
        } message: {
            Text("This wipes your diary, goals and streak. Can't be undone.")
        }
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(.system(size: 14)).foregroundColor(P.ash); Spacer()
            Text(v).font(.system(size: 14, weight: .semibold)).foregroundColor(.white) }
    }
}
