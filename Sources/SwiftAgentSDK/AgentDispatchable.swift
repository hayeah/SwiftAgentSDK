import Foundation

/// Protocol that @AgentSDK macro generates conformance for.
/// Provides string-based get/set/call dispatch on the state tree.
public protocol AgentDispatchable: AnyObject {
    func __agentGet(_ path: String) -> AgentResult
    func __agentSet(_ path: String, value: Any?) -> AgentResult
    func __agentCall(_ method: String, params: [String: Any]) -> AgentResult
    /// Return all properties as a JSON-serializable dictionary.
    /// Used when the agent reads a path that resolves to an AgentDispatchable object.
    func __agentSnapshot() -> [String: Any]
}

/// Result of an agent dispatch operation.
public enum AgentResult {
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
public func __agentEncode<T: Encodable>(_ value: T) -> Any? {
    guard let data = try? JSONEncoder().encode(value) else { return nil }
    return try? JSONSerialization.jsonObject(with: data)
}

/// Decode a Decodable value from a JSON-compatible Any.
public func __agentDecode<T: Decodable>(_ json: Any) -> T? {
    guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
}
