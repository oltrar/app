import SwiftUI
import WebKit

struct BrowserWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct RepeaterView: View {
    @ObservedObject var browser: BrowserModel
    @State private var url = ""
    @State private var action = RepeatAction.swipeUp
    @State private var intervalText = "10"
    @State private var limitText = "0"
    @State private var xText = "50"
    @State private var yText = "50"
    @State private var picking = false

    private var validSettings: (Int, Int, Double, Double)? {
        guard let seconds = Int(intervalText), seconds > 0,
              let limit = Int(limitText), limit >= 0,
              let x = Double(xText), x.isFinite, (0...100).contains(x),
              let y = Double(yText), y.isFinite, (0...100).contains(y) else { return nil }
        return (seconds, limit, x, y)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(browser.running ? "Repeating" : "Ready", systemImage: "repeat")
                            .font(.headline)
                        Spacer()
                        Text("Actions: \(browser.count)").monospacedDigit()
                    }
                    HStack {
                        TextField("https://example.com", text: $url)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .disabled(browser.running)
                            .onSubmit { browser.loadWebsite(url) }
                        Button("Go") { browser.loadWebsite(url) }
                            .disabled(browser.running)
                    }
                    Button("Open offline demo") { browser.loadDemo() }
                        .disabled(browser.running)
                    GeometryReader { proxy in
                        BrowserWebView(webView: browser.webView)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                if picking {
                                    Color.indigo.opacity(0.25)
                                        .overlay {
                                            Text("Tap where you want to click")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        }
                                        .contentShape(Rectangle())
                                        .gesture(DragGesture(minimumDistance: 0).onEnded { gesture in
                                            xText = String(format: "%.1f", min(100, max(0,
                                                gesture.location.x / max(1, proxy.size.width) * 100)))
                                            yText = String(format: "%.1f", min(100, max(0,
                                                gesture.location.y / max(1, proxy.size.height) * 100)))
                                            picking = false
                                        })
                                }
                            }
                    }
                    .frame(height: 340)
                    Picker("Action", selection: $action) {
                        ForEach(RepeatAction.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(browser.running)

                    if action == .tap {
                        Button(picking ? "Cancel picking" : "Pick point in browser") {
                            picking.toggle()
                        }
                        .disabled(browser.running)
                        HStack {
                            numericField("X %", text: $xText)
                            numericField("Y %", text: $yText)
                        }
                    }
                    HStack {
                        numericField("Interval (seconds)", text: $intervalText)
                        numericField("Repeats (0 = unlimited)", text: $limitText)
                    }
                    HStack {
                        Button {
                            guard let config = validSettings else { return }
                            picking = false
                            browser.start(action: action, intervalSeconds: config.0,
                                          limit: config.1, x: config.2, y: config.3)
                        } label: {
                            Label("Start", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(browser.running || !browser.pageReady || validSettings == nil)

                        Button {
                            browser.stop()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!browser.running)
                    }
                    if let error = browser.error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                    Text("iOS repeats webpage clicks and scrolling only inside this browser while the app is open. It cannot control other apps. Some sites reject synthetic clicks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("LoopMate iOS")
        }
    }

    private func numericField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption)
            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .disabled(browser.running)
        }
        .frame(maxWidth: .infinity)
    }
}
