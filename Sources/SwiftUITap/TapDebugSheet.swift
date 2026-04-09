import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Public API

extension View {
    /// Install a debug sheet that opens on a 3-finger long press anywhere
    /// in the app, or programmatically via `SwiftUITap.debug.present()`.
    /// Wrap your app's root view (typically alongside `.tapInspectable()`).
    ///
    /// On non-UIKit platforms this is a no-op.
    public func tapDebugSheet() -> some View {
        modifier(TapDebugSheetModifier())
    }
}

extension SwiftUITap {
    /// Global controller for the debug sheet. Call `present()` to open it
    /// from anywhere — useful for agents/tests that can't synthesize a
    /// 3-finger long press.
    public static var debug: TapDebugController { TapDebugController.shared }
}

// MARK: - Controller

@Observable
public final class TapDebugController: @unchecked Sendable {
    public static let shared = TapDebugController()

    public var isPresented: Bool = false

    public func present() { isPresented = true }
    public func dismiss() { isPresented = false }

    private init() {}
}

// MARK: - Modifier

struct TapDebugSheetModifier: ViewModifier {
    @State private var controller = TapDebugController.shared

    func body(content: Content) -> some View {
        // Explicit read so the @Observable observation tracking registers
        // this body as a dependent of `isPresented`. SwiftUI's sheet binding
        // alone is not always enough to set up observation.
        let _ = controller.isPresented
        @Bindable var controller = controller
        #if canImport(UIKit)
        content
            .background(
                ThreeFingerLongPressGesture { controller.present() }
            )
            .sheet(isPresented: $controller.isPresented) {
                TapDebugView()
            }
        #else
        content
            .sheet(isPresented: $controller.isPresented) {
                TapDebugView()
            }
        #endif
    }
}

// MARK: - Debug view

struct TapDebugView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Polling") {
                    let urls = SwiftUITap.activeServerURLs
                    if urls.isEmpty {
                        Text("No active pollers")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(urls, id: \.self) { url in
                            Text(url)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("SwiftUITap")
            #if os(iOS) || os(tvOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#if canImport(UIKit)

// MARK: - Three-finger long press

/// Attaches a 3-finger long-press recognizer to the host window. Embedded
/// as a 0×0 background — does not intercept touches.
private struct ThreeFingerLongPressGesture: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> UIView {
        let view = ProbeView()
        view.coordinator = context.coordinator
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let action: () -> Void
        var attached = false
        weak var window: UIWindow?
        weak var recognizer: UILongPressGestureRecognizer?

        init(action: @escaping () -> Void) {
            self.action = action
        }

        func attach(to window: UIWindow) {
            guard !attached else { return }
            let r = UILongPressGestureRecognizer(
                target: self,
                action: #selector(fired(_:))
            )
            r.numberOfTouchesRequired = 3
            r.minimumPressDuration = 0.6
            r.cancelsTouchesInView = false
            r.delegate = self
            window.addGestureRecognizer(r)
            self.window = window
            self.recognizer = r
            self.attached = true
        }

        @objc func fired(_ r: UILongPressGestureRecognizer) {
            if r.state == .began { action() }
        }

        // Recognize alongside everything else so we never block normal taps.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool { true }

        deinit {
            if let w = window, let r = recognizer {
                w.removeGestureRecognizer(r)
            }
        }
    }

    final class ProbeView: UIView {
        var coordinator: Coordinator?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window = window, let coordinator = coordinator {
                coordinator.attach(to: window)
            }
        }
    }
}

#endif
