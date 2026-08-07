# Glass Kanban — Arbeitsregeln

## Die drei Design-Prinzipien

Jede Feature-, UI- und Text-Entscheidung wird gegen diese drei Fragen geprüft. Sie sind
gleichrangig; ausführlich hergeleitet in CONCEPT.md (Abschnitte „Motivation" und
„Design-Anspruch") — dieses Dokument ist nur der Kompass, CONCEPT.md die Quelle.

1. **Minimalismus** — Nimmt das Element Rauschen weg oder fügt es welches hinzu?
   Vibe-Referenz: Minimal-Desk-Setup. Feste Regeln: Glas ist Chrome, nie Inhalt.
   Höchstens eine Einladung auf dem Board, und nur dort, wo Nichtstun etwas kostet.
   Kein Dauertext, kein Dauer-Badge, keine Karten-Tooltips. Wissen entsteht im Moment
   der Berührung, nicht über Onboarding.
2. **Psychologische Wirksamkeit** — Belohnen, nie bestrafen. Bewegung und Aufmerksamkeit
   gehören Ereignissen (gerade passiert), nie Dauerzuständen. Reibung statt Verbot
   (WIP-Dialog als Muster). Belohnungen bleiben klein und sicher — keine Fanfare, keine
   Eskalation. Zahlen dürfen nie als stehende Anklage wirken (vgl. gefensterte
   Durchlaufzeit, keine „0" in der Streak-Pille).
3. **Kanban als Gestaltungsmaßstab** — Personal Kanban wiegt bei jeder Designfrage mit,
   nicht nur im Datenmodell. Pull-Prinzip: Der freie Platz ruft, keine Karte wird zum
   Favoriten erklärt. WIP begrenzt begonnene Arbeit, nicht Planung. Regeln sind sichtbar
   („make policies explicit").

Stellt ein Vorschlag zwei Prinzipien gegeneinander: Spannung benennen und die Abwägung in
BACKLOG.md oder CONCEPT.md dokumentieren, nicht still entscheiden.

## Dokument-Landkarte

- **CONCEPT.md** — das Warum: Philosophie, Prinzipien, Herleitungen.
- **SPEC.md** — das Was: verbindliches, gebautes Verhalten.
- **BACKLOG.md** — das Später und das Nie: vor jedem UI-Vorschlag den Abschnitt
  „Explizit abgelehnt" prüfen; abgelehnte Ideen nicht wieder vorschlagen, ohne dass der
  Nutzer das Thema selbst öffnet.
- **RELEASE.md** — einzige Wahrheit zum Mac-App-Store-Release.

## Code-Landkarte

Ein Xcode-Target (`GlassKanban/`, ~8.000 Zeilen SwiftUI), Projektdatei wird von XcodeGen
erzeugt — Änderungen **nur** in `project.yml`, nie im `.xcodeproj`.

- **RemindersStore.swift** — der ganze EventKit-Zugriff: Laden, Sync, Schreiben, Undo,
  Tag-Hygiene. Mit Abstand die größte Datei und die einzige Stelle mit Seiteneffekten.
- **StatusTagger.swift** — Hashtag lesen/schreiben/migrieren. Wortgrenzen sind hier
  sicherheitskritisch (siehe FINDINGS A1: eine fehlende Grenze zerstörte Nutzertext).
- **Models.swift** — `KanbanStatus`, `KanbanCard`, Filter- und Sortierlogik.
- **Views** — `BoardView` (Board + Dialoge), `ColumnView` (Spalte, Falz, Drop-Ziele),
  `CardView` (Karte, Settle-Animationen, Durchstrich), `TicketEditSheet` (Karten-Editor),
  `StatsPopover`, `FindPopover`, `SettingsView`, `EmptyBoardNotice`.
- **DesignSystem.swift** — alle Tokens (Farben, Maße, Animationskurven). Neue Werte
  gehören hierher, nicht in die Views.
- **Reine, testbare Regeln ohne UI/EventKit** — `TicketRename`, `EditorKeyCommand`,
  `TextSanitizer`, `BacklogTicketTargeting`, `StreakCalculator`, `WrappedStats`,
  `ReminderDeepLink`. **Muster für neue Logik:** Entscheidung aus der View
  herausziehen, dann testen.
- **`Localizable.xcstrings`/`InfoPlist.xcstrings`** — String Catalogs, Englisch Quelle,
  Deutsch vollwertige Lokalisierung (seit 07.08.2026, siehe RELEASE.md Phase 1). **Regel
  fürs Testziel:** Die reinen Logik-Dateien oben werden ohne App-Host direkt ins
  Testbundle kompiliert (`project.yml`, `GlassKanbanTests`-Target) — dort ist
  `Bundle.main` der `xctest`-Runner, der Katalog wird nie gefunden. Deshalb dürfen
  diese Dateien nur **nicht-interpolierte** `String(localized:)`-Aufrufe enthalten,
  bei denen der Rückfall auf den Schlüssel (= englischer Text) ein brauchbares
  Ergebnis ist (z. B. `KanbanStatus.displayName`). **Jeder Plural und jeder
  interpolierte Satz gehört in die View-Ebene** des App-Ziels, wo der Katalog
  tatsächlich lädt.
  **Nach jeder Katalog-Änderung skriptgeprüft, nie per Augenmaß:** jede
  `String(localized:)`/`LocalizedStringKey`-Stelle gegen die Schlüssel diffen
  (Interpolationen normalisieren) und gegenprüfen, dass jeder Schlüssel `en` und
  `de` im Zustand `translated` trägt. Ein fehlender Schlüssel fällt sonst nicht
  auf — er zeigt still den englischen Quelltext. Beim ersten Durchgang
  (07.08.2026) fand genau diese Prüfung vier Lücken, die vier Augenpaare
  übersehen hatten, darunter eine reine Anführungszeichen-Abweichung (gerade `"`
  gegen typografische `“ ”`).
- **Tests** — `GlassKanbanTests/`, 14 Dateien, benannt nach der Regel statt nach der
  Datei (z. B. `BacklogFoldTests` liegt in `CardSortingTests.swift`).

## Arbeitsweise

- Design- und Verhaltensentscheidungen immer in BACKLOG.md, SPEC.md oder CONCEPT.md
  festhalten (mit Datum), damit sie Sessions überleben. **Das ist keine Bitte, sondern
  wird geprüft:** `scripts/doc-guard.sh` läuft über zwei Hooks in
  `.claude/settings.json` — beim Sessionstart als Hinweis auf geerbte Drift, am Ende
  jedes Zuges als einmalige Nachfrage, wenn der Branch Swift-Dateien, aber keine
  Dokumentation geändert hat. Ist wirklich keine Doku-Änderung nötig, genügt ein
  ausdrücklicher Satz dazu; der Wächter blockt pro Zug nur einmal.
- Vor Änderungen an bestehendem UI-Verhalten `git log --all` auf die betroffene Datei
  prüfen — Feature-History, nicht nur Diff gegen main.
- UI-Änderungen selbst per Screenshot prüfen und eigenständig nachbessern; vorher alte
  App-Instanzen aus früheren Sessions beenden.
- CLI-Builds/Tests mit `-derivedDataPath` außerhalb von `~/Documents` laufen lassen
  (iCloud-xattrs verursachen sonst CodeSign-Fehler).
- `Glass Kanban.app` liegt direkt im Projektordner und ist immer ein aktueller,
  doppelklickbarer Build — ohne Nachfrage. `scripts/build-app.sh` läuft über dieselben
  zwei Hooks wie der Doku-Wächter (SessionStart, Stop), prüft nur einen Fingerprint der
  Quellen (Millisekunden) und stößt bei Änderung einen Build als abgekoppelten
  Hintergrundprozess an — kein Zug wartet auf `xcodebuild`. Gebaut wird weiterhin nach
  `~/Library/Caches/GlassKanban/DerivedData` (außerhalb iCloud, siehe Punkt oben), das
  fertige, bereits signierte Bundle wird dann direkt in den Projektordner kopiert.
  Dadurch synct `~/Documents` die App bei jedem Build neu — bewusst in Kauf genommen,
  keine Automatik ohne Weiteres um diesen Punkt herum. Bekannte Nebenwirkung frisch
  geschriebener Dateien in iCloud Drive: macOS markiert sie mit `com.apple.quarantine`
  und würde die App sonst aus einem randomisierten Temp-Pfad statt dem echten
  Projektordner starten (Gatekeeper-Translokation) — das Skript entfernt das Attribut
  nach jedem Kopiervorgang und heilt es bei jedem Hook-Aufruf nach, falls iCloud es
  nachträglich erneut setzt. Ein fehlgeschlagener Build wird einmal pro Fingerprint
  gemeldet, sonst bleibt es still. Manuell: `scripts/build-app.sh --manual` (synchron,
  mit Ausgabe) oder `--release` für einen optimierten Build.
