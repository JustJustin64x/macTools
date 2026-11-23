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

## Voraussetzungen und Installation

- macOS 14 oder neuer
- Xcode Command Line Tools mit Swift 5.9 oder neuer (`xcode-select --install`)
- Keine zusätzlichen Pakete oder externen Abhängigkeiten

```sh
git clone https://github.com/JustJustin64x/macTools.git
cd macTools
make test
make install
make run
```

Die App wird unter `~/Applications/macTools.app` installiert. Das kann nach dem
Bauen auch direkt im Finder geöffnet werden. `make app` erstellt die App nur unter
`dist/macTools.app`, ohne sie zu installieren.

1. Öffne macTools.
2. Öffne über den Hinweis im Fenster die Bedienungshilfen-Einstellungen.
3. Füge **macTools.app** unter **Datenschutz & Sicherheit → Bedienungshilfen**
   hinzu und aktiviere die Freigabe. Im Auswahldialog führt Cmd+Shift+G zu
   `~/Applications/macTools.app`.
4. Füge für den eigenständigen Tastaturfilter zusätzlich
   `~/Applications/macTools.app/Contents/Helpers/finder_keys` hinzu und aktiviere
   auch diesen Eintrag. Cmd+Shift+G erlaubt im Auswahldialog die Eingabe des
   vollständigen Pfades. Ein alter `finder_keys`-Eintrag aus dem ursprünglichen
   Projektordner gilt nicht automatisch für den neuen Helper.
5. Aktiviere **Finder Enter** mit dem Schalter beziehungsweise wähle
   **Erneut starten**, wenn die Freigabe erst nach dem Start erteilt wurde.

Die App zeigt die tatsächlich laufenden Tools an. Ein eingeschalteter Schalter
bedeutet, dass der Autostart eingerichtet ist. **Aktiv** bedeutet, dass der
Hintergrundprozess läuft. Bei fehlenden Rechten oder einem fehlgeschlagenen Start
zeigt die App einen Hinweis und bietet **Erneut starten** sowie das Protokoll an.

Für den Start bei der Anmeldung darf die installierte App nicht verschoben werden.
Die lokale Entwicklung verwendet eine Ad-hoc-Signatur. Nach einem Neubau kann es
nötig sein, macTools in den Bedienungshilfen erneut freizugeben. Für die Verteilung
an andere Macs ist eine Developer-ID-Signatur mit Notarisierung vorgesehen, in
diesem Projekt aber noch nicht eingerichtet.

## Vorhandenen Finder-Autostart übernehmen

Die App erkennt die bisherige Konfiguration `local.finder-keys.plist`. Sie bleibt
zunächst aktiv, damit die bestehende Funktion während der Einrichtung erhalten
bleibt. Nach der Freigabe von macTools und des Finder-Helpers kannst du **In macTools übernehmen** wählen.
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

- App: `~/Applications/macTools.app`
- Autostart pro Tool: `~/Library/LaunchAgents/io.github.justjustin64x.macTools.<id>.plist`
- Protokolle: `~/Library/Logs/macTools/<id>/`
- Sicherungen: `~/Library/Application Support/macTools/Backups/`

Zum Deinstallieren zuerst alle Tools im Fenster deaktivieren, macTools beenden
und danach die App in den Papierkorb legen. Die Protokolle und Sicherungen können
bei Bedarf separat entfernt werden.
