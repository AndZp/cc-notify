import Foundation

// MARK: - Codable types for hook payloads

struct HookPayload: Codable {
    let session_id: String?
    let cwd: String?
    let hook_event_name: String?
    let message: String?
    let title: String?
    let notification_type: String?  // permission_prompt | idle_prompt | elicitation_dialog | auth_success
}

struct SessionInfo: Codable {
    let sessionId: String?
    let name: String?
    let startedAt: Double?
}

// MARK: - Resolvers

/// Extracts the project folder name from a working directory path.
/// Returns nil for hidden directories (starting with ".").
func projectName(from cwd: String?) -> String? {
    guard let cwd, !cwd.isEmpty else { return nil }
    let name = URL(fileURLWithPath: cwd).lastPathComponent
    return name.hasPrefix(".") ? nil : name
}

/// Finds the session info (including custom name) for a given session ID.
/// Scans all JSON files in ~/.claude/sessions/ looking for a matching sessionId.
func sessionInfo(for sessionId: String?) -> SessionInfo? {
    guard let sessionId, !sessionId.isEmpty else { return nil }
    let dir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/sessions")
    guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    else { return nil }
    for file in files where file.pathExtension == "json" {
        guard let data = try? Data(contentsOf: file),
              let info = try? JSONDecoder().decode(SessionInfo.self, from: data),
              info.sessionId == sessionId else { continue }
        return info
    }
    return nil
}
