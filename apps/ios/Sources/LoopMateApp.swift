import SwiftUI

@main
struct LoopMateApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var browser = BrowserModel()

    var body: some Scene {
        WindowGroup {
            RepeaterView(browser: browser)
                .onChange(of: scenePhase) { phase in
                    if phase != .active { browser.stop() }
                }
        }
    }
}
