import AppKit
import UserNotifications
import os.log

let logger = Logger(subsystem: "sh.claude.ccnotify", category: "main")

// MARK: - App delegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = Array(CommandLine.arguments.dropFirst())
        logger.info("launched: args=\(args, privacy: .public)")

        guard let event = args.first else {
            // Launched without arguments — nothing to do
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { NSApp.terminate(nil) }
            return
        }

        // Parse hook payload from temp file passed as argument
        let payload: HookPayload?
        if let filePath = args.dropFirst().first(where: { $0.hasPrefix("/") }),
           let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
            payload = try? JSONDecoder().decode(HookPayload.self, from: data)
            try? FileManager.default.removeItem(atPath: filePath)
        } else {
            payload = nil
        }

        // UserPromptSubmit: save timestamp for duration tracking, then exit (no notification)
        if event == "UserPromptSubmit" {
            if let sid = payload?.session_id {
                savePromptTimestamp(sessionId: sid)
                logger.info("saved prompt timestamp for session \(sid, privacy: .public)")
            }
            NSApp.terminate(nil)
            return
        }

        guard ["Notification", "Stop"].contains(event) else {
            NSApp.terminate(nil)
            return
        }

        // Determine which terminal to focus on notification tap.
        // TERM_PROGRAM is passed as the second argument by the hook command.
        let termProgram = args.count > 1 && !args[1].hasPrefix("/") ? args[1] : ""
        let targetBundle = resolveTerminalBundle(termProgram)

        let notif = buildContent(event: event, payload: payload)
        logger.info("posting: title=\(notif.title, privacy: .public) subtitle=\(notif.subtitle ?? "nil", privacy: .public)")

        sendNotification(notif: notif, targetBundle: targetBundle, event: event)
    }

    // MARK: - Notification tap handler

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let bundleId = userInfo["targetBundle"] as? String, !bundleId.isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, _ in }
        }
        completionHandler()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
    }

    // Show notifications even when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
