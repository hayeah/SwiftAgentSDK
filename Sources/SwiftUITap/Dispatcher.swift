import Foundation

/// Routes get/set/call operations to the TapDispatchable state tree.
struct Dispatcher {
    let state: any TapDispatchable

    @MainActor
    func dispatch(_ request: [String: Any]) -> TapResult {
        guard let type = request["type"] as? String else {
            return .error("missing 'type' field")
        }

        switch type {
        case "get":
            guard let path = request["path"] as? String else {
                return .error("missing 'path' for get")
            }
            if path == "." { return .value(state.__tapSnapshot()) }
            return state.__tapGet(path)

        case "set":
            guard let path = request["path"] as? String else {
                return .error("missing 'path' for set")
            }
            return state.__tapSet(path, value: request["value"])

        case "call":
            guard let method = request["method"] as? String else {
                return .error("missing 'method' for call")
            }
            let params = request["params"] as? [String: Any] ?? [:]
            return state.__tapCall(method, params: params)

        default:
            return .error("unknown type: \(type)")
        }
    }
}
