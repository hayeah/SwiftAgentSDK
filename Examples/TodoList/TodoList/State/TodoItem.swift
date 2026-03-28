import Foundation
import SwiftAgentSDK

@Observable
final class TodoItem: Identifiable {
    let id: String = UUID().uuidString
    var title: String
    var isCompleted: Bool = false

    init(title: String) {
        self.title = title
    }
}

// Hand-written — @AgentSDK macro would generate this
extension TodoItem: AgentDispatchable {
    func __agentGet(_ path: String) -> AgentResult {
        let (head, _) = AgentPath.split(path)
        switch head {
        case "id": return .value(id)
        case "title": return .value(title)
        case "isCompleted": return .value(isCompleted)
        default: return .error("unknown property: \(head)")
        }
    }

    func __agentSet(_ path: String, value: Any?) -> AgentResult {
        let (head, _) = AgentPath.split(path)
        switch head {
        case "title":
            guard let v = value as? String else { return .error("type mismatch: title expects String") }
            title = v
            return .value(nil)
        case "isCompleted":
            guard let v = value as? Bool else { return .error("type mismatch: isCompleted expects Bool") }
            isCompleted = v
            return .value(nil)
        default: return .error("unknown or read-only property: \(head)")
        }
    }

    func __agentCall(_ method: String, params: [String: Any]) -> AgentResult {
        return .error("unknown method: \(method)")
    }

    func __agentSnapshot() -> [String: Any] {
        return [
            "id": id,
            "title": title,
            "isCompleted": isCompleted,
        ]
    }
}
