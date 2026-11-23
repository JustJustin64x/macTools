import Foundation

public struct ToolDefinition: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let summary: String
    public let symbol: String
    public let executableName: String
    public let category: String
    public let shortcuts: [Shortcut]
    public var launchLabel: String { "io.github.justjustin64x.macTools.\(id)" }

    public struct Shortcut: Sendable {
        public let keys: String
        public let action: String
    }

    public static let finderKeys = ToolDefinition(
        id: "finder-keys", title: "Finder Enter", subtitle: "Dateien öffnen. Mit einem Tastendruck.",
        summary: "Öffne ausgewählte Dateien und Ordner mit Enter. Mit F2 kannst du sie umbenennen. Beim Suchen und Bearbeiten von Namen verhält sich Enter wie gewohnt.",
        symbol: "folder", executableName: "finder_keys", category: "Finder",
        shortcuts: [Shortcut(keys: "↩", action: "Datei oder Ordner öffnen"),
                    Shortcut(keys: "F2", action: "Datei oder Ordner umbenennen"),
                    Shortcut(keys: "fn + F2", action: "Je nach Tastatureinstellung")]
    )

    // Add new tools here, then implement their --run-tool entry point.
    public static let catalog: [ToolDefinition] = [.finderKeys]
}
