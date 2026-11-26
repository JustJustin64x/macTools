import AppKit
import MacToolsCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshots: [String: ToolSnapshot] = [:]
    @Published var busy = Set<String>()
    @Published var error: String?
    @Published var updateMessage: String?
    @Published var checkingUpdates = false
    private let controller = ServiceController(executable: Bundle.main.executableURL!)
    private var refreshing = false
    let tools = ToolDefinition.catalog

    var activeCount: Int { snapshots.values.filter { $0.status.isRunning }.count }
    var permissionRequired: Bool { snapshots.values.contains { $0.needsAccessibility } }
    var hasLegacy: Bool { snapshots.values.contains { $0.legacy } }

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        for tool in tools where !busy.contains(tool.id) {
            do { snapshots[tool.id] = try await controller.snapshot(tool) }
            catch { self.error = error.localizedDescription }
        }
    }

    func setEnabled(_ enabled: Bool, tool: ToolDefinition) {
        guard !busy.contains(tool.id) else { return }
        perform(tool) { try await self.controller.setEnabled(enabled, tool: tool) }
    }

    func restart(_ tool: ToolDefinition) {
        perform(tool) { try await self.controller.restart(tool) }
    }

    private func perform(_ tool: ToolDefinition, action: @escaping () async throws -> Void) {
        guard !busy.contains(tool.id) else { return }
        busy.insert(tool.id)
        Task {
            do { try await action() }
            catch { self.error = error.localizedDescription }
            busy.remove(tool.id)
            await refresh()
            try? await Task.sleep(for: .milliseconds(800))
            await refresh()
        }
    }

    func checkForUpdates() {
        guard !checkingUpdates else { return }
        checkingUpdates = true
        let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/macToolsUpdate")
        Task {
            let message = await Task.detached(priority: .utility) {
                do {
                    let process = Process()
                    process.executableURL = executable
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    process.standardError = pipe
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                } catch { return error.localizedDescription }
            }.value
            checkingUpdates = false
            updateMessage = message.isEmpty ? "Update-Prüfung abgeschlossen." : message
        }
    }

    func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func revealHelper(_ tool: ToolDefinition) {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/\(tool.executableName)")
        NSWorkspace.shared.activateFileViewerSelecting([helper])
    }

    func openLogs(_ tool: ToolDefinition) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/macTools/\(tool.id)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}
