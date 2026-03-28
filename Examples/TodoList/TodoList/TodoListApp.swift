import SwiftUI
import SwiftUITap
#if canImport(AppKit)
import AppKit
#endif

// Single instance so the poller and views share the same state
private let sharedAppState = AppState()

@main
struct TodoListApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sharedAppState)
                .agentInspectable()
                .onAppear {
                    #if DEBUG
                    let serverURL = ProcessInfo.processInfo.environment["AGENTSDK_URL"]
                        ?? "http://localhost:9876"
                    SwiftUITap.poll(state: sharedAppState, server: serverURL)
                    #endif
                }
        }
    }

    init() {
        #if canImport(AppKit)
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }
}
