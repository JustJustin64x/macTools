import AppKit
import ApplicationServices
import MacToolsCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshots: [String: ToolSnapshot] = [:]
    @Published var busy = Set<String>()
    @Published var accessibilityGranted = AXIsProcessTrusted()
    @Published var error: String?
    private let controller = ServiceController(executable: Bundle.main.executableURL!)
    private var refreshing = false
    let tools = ToolDefinition.catalog

    var activeCount: Int { snapshots.values.filter { $0.status.isRunning }.count }
    var hasLegacy: Bool { snapshots.values.contains { $0.legacy } }

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        accessibilityGranted = AXIsProcessTrusted()
        for tool in tools where !busy.contains(tool.id) {
            do { snapshots[tool.id] = try await controller.snapshot(tool) }
            catch { self.error = error.localizedDescription }
        }
    }

    func setEnabled(_ enabled: Bool, tool: ToolDefinition) {
        guard !busy.contains(tool.id) else { return }
        if enabled && !accessibilityGranted {
            error = "Bitte gib macTools zuerst unter Datenschutz & Sicherheit → Bedienungshilfen frei. Danach kannst du das Tool aktivieren."
            return
        }
        perform(tool) { try await self.controller.setEnabled(enabled, tool: tool) }
    }

    func restart(_ tool: ToolDefinition) {
        guard accessibilityGranted else {
            error = "Bitte zuerst die Bedienungshilfen-Freigabe für macTools aktivieren."
            return
        }
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

    func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func openLogs(_ tool: ToolDefinition) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/macTools/\(tool.id)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}
