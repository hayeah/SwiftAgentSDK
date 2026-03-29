import Foundation

/// Attached macro that generates TapDispatchable conformance.
/// Apply to @Observable classes to make them agent-drivable.
@attached(extension, conformances: TapDispatchable, names: named(__tapGet), named(__tapSet), named(__tapCall), named(__tapSnapshot))
public macro SwiftUITap() = #externalMacro(module: "SwiftUITapMacros", type: "SwiftUITapMacro")

/// Protocol that @SwiftUITap macro generates conformance for.
/// Provides string-based get/set/call dispatch on the state tree.
public protocol TapDispatchable: AnyObject {
    func __tapGet(_ path: String) -> TapResult
    func __tapSet(_ path: String, value: Any?) -> TapResult
    func __tapCall(_ method: String, params: [String: Any]) -> TapResult
    /// Return all properties as a JSON-serializable dictionary.
    /// Used when the agent reads a path that resolves to an TapDispatchable object.
    func __tapSnapshot() -> [String: Any]
}

/// Result of an agent dispatch operation.
public enum TapResult {
    case value(Any?)  // success — nil means void/no data
    case error(String)

    /// Convert to a JSON-serializable dictionary for the HTTP response.
    public var json: [String: Any] {
        switch self {
        case .value(let v): return ["data": v ?? NSNull()]
        case .error(let e): return ["error": e]
        }
    }
}

// MARK: - Codable Helpers

/// Encode an Encodable value to a JSON-compatible Any (dict, array, or primitive).
public func __tapEncode<T: Encodable>(_ value: T) -> Any? {
    guard let data = try? JSONEncoder().encode(value) else { return nil }
    return try? JSONSerialization.jsonObject(with: data)
}

/// Decode a Decodable value from a JSON-compatible Any.
public func __tapDecode<T: Decodable>(_ json: Any) -> T? {
    guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
}
