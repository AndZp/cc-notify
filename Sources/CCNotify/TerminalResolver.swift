import Foundation

/// Maps the host passed by the hook to a macOS bundle identifier — normally a TERM_PROGRAM
/// value, or "Conductor" for a Conductor agent that opted in with CCNOTIFY_CONDUCTOR.
/// Used to implement click-to-open: when the user taps a notification, the originating
/// terminal or editor is brought to the foreground.
func resolveTerminalBundle(_ termProgram: String) -> String {
    let map: [String: String] = [
        "Conductor":       "com.conductor.app",
        "WarpTerminal":    "dev.warp.Warp-Stable",
        "vscode":          "com.microsoft.VSCode",
        "cursor":          "com.todesktop.230313mzl4w4u92",
        "ghostty":         "com.mitchellh.ghostty",
        "iTerm.app":       "com.googlecode.iterm2",
        "Apple_Terminal":  "com.apple.Terminal",
    ]
    return map[termProgram] ?? ""
}
