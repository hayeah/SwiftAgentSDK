import SwiftUI

/// PreferenceKey that collects Anchor<CGRect> values from all .agentID() tagged views.
/// Keyed by the qualified ID (e.g. "ContentView.greeting").
public struct AgentViewFrameKey: PreferenceKey {
    public static var defaultValue: [String: Anchor<CGRect>] = [:]

    public static func reduce(
        value: inout [String: Anchor<CGRect>],
        nextValue: () -> [String: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
