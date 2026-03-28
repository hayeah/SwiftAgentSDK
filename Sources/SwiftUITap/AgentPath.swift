import Foundation

/// Utility for splitting dot-separated agent paths.
public enum AgentPath {
    /// Split "foo.bar.baz" into ("foo", "bar.baz").
    /// Split "foo" into ("foo", nil).
    public static func split(_ path: String) -> (String, String?) {
        guard let dotIndex = path.firstIndex(of: ".") else {
            return (path, nil)
        }
        let head = String(path[path.startIndex..<dotIndex])
        let tail = String(path[path.index(after: dotIndex)...])
        return (head, tail.isEmpty ? nil : tail)
    }
}
