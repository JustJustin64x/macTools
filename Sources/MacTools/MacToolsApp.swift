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
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        let delegate = MacToolsApplicationDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

// Explicit window ownership makes opening from Spotlight and reopening after
// closing the last window independent of SwiftUI's saved scene visibility.
@MainActor
final class MacToolsApplicationDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var window: NSWindow?
    private var refreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        showMainWindow()
        refreshTask = Task {
            while !Task.isCancelled {
                await model.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) { refreshTask?.cancel() }

    @objc private func showMainWindow() {
        if window == nil {
            let created = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 990, height: 720),
                                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                   backing: .buffered, defer: false)
            created.title = "macTools"
            created.titleVisibility = .hidden
            created.titlebarAppearsTransparent = true
            created.isMovableByWindowBackground = true
            created.isReleasedWhenClosed = false
            created.minSize = NSSize(width: 820, height: 620)
            created.contentView = NSHostingView(rootView: ContentView().environmentObject(model))
            created.center()
            window = created
        }
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func checkForUpdates() { model.checkForUpdates() }
    @objc private func openAccessibility() { model.openAccessibility() }

    private func configureMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu(title: "macTools")
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Über macTools", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let update = appMenu.addItem(withTitle: "Nach Updates suchen …", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        let access = appMenu.addItem(withTitle: "Bedienungshilfen öffnen …", action: #selector(openAccessibility), keyEquivalent: "")
        access.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "macTools ausblenden", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "macTools beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editItem = NSMenuItem(title: "Bearbeiten", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "Bearbeiten")
        for (title, action, key) in [("Widerrufen", "undo:", "z"), ("Ausschneiden", "cut:", "x"),
                                     ("Kopieren", "copy:", "c"), ("Einsetzen", "paste:", "v"),
                                     ("Alles auswählen", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem(title: "Fenster", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "Fenster")
        let show = windowMenu.addItem(withTitle: "macTools anzeigen", action: #selector(showMainWindow), keyEquivalent: "0")
        show.target = self
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApplication.shared.mainMenu = main
        NSApplication.shared.windowsMenu = windowMenu
    }
}
