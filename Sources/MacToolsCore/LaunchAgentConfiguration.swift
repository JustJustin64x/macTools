import Foundation

public struct LaunchAgentConfiguration: Sendable {
    public let tool: ToolDefinition
    public let executable: URL
    public let home: URL

    public init(tool: ToolDefinition, executable: URL, home: URL) {
        self.tool = tool
        self.executable = executable
        self.home = home
    }

    public var helperExecutable: URL {
        executable.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Helpers/\(tool.executableName)")
    }
    public var plistURL: URL {
        home.appendingPathComponent("Library/LaunchAgents/\(tool.launchLabel).plist")
    }
    public var logDirectory: URL {
        home.appendingPathComponent("Library/Logs/macTools/\(tool.id)", isDirectory: true)
    }
    public func encoded() throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: [
            "Label": tool.launchLabel,
            "ProgramArguments": [helperExecutable.path],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive",
            "StandardOutPath": logDirectory.appendingPathComponent("stdout.log").path,
            "StandardErrorPath": logDirectory.appendingPathComponent("stderr.log").path
        ], format: .xml, options: 0)
    }
}

public struct ServiceStatus: Equatable, Sendable {
    public let isLoaded: Bool
    public let isRunning: Bool
    public let lastExitCode: Int?

    public init(launchctlOutput: String, exitCode: Int32) {
        isLoaded = exitCode == 0
        let lines = launchctlOutput.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        isRunning = isLoaded && lines.contains("state = running")
        let prefix = "last exit code = "
        lastExitCode = lines.first(where: { $0.hasPrefix(prefix) }).flatMap { Int($0.dropFirst(prefix.count)) }
    }
}
