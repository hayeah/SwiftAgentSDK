import Foundation
import SwiftUI
import SwiftAgentSDK

@Observable
final class AppState {
    var __doc__: String {
        """
        AppState — TodoList app state tree.

        Single source of truth. All views bind to paths within this tree.

        ## State Tree

        todos — array of TodoItem objects
          todos.N.title (String)        — the todo text
          todos.N.isCompleted (Bool)    — whether the todo is done

        newTodoText (String) — text field for adding new todos

        ## Methods

        addTodo(title: String) → {"index": N}
          Creates a new TodoItem and appends it to `todos`.
          Returns the index of the new item.

        toggleTodo(index: Int)
          Toggles `isCompleted` on the todo at the given index.

        removeTodo(index: Int)
          Removes the todo at the given index.

        clearCompleted()
          Removes all completed todos.

        ## Common Workflows

        Add a todo:
          call addTodo {"title": "Buy milk"}

        Complete a todo:
          call toggleTodo {"index": 0}

        Edit a todo's title:
          set todos.0.title "Buy oat milk instead"

        Check all todos:
          get todos.0.title, get todos.0.isCompleted, etc.

        Remove completed:
          call clearCompleted
        """
    }

    var todos: [TodoItem] = []
    var newTodoText: String = ""

    // Computed
    var activeTodos: [TodoItem] {
        todos.filter { !$0.isCompleted }
    }

    var completedTodos: [TodoItem] {
        todos.filter { $0.isCompleted }
    }

    var activeCount: Int { activeTodos.count }

    // MARK: - Actions

    func addTodo(title: String) -> [String: Any]? {
        let item = TodoItem(title: title)
        todos.append(item)
        return ["index": todos.count - 1]
    }

    func toggleTodo(index: Int) {
        guard index >= 0 && index < todos.count else { return }
        todos[index].isCompleted.toggle()
    }

    func removeTodo(index: Int) {
        guard index >= 0 && index < todos.count else { return }
        todos.remove(at: index)
    }

    func clearCompleted() {
        todos.removeAll { $0.isCompleted }
    }
}

// Hand-written — @AgentSDK macro would generate this
extension AppState: AgentDispatchable {
    func __agentGet(_ path: String) -> AgentResult {
        let (head, tail) = AgentPath.split(path)
        switch head {
        case "__doc__": return .value(__doc__)
        case "newTodoText": return .value(newTodoText)
        case "todos":
            guard let tail else {
                return .value(todos.map { $0.__agentSnapshot() })
            }
            let (indexStr, rest) = AgentPath.split(tail)
            guard let index = Int(indexStr), index >= 0, index < todos.count else {
                return .error("index out of bounds: \(indexStr) (count: \(todos.count))")
            }
            guard let rest else {
                return .value(todos[index].__agentSnapshot())
            }
            return todos[index].__agentGet(rest)
        default: return .error("unknown property: \(head)")
        }
    }

    func __agentSet(_ path: String, value: Any?) -> AgentResult {
        let (head, tail) = AgentPath.split(path)
        switch head {
        case "newTodoText":
            guard let v = value as? String else { return .error("type mismatch: newTodoText expects String") }
            newTodoText = v
            return .value(nil)
        case "todos":
            guard let tail else { return .error("cannot replace todos array") }
            let (indexStr, rest) = AgentPath.split(tail)
            guard let index = Int(indexStr), index >= 0, index < todos.count else {
                return .error("index out of bounds: \(indexStr)")
            }
            guard let rest else { return .error("cannot replace array element") }
            return todos[index].__agentSet(rest, value: value)
        default: return .error("unknown property: \(head)")
        }
    }

    func __agentCall(_ method: String, params: [String: Any]) -> AgentResult {
        switch method {
        case "addTodo":
            guard let title = params["title"] as? String else {
                return .error("missing param: title (String)")
            }
            let result = addTodo(title: title)
            return .value(result)
        case "toggleTodo":
            guard let index = (params["index"] as? NSNumber)?.intValue else {
                return .error("missing param: index (Int)")
            }
            toggleTodo(index: index)
            return .value(nil)
        case "removeTodo":
            guard let index = (params["index"] as? NSNumber)?.intValue else {
                return .error("missing param: index (Int)")
            }
            removeTodo(index: index)
            return .value(nil)
        case "clearCompleted":
            clearCompleted()
            return .value(nil)
        default: return .error("unknown method: \(method)")
        }
    }

    func __agentSnapshot() -> [String: Any] {
        return [
            "todos": todos.map { $0.__agentSnapshot() },
            "newTodoText": newTodoText,
        ]
    }
}
