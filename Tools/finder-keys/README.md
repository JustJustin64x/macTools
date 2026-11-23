# Finder Enter

Die Implementierung liegt unter `Sources/FinderKeys/`. Sie wird über eine kleine
C-Schnittstelle eingebunden. `Tools/finder-keys/main.m` ist der Einstieg für den
separaten Helper unter `macTools.app/Contents/Helpers/finder_keys`. Dieser startet
ausschließlich den Hintergrundfilter, während das Fenster unabhängig davon läuft.

Die aktive Anwendung wird über `NSWorkspace.frontmostApplication` ermittelt.
Erst wenn dies der Finder ist, wird dessen fokussiertes Accessibility-Element
geprüft. Kann der Fokus nicht gelesen werden oder handelt es sich um ein Textfeld,
bleibt die Taste unverändert.

Für das Öffnen erzeugt der Filter ein neues Cmd+O-Tastaturereignis. Das bloße
Ändern des ursprünglichen Return-Ereignisses funktionierte auf dem Testsystem
nicht zuverlässig. Die Entscheidung beim Drücken gilt auch für das Loslassen,
selbst wenn das Öffnen inzwischen eine andere Anwendung aktiviert hat.

Die native Testsuite prüft Return, Ziffernblock-Enter, F2, Modifikatoren und
zusammengehörige Key-down-/Key-up-Ereignisse. macTools benötigt für den Einsatz
die Bedienungshilfen-Freigabe. Bei der lokalen Ad-hoc-Signatur muss auch der
Helper `macTools.app/Contents/Helpers/finder_keys` separat freigegeben werden;
ein vorhandener Eintrag für das frühere Programm im Projektordner reicht nicht. Ein automatischer Neustart nach einem Fehler ist
bewusst nicht eingerichtet, damit fehlende Rechte keine wiederholten
Berechtigungsdialoge auslösen.
