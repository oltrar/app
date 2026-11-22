import Foundation
import Combine
import WebKit

enum RepeatAction: String, CaseIterable, Identifiable {
    case tap = "Tap location"
    case swipeUp = "Swipe up"
    case swipeDown = "Swipe down"
    case swipeLeft = "Swipe left"
    case swipeRight = "Swipe right"

    var id: String { rawValue }
}

@MainActor
final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var pageReady = false
    @Published private(set) var running = false
    @Published private(set) var count = 0
    @Published var error: String?

    let webView: WKWebView
    private var timer: Timer?
    private var busy = false
    private var generation = 0
    private var repeatLimit = 0
    private var action: RepeatAction = .swipeUp
    private var tapX: Double = 50
    private var tapY: Double = 50

    override init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        loadDemo()
    }

    func loadDemo() {
        stop()
        pageReady = false
        error = nil
        webView.loadHTMLString(DemoPage.html, baseURL: nil)
    }

    func loadWebsite(_ text: String) {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = input.contains("://") ? input : "https://" + input
        guard let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else {
            error = "Enter a valid HTTPS website."
            return
        }
        stop()
        pageReady = false
        error = nil
        webView.load(URLRequest(url: url))
    }

    func start(action: RepeatAction, intervalSeconds: Int, limit: Int, x: Double, y: Double) {
        guard pageReady else { error = "Load a page first."; return }
        guard intervalSeconds >= 1 && limit >= 0 && (0...100).contains(x)
                && (0...100).contains(y) else {
            error = "Invalid repeat settings."
            return
        }
        stop()
        self.action = action
        tapX = x
        tapY = y
        repeatLimit = limit
        count = 0
        error = nil
        running = true
        let token = generation
        Task { await perform(token: token) }
        timer = Timer.scheduledTimer(withTimeInterval: Double(intervalSeconds), repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in await self?.perform(token: token) }
        }
    }

    func stop() {
        generation += 1
        timer?.invalidate()
        timer = nil
        running = false
    }

    private func perform(token: Int) async {
        guard running && token == generation && !busy && pageReady else { return }
        busy = true
        defer { busy = false }
        do {
            let script: String
            switch action {
            case .tap:
                // Click a DOM element in *this WKWebView*, not another iOS app.
                script = """
                    (function() {
                        const node = document.elementFromPoint(
                            innerWidth * \(tapX / 100.0),
                            innerHeight * \(tapY / 100.0)
                        );
                        if (!node) return false;
                        node.click();
                        return true;
                    })()
                    """
            case .swipeUp, .swipeDown, .swipeLeft, .swipeRight:
                let horizontal: Double = action == .swipeLeft ? 0.7 :
                    action == .swipeRight ? -0.7 : 0
                let vertical: Double = action == .swipeUp ? 0.7 :
                    action == .swipeDown ? -0.7 : 0
                script = """
                    (function() {
                        const dx = innerWidth * \(horizontal);
                        const dy = innerHeight * \(vertical);
                        let node = document.elementFromPoint(innerWidth / 2, innerHeight / 2);
                        while (node && node !== document.body && node !== document.documentElement) {
                            if ((dx && node.scrollWidth > node.clientWidth + 2) ||
                                (dy && node.scrollHeight > node.clientHeight + 2)) {
                                node.scrollBy(dx, dy);
                                return true;
                            }
                            node = node.parentElement;
                        }
                        window.scrollBy(dx, dy);
                        return true;
                    })()
                    """
            }
            let result = try await webView.evaluateJavaScript(script)
            guard running && token == generation else { return }
            if action == .tap, let succeeded = result as? Bool, !succeeded {
                throw NSError(domain: "LoopMate", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No element at the tap point."])
            }
            count += 1
            if repeatLimit > 0 && count >= repeatLimit { stop() }
        } catch {
            guard token == generation else { return }
            self.error = error.localizedDescription
            stop()
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        stop()
        pageReady = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        pageReady = false
        self.error = error.localizedDescription
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased() ?? ""
        decisionHandler(["https", "about", "data"].contains(scheme) ? .allow : .cancel)
    }
}
