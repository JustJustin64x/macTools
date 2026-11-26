import AppKit
import FinderKeys
import SwiftUI

@main
struct MacToolsEntry {
    @MainActor static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--self-test"] { exit(Int32(finder_keys_self_test())) }
        if arguments.first == "--run-tool" || arguments.first == "--check-tool" {
            guard arguments.count == 2 || (arguments.count == 3 && arguments[2] == "--verbose"),
                  arguments[1] == "finder-keys" else {
                fputs("Unbekanntes Tool. Aufruf: macTools --run-tool finder-keys [--verbose]\n", stderr)
                exit(2)
            }
            exit(Int32(finder_keys_run(arguments.contains("--verbose"), arguments[0] == "--check-tool")))
        }
        guard arguments.isEmpty else {
            fputs("Aufruf: macTools [--run-tool finder-keys | --check-tool finder-keys | --self-test]\n", stderr)
            exit(2)
        }
        NSApplication.shared.setActivationPolicy(.regular)
        MacToolsApp.main()
    }
}

struct MacToolsApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("macTools", id: "main") {
            ContentView().environmentObject(model)
                .frame(minWidth: 820, minHeight: 620)
                .task {
                    await model.refresh()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(3))
                        await model.refresh()
                    }
                }
        }
        .defaultSize(width: 990, height: 720)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Nach Updates suchen …") { model.checkForUpdates() }.disabled(model.checkingUpdates)
                Divider()
                Button("Bedienungshilfen öffnen …") { model.openAccessibility() }
            }
        }
    }
}
