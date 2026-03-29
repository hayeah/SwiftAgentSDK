import SwiftUI
import SwiftUITap

private let sharedAppState = AppState()

@main
struct TodoListiOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sharedAppState)
                .tapInspectable()
                .onAppear {
                    #if DEBUG
                    let serverURL = ProcessInfo.processInfo.environment["AGENTSDK_URL"]
                        ?? "http://localhost:9876"
                    SwiftUITap.poll(state: sharedAppState, server: serverURL)
                    #endif
                }
        }
    }
}
