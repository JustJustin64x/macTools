# macTools

Ein nativer Werkzeugkasten für macOS. In einem Fenster lassen sich kleine Tools
einzeln aktivieren, deaktivieren und bei Bedarf neu starten. Aktivierte Tools laufen
im Hintergrund und starten bei der nächsten Anmeldung automatisch wieder.
Das Schließen des Fensters beendet die Tools nicht.

## Erstes Tool: Finder Enter

| Taste | Verhalten im Finder |
| --- | --- |
| Return / Enter | Ausgewählte Datei oder ausgewählten Ordner öffnen |
| Enter auf dem Ziffernblock | Ebenfalls öffnen |
| F2, je nach Tastatur fn + F2 | Umbenennen |

In Such- und Textfeldern bleibt Enter unverändert. Kombinationen mit Cmd, Ctrl,
Alt oder Shift bleiben unverändert. Außerhalb des Finders greift das Tool nicht ein.

## Starten und automatische Updates

**Cmd + Leertaste → macTools → Enter** öffnet die App über Spotlight.
Der feste Starter liegt unter `/Applications/macTools.app` und öffnet immer die
aktuelle App unter `~/Applications/macTools.app`. Der bestehende Installationsort
bleibt damit auch für die Finder-Berechtigung unverändert.

Updates sind auf diesem Mac auf zwei Wegen eingerichtet:

- **GitHub:** Nach jedem Push auf `main` baut und testet GitHub die App für Apple
  Silicon und Intel und veröffentlicht ein unveränderliches Release. Ein eigener
  Anmeldedienst prüft alle 15 Minuten und bei der Anmeldung auf eine neue Version.
  Er lädt das App-Paket, prüft SHA-256, App-Kennung, Quellversion und Codesignatur
  und installiert es am bestehenden Ort. Zum Aktualisieren werden weder Git noch
  Swift auf dem Ziel-Mac benötigt. Eine neuere lokale Version wird nicht durch
  eine ältere GitHub-Version ersetzt.
- **Lokaler Code:** `make install` aktiviert in diesem Checkout die mitgelieferten
  Git-Hooks. Nach einem Code-Commit oder `git pull` werden Tests, Build und
  Installation automatisch ausgeführt. Reine Dokumentationsänderungen lösen
  keine Installation aus. Bei noch nicht commiteten Änderungen wird die lokale
  Installation verschoben, damit keine gemischte Arbeitsversion installiert wird.

Im Menü **macTools → Nach Updates suchen …** kannst du die GitHub-Prüfung jederzeit
selbst starten. Einstellungen und aktivierte Tools bleiben bei Updates erhalten.
Ein geöffnetes Verwaltungsfenster wird bei einer Installation neu gestartet.
Unveränderte Helper werden nicht überschrieben oder neu gestartet.

**macOS-Berechtigungen:** Das Projekt verwendet derzeit eine Ad-hoc-Signatur,
keine Developer-ID-Signatur. Nach einem Wechsel des signierten Tastaturfilters
kann macOS dessen Bedienungshilfen-Freigabe erneut verlangen. Das lässt sich nicht
zuverlässig automatisch bestätigen. Die App zeigt dann den betroffenen Filter
und eine Schaltfläche zum Auffinden im Finder. Für dauerhaft gleichbleibende
Signaturidentitäten wird eine Developer-ID-Signatur benötigt.

## Voraussetzungen und Installation aus dem Quellcode

- macOS 14 oder neuer
- Für die lokale Entwicklung: Xcode Command Line Tools mit Swift 5.9 oder neuer
- Keine zusätzlichen Pakete oder externen Abhängigkeiten

```sh
git clone https://github.com/JustJustin64x/macTools.git
cd macTools
make test
make install
```

Nach der Installation kannst du macTools über Spotlight starten. `make app`
erstellt nur das App-Paket unter `dist/macTools.app`, ohne zu installieren.
Fertige App-Pakete findest du unter
[GitHub Releases](https://github.com/JustJustin64x/macTools/releases/latest).

Beim ersten Aktivieren von **Finder Enter** benötigt nur dessen Helper eine
Bedienungshilfen-Freigabe. Füge unter **Datenschutz & Sicherheit → Bedienungshilfen**
über **+** diese Datei hinzu und aktiviere den Eintrag:

```text
~/Applications/macTools.app/Contents/Helpers/finder_keys
```

Cmd+Shift+G erlaubt im Auswahldialog die Eingabe des vollständigen Pfades.
Ein alter `finder_keys`-Eintrag aus einem anderen Ordner gilt nicht automatisch
für den aktuellen Helper. Anschließend im macTools-Fenster **Erneut starten**
wählen. Die Verwaltungsoberfläche selbst benötigt keine Bedienungshilfen-Freigabe.

Die App zeigt die tatsächlich laufenden Tools an. Ein eingeschalteter Schalter
bedeutet, dass der Autostart eingerichtet ist. **Aktiv** bedeutet, dass der
Hintergrundprozess läuft. Die App darf für den Tool-Autostart nicht verschoben
werden; der Spotlight-Starter bleibt ebenfalls am festen Ort.

## Vorhandenen Finder-Autostart übernehmen

Die App erkennt die bisherige Konfiguration `local.finder-keys.plist`. Sie bleibt
zunächst aktiv, damit die bestehende Funktion während der Einrichtung erhalten
bleibt. Nach der Freigabe des Finder-Helpers kannst du **In macTools übernehmen** wählen.
Dabei wird die alte Konfiguration unter
`~/Library/Application Support/macTools/Backups/` gesichert und der alte Prozess
beendet, bevor der neue startet. Es laufen dadurch keine zwei Filter gleichzeitig.

Beim Deaktivieren wird das Tool beendet und sein Autostart entfernt. Die App selbst
startet nicht automatisch als Fenster; nur aktivierte Tools starten im Hintergrund.

## Projektstruktur

```text
Sources/
  MacTools/                 SwiftUI-Fenster, Zustand und Programmeinstieg
  MacToolsCore/             Tool-Katalog, LaunchAgents und Prozessstatus
  MacToolsUpdater/          Download und Prüfung von GitHub-Updates
  FinderKeys/               Objective-C-Implementierung von Finder Enter
    include/                Öffentliche C-Schnittstelle für Swift
Tools/
  finder-keys/              Tool-spezifische Dokumentation
Tests/
  MacToolsCoreTests/         Tests für Konfiguration und Statusauswertung
Resources/                  App-Metadaten
scripts/                    App bauen und installieren
.github/workflows/          Automatische Builds und Tests auf macOS
Package.swift               Swift-Package-Konfiguration
Makefile                    Gemeinsame Entwicklungsbefehle
```

## Entwicklung und Tests

```sh
make build                  # Debug-Build
make test                   # Core-Tests und native Tasten-Selbsttests
make app                    # Release-App erstellen und lokal signieren
make install                # App installieren; bestehende App vorher sichern
make run                    # Installierte App öffnen
make check                  # Rechte und Tastaturfilter prüfen
make check-updates          # GitHub-Version prüfen, ohne Installation
make update                 # GitHub-Update sofort installieren
```

Das Fenster und die Hintergrundprozesse sind getrennte Programme im selben
App-Paket. Dadurch bleibt das Fenster auch bei laufenden Tools unabhängig nutzbar:

```sh
# Diagnose ohne Fenster
~/Applications/macTools.app/Contents/Helpers/finder_keys --check

# Nativer Selbsttest, ohne Bedienungshilfen-Freigabe
swift run macTools --self-test
```

Für eine manuelle Diagnose mit
`~/Applications/macTools.app/Contents/Helpers/finder_keys --verbose` das Tool zuerst
im Fenster deaktivieren, damit nur eine Instanz läuft. Die Diagnose protokolliert
App-Kennungen, Fokusrollen und Entscheidungen für Enter/F2, aber keine Dateinamen
oder Texteingaben. Die Core-Tests laufen als eigenständiges Swift-Programm auch ohne XCTest.
Die automatisierten Tests ersetzen nicht den praktischen Test
mit echten Tasten im Finder: Ordner und Datei öffnen, F2 zum Umbenennen, Enter zum
Bestätigen und im Suchfeld sowie das Verhalten außerhalb des Finders prüfen.

## Ein weiteres Tool hinzufügen

1. Implementierung in einem eigenen Target unter `Sources/` anlegen.
2. Das Target in `Package.swift` eintragen und mit `MacTools` verknüpfen.
3. Einen Eintrag in `ToolDefinition.catalog` ergänzen: stabile ID, Name,
   Beschreibung, Kategorie, Symbol, Helper-Dateiname und gegebenenfalls Tastenkürzel.
4. Einen kleinen Helper-Einstieg unter `Tools/<id>/` ergänzen und den Build in
   `scripts/build-app.sh` eintragen. Der signierte Helper gehört nach
   `Contents/Helpers/` und darf kein App-Fenster öffnen.
5. Tests und eine Dokumentation unter `Tools/<id>/` ergänzen.

Katalog, Fenster und Autostart-Verwaltung sind toolübergreifend. Die Oberfläche
listet nur tatsächlich implementierte Tools auf.

## Speicherorte und Deinstallation

- Spotlight-Starter: `/Applications/macTools.app`
- App: `~/Applications/macTools.app`
- Update-Dienst: `~/Library/LaunchAgents/io.github.justjustin64x.macTools.updates.plist`
- Update-Protokolle: `~/Library/Logs/macTools/updates/`
- Autostart pro Tool: `~/Library/LaunchAgents/io.github.justjustin64x.macTools.<id>.plist`
- Protokolle: `~/Library/Logs/macTools/<id>/`
- Sicherungen: `~/Library/Application Support/macTools/Backups/`

Zum Abschalten automatischer GitHub-Updates:

```sh
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/io.github.justjustin64x.macTools.updates.plist
mv ~/Library/LaunchAgents/io.github.justjustin64x.macTools.updates.plist ~/Library/LaunchAgents/io.github.justjustin64x.macTools.updates.plist.disabled
```

Lokale Git-Hooks lassen sich mit `git config --local --unset core.hooksPath`
abschalten. Ein einzelner Commit kann mit `MACTOOLS_SKIP_AUTO_INSTALL=1 git commit …`
ohne automatische Installation erfolgen.

Zum Deinstallieren zuerst die automatischen Updates abschalten und alle Tools
im Fenster deaktivieren. Anschließend macTools beenden und beide App-Pakete in
den Papierkorb legen. Die Protokolle und Sicherungen können
bei Bedarf separat entfernt werden.
