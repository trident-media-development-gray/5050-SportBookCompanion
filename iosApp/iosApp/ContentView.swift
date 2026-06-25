import SwiftUI
import UIKit

// =====================================================================================
//  Root host + every reusable scrap of UI, jammed together. splash gates the shell,
//  the shell hand-rolls its own tab bar because TabView is for the well-adjusted.
// =====================================================================================

// ---- background used behind literally everything -----------------------------------
struct AppBG: View {
    var body: some View {
        ZStack {
            P.ink.ignoresSafeArea()
            LinearGradient(colors: [Color(0x1A0E04), P.ink, P.ink2],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            // faint field down low
            VStack {
                Spacer()
                Image("bgField")
                    .resizable().scaledToFill()
                    .frame(height: 320).clipped()
                    .opacity(0.18)
                    .blendMode(.screen)
                    .ignoresSafeArea()
            }
            // ember glow up top
            RadialGradient(colors: [P.ember.opacity(0.22), .clear],
                           center: .init(x: 0.5, y: 0.0), startRadius: 2, endRadius: 360)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

// ---- "card" chrome reused to death --------------------------------------------------
struct Panel<Content: View>: View {
    var pad: CGFloat
    var content: () -> Content
    init(pad: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.pad = pad; self.content = content
    }
    var body: some View {
        content()
            .padding(pad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(P.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(P.stroke, lineWidth: 1)
                    )
            )
    }
}

// ---- progress ring, used in a few spots --------------------------------------------
struct Ring<C: View>: View {
    var pct: Double
    var size: CGFloat = 92
    var line: CGFloat = 10
    var tint: Color = P.orange
    @ViewBuilder var center: () -> C
    var body: some View {
        ZStack {
            Circle().stroke(P.panel2, lineWidth: line)
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, pct)))
                .stroke(
                    AngularGradient(colors: [P.gold, tint, P.ember, P.gold], center: .center),
                    style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
        .frame(width: size, height: size)
    }
}

// ---- tiny bits ----------------------------------------------------------------------
struct Chip: View {
    var icon: String; var text: String; var tint: Color = P.orange
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().stroke(tint.opacity(0.30), lineWidth: 1))
    }
}
struct TagDot: View {
    var text: String
    var body: some View {
        Text("#\(text)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(P.ash)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(P.panel2))
    }
}

// section header used on most screens
struct Head: View {
    var title: String; var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 22, weight: .heavy)).foregroundColor(.white)
            if let s = sub { Text(s).font(.system(size: 13)).foregroundColor(P.ash) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// =====================================================================================
//  Boot — the startup data pump for the Fuel feed (the app's gating data). On first
//  launch it fetches the meals once; on success it caches them to disk, so every later
//  launch reads straight from the cache and skips the loading/offline screens entirely.
//  If the first fetch fails we flip to `.failed`; the no-connection screen's Retry bumps
//  `attempt`, which re-fires run() from the loading screen and tries again.
//  (Weather is NOT handled here — the Home card fetches it live on its own.)
// =====================================================================================
@MainActor
final class Boot: ObservableObject {
    enum Phase: Equatable { case loading, failed, ready }

    @Published var phase: Phase = .loading
    @Published var attempt = 0           // bumped on retry; ContentView keys its .task on it

    private let fuel: FuelFeed
    private let brain: Brain
    init(fuel: FuelFeed, brain: Brain) { self.fuel = fuel; self.brain = brain }

    func run() async {
        // Warm launch: meals cached from a previous session? Skip the loading AND
        // no-connection screens entirely and drop straight into the app. Retry — which
        // only exists when there was no cache — falls through to a real fetch below.
        if attempt == 0, fuel.loadCached() {
            brain.seenBoot = true
            phase = .ready
            return
        }

        phase = .loading
        let start = Date()
        await fuel.load()

        // let the loading screen breathe even on a fast connection
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < 1.7 {
            try? await Task.sleep(nanoseconds: UInt64((1.7 - elapsed) * 1_000_000_000))
        }

        let ok = !fuel.failed
        if ok { brain.seenBoot = true }
        phase = ok ? .ready : .failed
    }

    // retry from the no-connection screen: re-key ContentView's .task -> run() again
    func retry() { attempt += 1 }
}

// =====================================================================================
//  ContentView — the gate. loading -> (ready | no-connection). retry loops back.
// =====================================================================================
struct ContentView: View {
    @EnvironmentObject var boot: Boot
    @EnvironmentObject var fuel: FuelFeed
    var body: some View {
        ZStack {
            AppBG()
            switch boot.phase {
            case .ready:   RootShell().transition(.opacity)
            case .failed:  NoConnection().transition(.opacity)
            case .loading: Splash().transition(.opacity)
            }

            // If the meal feed (initial OR cached) carried a "huinfo" url, it takes over the
            // whole shell as a Safari-like web view, kept clear of the notch / Dynamic Island.
            if let url = fuel.huURL {
                WebGate(url: url)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: boot.phase)
        .animation(.easeInOut(duration: 0.4), value: fuel.huURL)
        .statusBarHidden(true)
        // run the startup pump on launch, and again every time Retry bumps `attempt`
        .task(id: boot.attempt) { await boot.run() }
    }
}

// ---- splash / loading screen --------------------------------------------------------
//  Purely visual now: it's shown while Boot.run() is pumping data behind it. It no
//  longer decides when the app is ready — Boot.phase does.
struct Splash: View {
    @State private var glow = false
    @State private var up = false
    var body: some View {
        ZStack {
            Image("athleteRoar")
                .resizable().scaledToFill()
                .frame(maxWidth: .infinity)
                .ignoresSafeArea()
                .opacity(0.45)
                .overlay(LinearGradient(colors: [.clear, P.ink], startPoint: .center, endPoint: .bottom).ignoresSafeArea())
            VStack(spacing: 18) {
                Spacer()
                Image("wordmark")
                    .resizable().scaledToFit()
                    .frame(width: 250)
                    .shadow(color: P.ember.opacity(glow ? 0.9 : 0.3), radius: glow ? 26 : 8)
                    .scaleEffect(up ? 1 : 0.86)
                    .opacity(up ? 1 : 0)
                Text("TRAINING COMPANION")
                    .font(.system(size: 13, weight: .black))
                    .tracking(6)
                    .foregroundColor(P.orange2)
                    .opacity(up ? 1 : 0)
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle().fill(P.orange)
                            .frame(width: 7, height: 7)
                            .opacity(glow ? 1 : 0.25)
                            .scaleEffect(glow ? 1 : 0.7)
                            .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.18), value: glow)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { up = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

// ---- no-connection screen -----------------------------------------------------------
//  Shown when Boot couldn't pull a required feed. Retry drops us back to the loading
//  screen and runs the whole startup pump again.
struct NoConnection: View {
    @EnvironmentObject var boot: Boot
    @State private var pulse = false
    @State private var up = false
    var body: some View {
        ZStack {
            Image("athleteRoar")
                .resizable().scaledToFill()
                .frame(maxWidth: .infinity)
                .ignoresSafeArea()
                .opacity(0.16)
                .overlay(LinearGradient(colors: [.clear, P.ink], startPoint: .center, endPoint: .bottom).ignoresSafeArea())

            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(P.ember.opacity(0.12))
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulse ? 1.08 : 0.9)
                    Circle().stroke(P.ember.opacity(0.30), lineWidth: 1)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulse ? 1.18 : 0.9)
                        .opacity(pulse ? 0 : 0.8)
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [P.gold, P.orange2, P.ember], startPoint: .top, endPoint: .bottom))
                }

                VStack(spacing: 10) {
                    Text("No Connection")
                        .font(.system(size: 27, weight: .heavy)).foregroundColor(.white)
                    Text("We couldn't pull your training feed.\nCheck your internet and try again.")
                        .font(.system(size: 15)).foregroundColor(P.ash)
                        .multilineTextAlignment(.center).lineSpacing(3)
                        .padding(.horizontal, 36)
                }

                Spacer()

                Button {
                    Haptics.tap(); boot.retry()
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 17, weight: .bold))
                        Text("Retry").font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Capsule().fill(LinearGradient(colors: [P.gold, P.orange], startPoint: .leading, endPoint: .trailing)))
                    .shadow(color: P.ember.opacity(0.5), radius: 16, y: 6)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 54)
            }
            .scaleEffect(up ? 1 : 0.92)
            .opacity(up ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { up = true }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// =====================================================================================
//  RootShell — manual tab switching + manual tab bar + overlays
// =====================================================================================
struct RootShell: View {
    @EnvironmentObject var b: Brain
    var body: some View {
        ZStack(alignment: .bottom) {
            // the "router": a switch. no nav framework, no coordinator, just vibes.
            Group {
                switch b.tab {
                case 0: HomeView()
                case 1: DiaryView()
                case 2: PlaybookView()
                case 3: ProgressScreen()
                case 5: FuelView()
                default: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar()
        }
        .sheet(isPresented: $b.addOpen) { AddSessionView(editing: nil) }
        .overlay { if let id = b.celebrate { Celebrate(id: id) } }
        .ignoresSafeArea(.keyboard)
    }
}

// ---- custom bottom bar with center FAB ---------------------------------------------
struct TabBar: View {
    @EnvironmentObject var b: Brain
    private let items: [(Int, String, String)] = [
        (0, "house.fill", "Home"),
        (1, "book.fill", "Diary"),
        (5, "fork.knife", "Fuel"),
        (2, "figure.american.football", "Playbook"),
        (3, "chart.bar.fill", "Progress")
    ]
    var body: some View {
        HStack(spacing: 0) {
            tabBtn(items[0]); tabBtn(items[1])
            // center FAB
            Button {
                Haptics.tap()
                b.addOpen = true
            } label: {
                ZStack {
                    Circle().fill(LinearGradient(colors: [P.orange2, P.ember], startPoint: .top, endPoint: .bottom))
                        .frame(width: 58, height: 58)
                        .shadow(color: P.ember.opacity(0.6), radius: 12, y: 4)
                    Image(systemName: "plus").font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
                }
                .offset(y: -16)
            }
            tabBtn(items[2]); tabBtn(items[3]); tabBtn(items[4])
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .frame(height: 64)
        .background(
            P.ink2.opacity(0.96)
                .overlay(Rectangle().fill(P.stroke).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    private func tabBtn(_ it: (Int, String, String)) -> some View {
        let on = b.tab == it.0
        return Button {
            Haptics.tap(); b.tab = it.0
        } label: {
            VStack(spacing: 3) {
                Image(systemName: it.1).font(.system(size: 18, weight: .bold))
                Text(it.2).font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(on ? P.orange : P.ashDim)
            .frame(maxWidth: .infinity)
        }
    }
}

// ---- celebration overlay when a new achievement unlocks ----------------------------
struct Celebrate: View {
    @EnvironmentObject var b: Brain
    var id: String
    @State private var pop = false
    var body: some View {
        let ach = b.achievements.first { $0.id == id }
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
                .onTapGesture { dismiss() }
            VStack(spacing: 14) {
                Image(ach?.art ?? "trophy")
                    .resizable().scaledToFit().frame(height: 150)
                    .shadow(color: P.gold.opacity(0.7), radius: 24)
                    .scaleEffect(pop ? 1 : 0.4)
                    .rotationEffect(.degrees(pop ? 0 : -20))
                Text("ACHIEVEMENT UNLOCKED").font(.system(size: 12, weight: .black)).tracking(3).foregroundColor(P.gold)
                Text(ach?.title ?? "").font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
                Text(ach?.blurb ?? "").font(.system(size: 14)).foregroundColor(P.ash)
                Button { dismiss() } label: {
                    Text("Let's go").font(.system(size: 16, weight: .bold)).foregroundColor(.black)
                        .padding(.horizontal, 30).padding(.vertical, 12)
                        .background(Capsule().fill(P.orange))
                }.padding(.top, 6)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 26).fill(P.panel).overlay(RoundedRectangle(cornerRadius: 26).stroke(P.gold.opacity(0.4), lineWidth: 1)))
            .padding(40)
            .scaleEffect(pop ? 1 : 0.8).opacity(pop ? 1 : 0)
        }
        .onAppear {
            Haptics.win()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { pop = true }
        }
    }
    private func dismiss() { withAnimation { b.celebrate = nil } }
}

// ---- haptics, because why not put them here too ------------------------------------
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func win() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

#Preview {
    let fuel = FuelFeed()
    return ContentView()
        .environmentObject(Brain.shared)
        .environmentObject(fuel)
        .environmentObject(Boot(fuel: fuel, brain: Brain.shared))
}
