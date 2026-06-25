import SwiftUI

@main
struct SportBookCompanionApp: App {
    @StateObject private var brain = Brain.shared
    @StateObject private var fuel: FuelFeed
    @StateObject private var boot: Boot

    init() {
        // force the few UIKit bits that leak through to match the theme
        UINavigationBar.appearance().tintColor = UIColor(P.orange)
        UITableView.appearance().backgroundColor = .clear
        // one FuelFeed instance, shared by the feed view AND the startup pump
        let f = FuelFeed()
        _fuel = StateObject(wrappedValue: f)
        _boot = StateObject(wrappedValue: Boot(fuel: f, brain: Brain.shared))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(brain)
                .environmentObject(fuel)
                .environmentObject(boot)
                .preferredColorScheme(.dark)
                .tint(P.orange)
        }
    }
}
