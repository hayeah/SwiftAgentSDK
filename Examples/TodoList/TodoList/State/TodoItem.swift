import Foundation
import SwiftAgentSDK

@AgentSDK
@Observable
final class TodoItem: Identifiable {
    let id: String = UUID().uuidString
    var title: String
    var isCompleted: Bool = false

    init(title: String) {
        self.title = title
    }
}
