import MacToolsCore
import SwiftUI

private let accent = Color(red: 0.20, green: 0.38, blue: 0.91)

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""
    @State private var category = "Alle Tools"
    private var visibleTools: [ToolDefinition] {
        model.tools.filter {
            (category == "Alle Tools" || $0.category == category) &&
            (search.isEmpty || "\($0.title) \($0.summary) \($0.category)".localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 218)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if !model.accessibilityGranted { permissionCard }
                        if model.hasLegacy { migrationCard }
                        HStack {
                            Text(category).font(.title3.weight(.semibold))
                            Text("\(visibleTools.count)").font(.caption.weight(.medium))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.quaternary, in: Capsule())
                            Spacer()
                            Text("Änderungen werden sofort übernommen")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(visibleTools) { tool in ToolCard(tool: tool) }
                        if visibleTools.isEmpty {
                            ContentUnavailableView.search(text: search)
                        }
                        Label("Aktivierte Tools starten bei der Anmeldung. Du kannst dieses Fenster schließen.",
                              systemImage: "arrow.clockwise")
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(30)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(accent)
        .alert("Aktion nicht abgeschlossen", isPresented: Binding(
            get: { model.error != nil }, set: { if !$0 { model.error = nil } }
        )) { Button("OK") { model.error = nil } }
        message: { Text(model.error ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 24, weight: .medium)).foregroundStyle(accent)
                Text("macTools").font(.title2.weight(.bold))
            }
            .padding(.top, 42).padding(.bottom, 35).padding(.horizontal, 22)
            Text("DEIN WERKZEUGKASTEN").font(.system(size: 10, weight: .semibold))
                .tracking(1.2).foregroundStyle(.secondary).padding(.horizontal, 22).padding(.bottom, 12)
            navigationItem("Alle Tools", symbol: "square.grid.2x2", count: model.tools.count)
            Text("KATEGORIEN").font(.system(size: 10, weight: .semibold)).tracking(1.2)
                .foregroundStyle(.secondary).padding(.horizontal, 22).padding(.top, 28).padding(.bottom, 12)
            ForEach(Array(Set(model.tools.map(\.category))).sorted(), id: \.self) { name in
                navigationItem(name, symbol: "folder", count: model.tools.filter { $0.category == name }.count)
            }
            Spacer()
            Divider().padding(.horizontal, 20)
            HStack(spacing: 8) {
                Circle().fill(model.activeCount > 0 ? Color.green : Color.secondary).frame(width: 7, height: 7)
                Text("\(model.activeCount) von \(model.tools.count) aktiv")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(22)
            Text("macTools 0.1.0").font(.system(size: 10)).foregroundStyle(.tertiary)
                .padding(.horizontal, 22).padding(.bottom, 18)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func navigationItem(_ title: String, symbol: String, count: Int) -> some View {
        Button { category = title } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 18)
                Text(title).fontWeight(category == title ? .semibold : .regular)
                Spacer()
                Text("\(count)").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .foregroundStyle(category == title ? accent : .primary)
            .background(category == title ? accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).padding(.horizontal, 12)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Dein Mac. Deine Handgriffe.").font(.system(size: 26, weight: .bold))
                Text("Kleine Tools, die deinen Alltag einfacher machen.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 20)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Tools suchen", text: $search).textFieldStyle(.plain)
            }
            .padding(10).frame(width: 155)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
        }.padding(.horizontal, 30).padding(.top, 37).padding(.bottom, 26)
    }

    private var permissionCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "hand.raised.fill").font(.title2).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Einmal freigeben, dann loslegen.").font(.headline)
                Text("Erlaube macTools unter Bedienungshilfen, Tastatureingaben anzupassen. Füge dort diese macTools-App hinzu und aktiviere den Schalter.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Bedienungshilfen öffnen …") { model.openAccessibility() }
                    .buttonStyle(.link).padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(18).background(Color.orange.opacity(0.075), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.18)))
    }

    private var migrationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 5) {
                Text("Dein bisheriger Finder-Autostart wurde erkannt.").font(.callout.weight(.semibold))
                Text("Übernimm ihn in macTools, um ihn hier zu verwalten. Die bisherige Konfiguration wird gesichert.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("In macTools übernehmen") { model.restart(.finderKeys) }
                    .disabled(!model.accessibilityGranted || model.busy.contains("finder-keys"))
                    .padding(.top, 5)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ToolCard: View {
    @EnvironmentObject private var model: AppModel
    let tool: ToolDefinition
    private var state: ToolSnapshot? { model.snapshots[tool.id] }
    private var busy: Bool { model.busy.contains(tool.id) }
    private var running: Bool { state?.status.isRunning == true }
    private var statusText: String {
        if busy { return "Wird aktualisiert …" }
        if state == nil { return "Wird geprüft …" }
        if running { return state?.legacy == true ? "Aktiv · bisheriger Autostart" : "Aktiv" }
        if state?.enabled == true { return "Start erforderlich" }
        return "Deaktiviert"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 15) {
                Image(systemName: tool.symbol).font(.system(size: 27, weight: .medium))
                    .foregroundStyle(accent).frame(width: 54, height: 54)
                    .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 5) {
                    Text(tool.title).font(.system(size: 20, weight: .semibold))
                    Text(tool.subtitle).font(.subheadline).foregroundStyle(.secondary)
                }.padding(.top, 3)
                Spacer()
                Toggle("Aktiviert", isOn: Binding(
                    get: { state?.enabled == true },
                    set: { model.setEnabled($0, tool: tool) }
                )).toggleStyle(.switch).labelsHidden()
                    .accessibilityLabel("\(tool.title) aktivieren")
                    .disabled(busy || state == nil)
                    .padding(.top, 10)
            }
            Text(tool.summary).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
            HStack(spacing: 22) {
                ForEach(tool.shortcuts.prefix(2), id: \.keys) { shortcut in
                    HStack(spacing: 8) {
                        Text(shortcut.keys).font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(minWidth: 24).padding(.horizontal, 5).padding(.vertical, 5)
                            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.quaternary))
                        Text(shortcut.action).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
            HStack(spacing: 7) {
                Circle().fill(running ? Color.green : (state?.enabled == true ? Color.orange : Color.secondary))
                    .frame(width: 7, height: 7)
                Text(statusText).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                if state?.enabled == true && state?.legacy != true {
                    Button("Erneut starten") { model.restart(tool) }.buttonStyle(.link).disabled(busy)
                }
                Button("Protokoll öffnen") { model.openLogs(tool) }.buttonStyle(.link)
            }
            if state?.enabled == true && !running && !busy {
                Text("Falls das Tool nicht startet, prüfe die Bedienungshilfen-Freigabe und starte es erneut. Details stehen im Protokoll.")
                    .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }
}
