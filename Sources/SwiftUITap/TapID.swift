import SwiftUI

// MARK: - TapDebugLayout

/// Transparent Layout wrapper that records proposed/reported sizes.
/// Always on — intercepts the real sizeThatFits, no extra layout passes.
public struct TapDebugLayout: Layout {
    let id: String

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        subviews[0].sizeThatFits(proposal)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let reported = subviews[0].sizeThatFits(proposal)
        subviews[0].place(at: bounds.origin, proposal: proposal)
        // Record in placeSubviews — this is the final layout pass, not a probe.
        // placeSubviews runs on the main thread as part of the render pipeline.
        Task { @MainActor in
            TapViewStore.active?.layoutInfo[id] = TapViewStore.LayoutInfo(
                proposedWidth: proposal.width,
                proposedHeight: proposal.height,
                reported: reported
            )
        }
    }
}

// MARK: - .tapID() modifier

struct TapIDModifier: ViewModifier {
    let qualifiedID: String

    func body(content: Content) -> some View {
        TapDebugLayout(id: qualifiedID) {
            content
        }
        .transformAnchorPreference(key: TapViewFrameKey.self, value: .bounds) { existing, anchor in
            existing[qualifiedID] = anchor
        }
        .accessibilityIdentifier(qualifiedID)
    }
}

extension View {
    /// Tag a view for agent inspection.
    /// The ID is auto-prefixed with the source filename (e.g. "ContentView.greeting").
    public func tapID(_ id: String, file: String = #fileID) -> some View {
        let stem = file
            .split(separator: "/").last
            .flatMap { $0.split(separator: ".").first }
            .map(String.init) ?? ""
        let qualifiedID = stem.isEmpty ? id : "\(stem).\(id)"
        return modifier(TapIDModifier(qualifiedID: qualifiedID))
    }
}
