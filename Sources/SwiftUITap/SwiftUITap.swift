import Foundation

/// Main entry point for SwiftUITap.
/// Call `SwiftUITap.poll(state:server:)` to start the long-poll loop.
public enum SwiftUITap {

    /// Start polling the agent server for commands.
    /// Must be called from the main actor (typically in your App's init).
    ///
    /// - Parameters:
    ///   - state: The root state object (must conform to AgentDispatchable)
    ///   - server: The server URL, e.g. "http://localhost:9876"
    @MainActor
    public static func poll(state: any AgentDispatchable, server: String) {
        guard let url = URL(string: server) else {
            print("[SwiftUITap] Invalid server URL: \(server)")
            return
        }
        let poller = Poller(state: state, serverURL: url)
        // Retain the poller via global storage
        _activePollers.append(poller)
        poller.start()
        print("[SwiftUITap] Polling \(server)")
    }
}

private var _activePollers: [Poller] = []
