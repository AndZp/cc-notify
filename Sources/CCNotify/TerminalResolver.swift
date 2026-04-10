import Foundation

/// Maps TERM_PROGRAM environment variable values to macOS bundle identifiers.
/// Used to implement click-to-open: when the user taps a notification, the originating
/// terminal or editor is brought to the foreground.
func resolveTerminalBundle(_ termProgram: String) -> String {
    let map: [String: String] = [
        "WarpTerminal":    "dev.warp.Warp-Stable",
        "vscode":          "com.microsoft.VSCode",
        "cursor":          "com.todesktop.230313mzl4w4u92",
        "ghostty":         "com.mitchellh.ghostty",
        "iTerm.app":       "com.googlecode.iterm2",
        "Apple_Terminal":  "com.apple.Terminal",
    ]
    return map[termProgram] ?? ""
}
