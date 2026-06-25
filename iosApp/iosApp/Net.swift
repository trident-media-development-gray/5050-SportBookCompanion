import Foundation
import SwiftUI
import UIKit
import WebKit

// =====================================================================================
//  Net — the one chokepoint every network call goes through. Exists for a single
//  reason: stamp the system's real browser User-Agent on EVERY request (weather +
//  fuel feed alike), so public endpoints treat us like Safari, not a no-name URLSession.
// =====================================================================================
enum NetError: Error { case badURL, http }

enum Net {
    // Read the live WebKit User-Agent once, lazily, off the actual system — no baked-in
    // string. Falls back to a UA derived from the running device if WebKit won't answer.
    static let userAgent: String = resolveUA()

    private static func resolveUA() -> String {
        let read: () -> String? = { WKWebView().value(forKey: "userAgent") as? String }
        let ua = Thread.isMainThread ? read() : DispatchQueue.main.sync(execute: read)
        return ua ?? deviceUA
    }

    // fallback still pulled from the device at runtime (OS version is not hardcoded)
    private static var deviceUA: String {
        let osv = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(osv) like Mac OS X) " +
               "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    }

    // GET -> raw bytes. caller decodes. throws on bad status so retries can show UI.
    static func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NetError.http
        }
        return data
    }
}

// =====================================================================================
//  WebView / WebGate — a Safari-like WKWebView host. Surfaces a "huinfo" url tacked onto
//  the meal feed. Wired with back/forward swipe navigation so it behaves like Safari, and
//  hosted by WebGate so it stays clear of the notch / Dynamic Island (top safe area only).
// =====================================================================================
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = true   // Safari-style swipe back / forward
        web.allowsLinkPreview = true                     // peek/pop on long-press, like Safari
        web.customUserAgent = Net.userAgent              // same Safari UA the rest of the app rides
        // SwiftUI already insets us for the safe area; don't let the scroll view double-inset.
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.alwaysBounceVertical = true
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}
}

struct WebGate: View {
    let url: URL
    var body: some View {
        ZStack {
            // black fills everything (including behind the notch); the web view sits below it
            Color.black.ignoresSafeArea()
            WebView(url: url)
                // reach the bottom edge / home indicator, but keep the top under the safe
                // area so page content is never drawn behind the notch / Dynamic Island.
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
