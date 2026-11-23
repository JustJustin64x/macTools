import Foundation

public struct ToolSnapshot: Sendable {
    public let enabled: Bool
    public let status: ServiceStatus
    public let legacy: Bool
}

public struct CommandResult: Sendable {
    public let code: Int32
    public let output: String
}

public enum ServiceError: LocalizedError {
    case command(String)
    case notInstalled
    public var errorDescription: String? {
        switch self {
        case .command(let text): return text
        case .notInstalled: return "Bitte macTools zuerst mit make install in deinem Programme-Ordner installieren."
        }
    }
}

// File operations and launchctl run off the UI's main actor. No shell commands
// or interpolated command strings: paths with spaces remain single arguments.
public actor ServiceController {
    private let home: URL
    private let executable: URL
    private let domain: String
    private let files = FileManager.default

    public init(executable: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.executable = executable
        self.home = home
        self.domain = "gui/\(getuid())"
    }

    private func configuration(_ tool: ToolDefinition) -> LaunchAgentConfiguration {
        LaunchAgentConfiguration(tool: tool, executable: executable, home: home)
    }

    private var legacyPlist: URL { home.appendingPathComponent("Library/LaunchAgents/local.finder-keys.plist") }

    public func snapshot(_ tool: ToolDefinition) throws -> ToolSnapshot {
        let config = configuration(tool)
        let modern = files.fileExists(atPath: config.plistURL.path)
        let legacy = tool.id == "finder-keys" && !modern && files.fileExists(atPath: legacyPlist.path)
        let label = legacy ? "local.finder-keys" : tool.launchLabel
        let result = try run(["print", "\(domain)/\(label)"])
        return ToolSnapshot(enabled: modern || legacy,
                            status: ServiceStatus(launchctlOutput: result.output, exitCode: result.code),
                            legacy: legacy)
    }

    public func setEnabled(_ enabled: Bool, tool: ToolDefinition) throws {
        // Never register the transient .build executable as an autostart target.
        guard executable.path.contains(".app/Contents/MacOS/") else { throw ServiceError.notInstalled }
        let config = configuration(tool)
        if !enabled {
            try stop(label: tool.launchLabel)
            if files.fileExists(atPath: config.plistURL.path) { try files.removeItem(at: config.plistURL) }
            if tool.id == "finder-keys" { try retireLegacy() }
            return
        }
        guard files.isExecutableFile(atPath: config.helperExecutable.path) else {
            throw ServiceError.command("Die Tool-Implementierung fehlt im App-Paket. Bitte macTools erneut installieren.")
        }
        try files.createDirectory(at: config.plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.createDirectory(at: config.logDirectory, withIntermediateDirectories: true)
        let data = try config.encoded()
        // Retire the old agent before loading the replacement to prevent double remaps.
        if tool.id == "finder-keys" { try retireLegacy() }
        try stop(label: tool.launchLabel)
        try data.write(to: config.plistURL, options: .atomic)
        let result = try run(["bootstrap", domain, config.plistURL.path])
        guard result.code == 0 else { throw ServiceError.command("Tool konnte nicht gestartet werden: \(result.output)") }
    }

    public func restart(_ tool: ToolDefinition) throws {
        let state = try snapshot(tool)
        guard state.enabled else { return }
        // Rebuild configuration too, so a restart applies app/helper updates.
        try setEnabled(true, tool: tool)
    }

    private func retireLegacy() throws {
        guard files.fileExists(atPath: legacyPlist.path) else { return }
        // Check ownership before touching a pre-existing agent.
        let data = try Data(contentsOf: legacyPlist)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        guard plist?["Label"] as? String == "local.finder-keys",
              let args = plist?["ProgramArguments"] as? [String],
              let first = args.first, URL(fileURLWithPath: first).lastPathComponent == "finder_keys" else {
            throw ServiceError.command("Die vorhandene Finder-Konfiguration wurde nicht erkannt und bleibt unverändert.")
        }
        let backup = home.appendingPathComponent("Library/Application Support/macTools/Backups", isDirectory: true)
        try files.createDirectory(at: backup, withIntermediateDirectories: true)
        let destination = backup.appendingPathComponent("local.finder-keys-\(UUID().uuidString).plist")
        try data.write(to: destination, options: .atomic)
        try stop(label: "local.finder-keys")
        try files.removeItem(at: legacyPlist)
    }

    private func stop(label: String) throws {
        let loaded = try run(["print", "\(domain)/\(label)"])
        guard loaded.code == 0 else { return }
        let result = try run(["bootout", "\(domain)/\(label)"])
        guard result.code == 0 else { throw ServiceError.command("Tool konnte nicht beendet werden: \(result.output)") }
    }

    private func run(_ arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(code: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}
