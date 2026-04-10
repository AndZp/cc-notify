import Foundation

/// Saves the current timestamp to a temp file keyed by session ID.
/// Called on UserPromptSubmit so we can later compute how long a task took.
func savePromptTimestamp(sessionId: String) {
    let path = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ccnotify_prompt_\(sessionId).ts")
    let ms = String(Date().timeIntervalSince1970 * 1000)
    try? ms.write(to: path, atomically: true, encoding: .utf8)
}

/// Reads and deletes the timestamp file for a session.
/// Returns elapsed seconds since the saved timestamp, or nil if no file exists.
func consumePromptTimestamp(sessionId: String?) -> TimeInterval? {
    guard let sessionId else { return nil }
    let path = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ccnotify_prompt_\(sessionId).ts")
    guard let raw = try? String(contentsOf: path, encoding: .utf8),
          let ms = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    else { return nil }
    try? FileManager.default.removeItem(at: path)
    return Date().timeIntervalSince1970 - ms / 1000.0
}

/// Formats a duration in seconds to a human-readable string.
/// Examples: "45s", "2m 34s", "1h 5m"
func formatDuration(_ seconds: TimeInterval) -> String {
    let s = Int(seconds)
    if s < 60   { return "\(s)s" }
    if s < 3600 { return "\(s / 60)m \(s % 60)s" }
    return "\(s / 3600)h \((s % 3600) / 60)m"
}
