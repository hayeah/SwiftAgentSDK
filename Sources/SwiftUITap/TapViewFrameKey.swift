import SwiftUI

/// PreferenceKey that collects Anchor<CGRect> values from all .tapID() tagged views.
/// Keyed by the qualified ID (e.g. "ContentView.greeting").
public struct TapViewFrameKey: PreferenceKey {
    public static var defaultValue: [String: Anchor<CGRect>] = [:]

    public static func reduce(
        value: inout [String: Anchor<CGRect>],
        nextValue: () -> [String: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
