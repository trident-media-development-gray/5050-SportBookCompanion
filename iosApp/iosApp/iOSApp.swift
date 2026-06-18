import SwiftUI

@main
struct SportBookCompanionApp: App {
    @StateObject private var brain = Brain.shared

    init() {
        // force the few UIKit bits that leak through to match the theme
        UINavigationBar.appearance().tintColor = UIColor(P.orange)
        UITableView.appearance().backgroundColor = .clear
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(brain)
                .preferredColorScheme(.dark)
                .tint(P.orange)
        }
    }
}
