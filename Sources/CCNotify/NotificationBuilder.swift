import AppKit
import UserNotifications

// MARK: - Notification content

struct NotifContent {
    let title: String     // e.g. "andrey · Permission"
    let subtitle: String? // session name when renamed, otherwise nil
    let body: String      // specific message or action detail
}

/// Constructs notification content from a hook event and its payload.
///
/// Title format:  `<folder> · <Action>`
/// Subtitle:      session name (only when the session has been renamed)
/// Body:          specific detail — message text, or duration for Stop events
func buildContent(event: String, payload: HookPayload?) -> NotifContent {
    let folder  = projectName(from: payload?.cwd) ?? "Claude Code"
    let session = sessionInfo(for: payload?.session_id)
    let sName   = session?.name
    let msg     = payload?.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    switch event {

    case "Notification":
        let action: String
        let detail: String
        switch payload?.notification_type {
        case "permission_prompt":
            action = "Permission"
            detail = msg.isEmpty ? "Needs your approval" : msg
        case "idle_prompt":
            action = "Input Needed"
            detail = msg.isEmpty ? "Claude has a question for you" : msg
        case "elicitation_dialog":
            action = "Question"
            detail = msg.isEmpty ? "Claude needs your input" : msg
        case "auth_success":
            action = "Authorized"
            detail = msg.isEmpty ? "Permission granted" : msg
        default:
            action = payload?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Attention"
            detail = msg.isEmpty ? "Claude needs your attention" : msg
        }
        return NotifContent(title: "\(folder) · \(action)", subtitle: sName, body: detail)

    case "Stop":
        var body = "Task finished"
        if let elapsed = consumePromptTimestamp(sessionId: payload?.session_id) {
            body = "Finished in \(formatDuration(elapsed))"
        }
        return NotifContent(title: "\(folder) · Done", subtitle: sName, body: body)

    default:
        return NotifContent(title: "\(folder) · Claude Code", subtitle: sName, body: msg.isEmpty ? event : msg)
    }
}

// MARK: - Notification delivery

/// Requests notification authorization (if needed) and posts the notification.
/// Attaches a branded icon PNG from the app bundle as a notification image.
/// Quits the app ~1 second after the notification is posted.
func sendNotification(notif: NotifContent, targetBundle: String, event: String) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
        guard granted else {
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notif.title
        if let sub = notif.subtitle { content.subtitle = sub }
        content.body  = notif.body
        content.sound = .default
        if !targetBundle.isEmpty { content.userInfo = ["targetBundle": targetBundle] }

        // Attach branded icon — workaround for ad-hoc signed apps on macOS 26
        // which cannot display bundle icons in Notification Center.
        // UNNotificationAttachment copies the file internally, so we clean up after delivery.
        var iconTmpURL: URL?
        if let src = Bundle.main.url(forResource: "icon", withExtension: "png") {
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("ccnotify-icon-\(UUID().uuidString).png")
            if (try? FileManager.default.copyItem(at: src, to: tmp)) != nil,
               let att = try? UNNotificationAttachment(identifier: "icon", url: tmp, options: nil) {
                content.attachments = [att]
                iconTmpURL = tmp
            }
        }

        let req = UNNotificationRequest(
            identifier: "ccnotify-\(UUID().uuidString)",
            content: content, trigger: nil
        )
        center.add(req) { _ in
            if let url = iconTmpURL { try? FileManager.default.removeItem(at: url) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { NSApp.terminate(nil) }
        }
    }
}
