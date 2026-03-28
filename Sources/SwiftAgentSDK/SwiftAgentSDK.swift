import Foundation

/// Main entry point for the SwiftAgentSDK.
/// Call `SwiftAgentSDK.poll(state:server:)` to start the long-poll loop.
public enum SwiftAgentSDK {

    /// Start polling the agent server for commands.
    /// Must be called from the main actor (typically in your App's init).
    ///
    /// - Parameters:
    ///   - state: The root state object (must conform to AgentDispatchable)
    ///   - server: The server URL, e.g. "http://localhost:9876"
    @MainActor
    public static func poll(state: any AgentDispatchable, server: String) {
        guard let url = URL(string: server) else {
            print("[AgentSDK] Invalid server URL: \(server)")
            return
        }
        let poller = Poller(state: state, serverURL: url)
        // Retain the poller via global storage
        _activePollers.append(poller)
        poller.start()
        print("[AgentSDK] Polling \(server)")
    }
}

private var _activePollers: [Poller] = []
