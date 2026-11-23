import Foundation
import MacToolsCore

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}
func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw TestFailure(description: message) }
}

// A standalone test executable also runs with Command Line Tools installations
// that don't ship XCTest. No third-party test dependency is required.
@main
struct ServiceTests {
    static func main() async throws {
        try testLaunchAgentPathsAndPolicy()
        try testServiceStates()
        try await testDevelopmentBinaryCannotReplaceWorkingAgent()
        try testCatalog()
        print("Core tests passed: paths, login policy, process states, development guard, catalog.")
    }

    static func testLaunchAgentPathsAndPolicy() throws {
        let home = URL(fileURLWithPath: "/Users/Example Person")
        let executable = URL(fileURLWithPath: "/Users/Example Person/Applications/macTools.app/Contents/MacOS/macTools")
        let config = LaunchAgentConfiguration(tool: .finderKeys, executable: executable, home: home)
        guard let plist = try PropertyListSerialization.propertyList(from: config.encoded(), format: nil) as? [String: Any] else {
            throw TestFailure(description: "Invalid plist")
        }
        try expect(plist["ProgramArguments"] as? [String] == ["/Users/Example Person/Applications/macTools.app/Contents/Helpers/finder_keys"], "Paths must remain separate arguments, including spaces")
        try expect(plist["Label"] as? String == "io.github.justjustin64x.macTools.finder-keys", "Wrong agent identity")
        try expect(plist["RunAtLoad"] as? Bool == true, "Agent must start at login")
        try expect(plist["KeepAlive"] == nil, "Missing permissions must not create a restart loop")
        try expect(plist["StandardErrorPath"] as? String == "/Users/Example Person/Library/Logs/macTools/finder-keys/stderr.log", "Wrong error log path")
    }

    static func testServiceStates() throws {
        let running = ServiceStatus(launchctlOutput: "state = running\n\tlast exit code = 1\n", exitCode: 0)
        try expect(running.isRunning && running.isLoaded && running.lastExitCode == 1, "Previous failure must not hide a running service")
        let exited = ServiceStatus(launchctlOutput: "state = not running\nlast exit code = 1", exitCode: 0)
        try expect(!exited.isRunning && exited.isLoaded, "Loaded is not the same as running")
        let missing = ServiceStatus(launchctlOutput: "Could not find service", exitCode: 113)
        try expect(!missing.isLoaded && !missing.isRunning && missing.lastExitCode == nil, "Absent service must be inactive")
    }

    static func testDevelopmentBinaryCannotReplaceWorkingAgent() async throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let service = ServiceController(executable: URL(fileURLWithPath: "/tmp/.build/macTools"), home: scratch)
        do {
            try await service.setEnabled(true, tool: .finderKeys)
            throw TestFailure(description: "Development executable must be rejected")
        } catch ServiceError.notInstalled {
            try expect(!FileManager.default.fileExists(atPath: scratch.path), "Rejection must not modify disk or agents")
        }
    }

    static func testCatalog() throws {
        let tools = ToolDefinition.catalog
        try expect(Set(tools.map(\.id)).count == tools.count, "Duplicate tool ID")
        try expect(Set(tools.map(\.launchLabel)).count == tools.count, "Duplicate launch agent")
    }
}
