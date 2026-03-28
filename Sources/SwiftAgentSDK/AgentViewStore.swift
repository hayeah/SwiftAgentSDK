import SwiftUI
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Stores view inspection data: frames, layout info, and root platform view reference.
/// Used by the view inspection protocol (POST /view).
@MainActor
public final class AgentViewStore {
    /// Shared instance — set by .agentInspectable(), read by DebugLayout and Poller.
    public static var active: AgentViewStore?

    /// Resolved anchor frames, keyed by qualified agentID.
    public var frames: [String: CGRect] = [:]

    /// Layout negotiation info from DebugLayout passthrough.
    public var layoutInfo: [String: LayoutInfo] = [:]

    #if canImport(AppKit)
    /// Root NSView for screenshots and view hierarchy walking.
    public weak var rootView: NSView?
    #elseif canImport(UIKit)
    /// Root UIView for screenshots and view hierarchy walking.
    public weak var rootView: UIView?
    #endif

    public struct LayoutInfo {
        public var proposedWidth: CGFloat?
        public var proposedHeight: CGFloat?
        public var reported: CGSize

        public init(proposedWidth: CGFloat?, proposedHeight: CGFloat?, reported: CGSize) {
            self.proposedWidth = proposedWidth
            self.proposedHeight = proposedHeight
            self.reported = reported
        }
    }

    public init() {}

    // MARK: - Dispatch

    public func dispatch(_ request: [String: Any]) -> AgentResult {
        guard let type = request["type"] as? String else {
            return .error("missing 'type' field")
        }
        switch type {
        case "tree":
            return tree(id: request["id"] as? String)
        case "screenshot":
            return screenshot(request)
        case "get":
            return platformGet(request)
        case "set":
            return platformSet(request)
        case "call":
            return platformCall(request)
        default:
            return .error("unknown view type: \(type)")
        }
    }

    // MARK: - Tree

    func tree(id: String?) -> AgentResult {
        // Build flat list of nodes
        var nodes: [(id: String, frame: CGRect, proposed: LayoutInfo?, viewClass: String?)] = []
        for (nodeID, frame) in frames {
            let layout = layoutInfo[nodeID]
            let viewClass = findViewClass(for: nodeID)
            nodes.append((id: nodeID, frame: frame, proposed: layout, viewClass: viewClass))
        }

        // Sort by area descending (largest first) for containment check
        nodes.sort { $0.frame.width * $0.frame.height > $1.frame.width * $1.frame.height }

        // Build tree from spatial containment
        var nodeMap: [String: [String: Any]] = [:]
        var childrenMap: [String: [[String: Any]]] = [:]
        var parentMap: [String: String] = [:] // child -> parent

        for node in nodes {
            var dict: [String: Any] = [
                "id": node.id,
                "frame": rectToDict(node.frame),
            ]
            if let layout = node.proposed {
                dict["proposed"] = [
                    "w": layout.proposedWidth.map { $0 as Any } ?? NSNull(),
                    "h": layout.proposedHeight.map { $0 as Any } ?? NSNull(),
                ] as [String: Any]
                dict["reported"] = [
                    "w": layout.reported.width,
                    "h": layout.reported.height,
                ]
            }
            dict["viewClass"] = node.viewClass as Any
            nodeMap[node.id] = dict
            childrenMap[node.id] = []
        }

        // Assign children: for each node (smallest first), find the smallest containing parent
        let sortedByAreaAsc = nodes.reversed()
        for node in sortedByAreaAsc {
            // Find smallest node that contains this one (and isn't itself)
            var bestParent: String?
            var bestArea: CGFloat = .infinity
            for candidate in nodes {
                if candidate.id == node.id { continue }
                let cf = candidate.frame
                let nf = node.frame
                let area = cf.width * cf.height
                if cf.contains(nf) && area < bestArea {
                    bestArea = area
                    bestParent = candidate.id
                }
            }
            if let parent = bestParent {
                parentMap[node.id] = parent
            }
        }

        // Build children lists
        for (child, parent) in parentMap {
            if var children = childrenMap[parent] {
                children.append(nodeMap[child]!)
                childrenMap[parent] = children
            }
        }

        // Find roots (nodes with no parent)
        let rootIDs = nodes.map(\.id).filter { parentMap[$0] == nil }

        // Attach children recursively
        func buildNode(_ nodeID: String) -> [String: Any] {
            var node = nodeMap[nodeID]!
            let children = (childrenMap[nodeID] ?? []).map { child -> [String: Any] in
                let childID = child["id"] as! String
                return buildNode(childID)
            }
            if !children.isEmpty {
                node["children"] = children
            }
            return node
        }

        // If scoped to a specific id, return that subtree
        if let id = id {
            guard nodeMap[id] != nil else {
                return .error("unknown view id: \(id)")
            }
            return .value(buildNode(id))
        }

        // Return full tree (single root or array of roots)
        if rootIDs.count == 1 {
            return .value(buildNode(rootIDs[0]))
        }
        let roots = rootIDs.map { buildNode($0) }
        return .value(roots)
    }

    // MARK: - Screenshot

    func screenshot(_ request: [String: Any]) -> AgentResult {
        #if canImport(AppKit)
        guard let view = rootView, let window = view.window else {
            return .error("no root view available for screenshot")
        }

        // Capture the full window content
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            return .error("failed to create bitmap rep")
        }
        view.cacheDisplay(in: bounds, to: rep)

        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            return .error("failed to encode PNG")
        }

        var result: [String: Any] = [
            "image": pngData.base64EncodedString(),
            "format": "png",
            "size": ["w": bounds.width, "h": bounds.height],
            "scale": window.backingScaleFactor,
        ]

        // Include frames so server can crop
        if request["id"] != nil {
            var framesDict: [String: Any] = [:]
            for (id, frame) in frames {
                framesDict[id] = rectToDict(frame)
            }
            result["frames"] = framesDict
        }

        return .value(result)

        #elseif canImport(UIKit)
        guard let view = rootView else {
            return .error("no root view available for screenshot")
        }

        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { ctx in
            view.layer.render(in: ctx.cgContext)
        }

        guard let pngData = image.pngData() else {
            return .error("failed to encode PNG")
        }

        var result: [String: Any] = [
            "image": pngData.base64EncodedString(),
            "format": "png",
            "size": ["w": view.bounds.width, "h": view.bounds.height],
            "scale": UIScreen.main.scale,
        ]

        if request["id"] != nil {
            var framesDict: [String: Any] = [:]
            for (id, frame) in frames {
                framesDict[id] = rectToDict(frame)
            }
            result["frames"] = framesDict
        }

        return .value(result)
        #else
        return .error("screenshot not supported on this platform")
        #endif
    }

    // MARK: - KVC Get/Set/Call on backing platform view

    func platformGet(_ request: [String: Any]) -> AgentResult {
        guard let id = request["id"] as? String else {
            return .error("get requires 'id'")
        }
        guard let view = findPlatformView(byIdentifier: id) else {
            return .error("no backing view for id: \(id)")
        }
        let viewClass = String(describing: type(of: view))

        // Multi-get
        if let paths = request["path"] as? [String] {
            var result: [String: Any] = [:]
            for kp in paths {
                result[kp] = serializeValue(view.value(forKeyPath: kp))
            }
            return .value(["data": result, "viewClass": viewClass])
        }

        // Single get
        guard let path = request["path"] as? String else {
            return .error("get requires 'path'")
        }
        let val = view.value(forKeyPath: path)
        return .value(["data": serializeValue(val), "viewClass": viewClass])
    }

    func platformSet(_ request: [String: Any]) -> AgentResult {
        guard let id = request["id"] as? String else {
            return .error("set requires 'id'")
        }
        guard let view = findPlatformView(byIdentifier: id) else {
            return .error("no backing view for id: \(id)")
        }
        guard let path = request["path"] as? String else {
            return .error("set requires 'path'")
        }
        let viewClass = String(describing: type(of: view))
        view.setValue(request["value"], forKeyPath: path)
        return .value(["viewClass": viewClass])
    }

    func platformCall(_ request: [String: Any]) -> AgentResult {
        guard let id = request["id"] as? String else {
            return .error("call requires 'id'")
        }
        guard let view = findPlatformView(byIdentifier: id) else {
            return .error("no backing view for id: \(id)")
        }
        guard let method = request["method"] as? String else {
            return .error("call requires 'method'")
        }
        let viewClass = String(describing: type(of: view))
        let sel = NSSelectorFromString(method)
        guard view.responds(to: sel) else {
            return .error("\(viewClass) does not respond to \(method)")
        }
        // Simple no-arg selector call
        _ = view.perform(sel)
        return .value(["viewClass": viewClass])
    }

    // MARK: - Helpers

    private func findViewClass(for id: String) -> String? {
        guard let view = findPlatformView(byIdentifier: id) else { return nil }
        return String(describing: type(of: view))
    }

    #if canImport(AppKit)
    private func findPlatformView(byIdentifier id: String) -> NSView? {
        guard let root = rootView else { return nil }
        return findDescendant(of: root) { view in
            // NSView accessibility identifier via NSAccessibility protocol
            view.accessibilityIdentifier() == id
        }
    }

    private func findDescendant(of view: NSView, where predicate: (NSView) -> Bool) -> NSView? {
        if predicate(view) { return view }
        for subview in view.subviews {
            if let found = findDescendant(of: subview, where: predicate) {
                return found
            }
        }
        return nil
    }
    #elseif canImport(UIKit)
    private func findPlatformView(byIdentifier id: String) -> UIView? {
        guard let root = rootView else { return nil }
        return findDescendant(of: root) { $0.accessibilityIdentifier == id }
    }

    private func findDescendant(of view: UIView, where predicate: (UIView) -> Bool) -> UIView? {
        if predicate(view) { return view }
        for subview in view.subviews {
            if let found = findDescendant(of: subview, where: predicate) {
                return found
            }
        }
        return nil
    }
    #endif

    private func rectToDict(_ rect: CGRect) -> [String: CGFloat] {
        ["x": rect.origin.x, "y": rect.origin.y, "w": rect.size.width, "h": rect.size.height]
    }

    private func serializeValue(_ value: Any?) -> Any {
        guard let value = value else { return NSNull() }

        switch value {
        case let n as NSNumber: return n
        case let s as String: return s
        case let b as Bool: return b
        #if canImport(AppKit)
        case let p as NSPoint: return ["x": p.x, "y": p.y]
        case let s as NSSize: return ["w": s.width, "h": s.height]
        case let r as NSRect: return rectToDict(r)
        #endif
        case let p as CGPoint: return ["x": p.x, "y": p.y]
        case let s as CGSize: return ["w": s.width, "h": s.height]
        case let r as CGRect: return rectToDict(r)
        default: return String(describing: value)
        }
    }
}
