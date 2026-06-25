import SwiftUI

// =====================================================================================
//  DrillTimer — a configurable work/rest interval timer. New in v1.1. Set it up, hit
//  start, and run your reps with a big countdown + haptic cues on every phase change.
// =====================================================================================

private enum Phase { case ready, work, rest, done }

struct DrillTimer: View {
    @Environment(\.dismiss) private var dismiss

    // ---- config (edited while idle) ----
    @State private var workSec = 30
    @State private var restSec = 15
    @State private var rounds  = 8

    // ---- runtime ----
    @State private var phase: Phase = .ready
    @State private var remaining = 30
    @State private var round = 1
    @State private var running = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppBG()
            VStack(spacing: 24) {
                // header
                HStack {
                    Text("Drill Timer").font(.system(size: 22, weight: .heavy)).foregroundColor(.white)
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 26)).foregroundColor(P.ashDim) }
                }.padding(.top, 8)

                Spacer()

                // the dial
                ZStack {
                    Circle().stroke(P.panel2, lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: dialPct)
                        .stroke(phaseColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.25), value: remaining)
                    VStack(spacing: 6) {
                        Text(phaseWord).font(.system(size: 14, weight: .black)).tracking(3).foregroundColor(phaseColor)
                        Text("\(remaining)").font(.system(size: 76, weight: .black)).foregroundColor(.white).monospacedDigit()
                        Text(phase == .done ? "Nice work" : "Round \(min(round, rounds)) / \(rounds)")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(P.ash)
                    }
                }
                .frame(width: 280, height: 280)

                Spacer()

                if phase == .ready { setup } else { controls }
            }
            .padding(.horizontal, 20)
        }
        .onReceive(tick) { _ in step() }
    }

    // ---- idle setup controls ----
    private var setup: some View {
        VStack(spacing: 16) {
            stepperRow("WORK", "\(workSec)s", P.ember) { workSec = max(5,  workSec - 5) } up: { workSec = min(600, workSec + 5) }
            stepperRow("REST", "\(restSec)s", P.ok)    { restSec = max(0,  restSec - 5) } up: { restSec = min(600, restSec + 5) }
            stepperRow("ROUNDS", "\(rounds)", P.orange) { rounds = max(1, rounds - 1) } up: { rounds = min(30, rounds + 1) }
            Button { start() } label: {
                Label("Start", systemImage: "play.fill").font(.system(size: 18, weight: .heavy)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Capsule().fill(P.orange))
            }.padding(.top, 4)
        }
    }

    // ---- running controls ----
    private var controls: some View {
        HStack(spacing: 14) {
            Button { reset() } label: {
                Label("Reset", systemImage: "arrow.counterclockwise").font(.system(size: 16, weight: .bold)).foregroundColor(P.ash)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Capsule().fill(P.panel))
            }
            if phase != .done {
                Button { running.toggle(); Haptics.tap() } label: {
                    Label(running ? "Pause" : "Resume", systemImage: running ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .heavy)).foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Capsule().fill(P.orange))
                }
            }
        }
    }

    private func stepperRow(_ label: String, _ value: String, _ tint: Color,
                            down: @escaping () -> Void, up: @escaping () -> Void) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: .heavy)).tracking(1).foregroundColor(P.ash).frame(width: 80, alignment: .leading)
            Spacer()
            Button { Haptics.tap(); down() } label: { Image(systemName: "minus.circle.fill").font(.system(size: 30)).foregroundColor(tint) }
            Text(value).font(.system(size: 20, weight: .black)).foregroundColor(.white).frame(width: 70).monospacedDigit()
            Button { Haptics.tap(); up() } label: { Image(systemName: "plus.circle.fill").font(.system(size: 30)).foregroundColor(tint) }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(P.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(P.stroke, lineWidth: 1)))
    }

    // ---- engine -----------------------------------------------------------------------
    private var phaseWord: String {
        switch phase { case .ready: return "READY"; case .work: return "WORK"; case .rest: return "REST"; case .done: return "DONE" }
    }
    private var phaseColor: Color {
        switch phase { case .ready: return P.ash; case .work: return P.ember; case .rest: return P.ok; case .done: return P.gold }
    }
    private var dialPct: CGFloat {
        let total = phase == .rest ? restSec : workSec
        return total <= 0 ? 0 : CGFloat(remaining) / CGFloat(total)
    }

    private func start() {
        round = 1; phase = .work; remaining = workSec; running = true; Haptics.win()
    }
    private func reset() {
        running = false; phase = .ready; round = 1; remaining = workSec
    }
    private func step() {
        guard running, phase != .ready, phase != .done else { return }
        if remaining > 1 { remaining -= 1; return }
        // phase boundary
        if phase == .work {
            if restSec > 0 { phase = .rest; remaining = restSec; Haptics.tap() }
            else { advanceRound() }
        } else if phase == .rest {
            advanceRound()
        }
    }
    private func advanceRound() {
        if round >= rounds { phase = .done; running = false; remaining = 0; Haptics.win() }
        else { round += 1; phase = .work; remaining = workSec; Haptics.win() }
    }
}
