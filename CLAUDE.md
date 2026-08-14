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
- **README.md** — die Außensicht: was die App ist und kann, für jemanden, der das
  Repository zum ersten Mal sieht. Ein neues nutzersichtbares Feature gehört auch hierhin,
  nicht nur in SPEC.md.
- **CLAUDE.md** (dieses Dokument) — wie hier gearbeitet wird: Prinzipien als Kompass,
  Landkarten, Arbeitsregeln. Kein Produktwissen — das steht in den vier oben.

## Code-Landkarte

Zwei Targets (App + Tests), `GlassKanban/` mit rund 10.000 Zeilen SwiftUI; Projektdatei wird von XcodeGen
erzeugt — Änderungen **nur** in `project.yml`, nie im `.xcodeproj`.

- **RemindersStore.swift** — der ganze EventKit-Zugriff: Laden, Sync, Schreiben, Undo,
  Korrektur-Antworten an fremde Schreiber. Mit Abstand die größte Datei und die einzige
  Stelle mit Seiteneffekten. (Die frühere *Tag-Hygiene* ist mit dem Formwechsel vom
  13.08.2026 entfallen — es gibt keine Tags mehr zu pflegen.)
- **ColumnState.swift** — **die Spalte**: welche Karte in welcher Arbeitsspur liegt und
  seit wann, in einer eigenen Datei (`columns.json`).
  Seit 13.08.2026 die einzige Quelle dafür; kein Eintrag heißt Backlog, Erledigt bleibt
  `isCompleted`. Kein anderes **Programm** erreicht diesen Speicher — genau das ist der
  Zweck. Seit 14.08.2026 ist dagegen eine zweite **Instanz dieser App** vorgesehen (der
  eigene zweite Mac): `released` datiert das Ablegen einer Karte, `merged(_:_:now:)`
  führt zwei Rechner zusammen (jüngster gewinnt, Abwesenheit zählt nicht als Aussage,
  Gleichstand geht nach Backlog), und `knownFileURLs` liest von jedem Ort, an dem die
  Datei je lag. **Übertragen wird noch nichts** — das hängt am Developer Program
  (BACKLOG.md, „Gerätesynchronisation über iCloud"; dort steht auch, wann die
  liegengebliebenen Kopien aufgeräumt werden).
- **StatusTagger.swift** — **nur noch Migration**: liest die alten Hashtags einmal je
  Liste ein und schneidet sie danach aus den Notizen — aber **nur bei den IDs, die der
  Import namentlich vermerkt hat** (`ColumnState.pendingTagCleanup`). Diese Einschränkung
  ist nicht kosmetisch: Ohne sie löschte der Lauf am 14.08.2026 ein Wort, das der Nutzer
  gerade selbst getippt hatte („Notiz mit #inprogress darin" → „Notiz mit darin"), weil
  ein Alt-Tag und ein frisches Wort im Text nicht zu unterscheiden sind. Wortgrenzen sind hier weiterhin
  sicherheitskritisch — eine links fehlende Grenze erkannte `#next` mitten in
  `https://example.com/guide#next` und zerstörte damit echten Nutzertext, ohne dass der
  Nutzer je etwas getan hatte (behoben 26.07.2026, siehe `StatusTaggerTests`). Die Datei
  entfällt mit der Aufräumung, frühestens eine Version nach 1.0.
- **Models.swift** — `KanbanStatus`, `KanbanCard`, Filter- und Sortierlogik.
- **Views** — `BoardView` (Board + Dialoge), `ColumnView` (Spalte, Falz, Drop-Ziele),
  `CardView` (Karte, Settle-Animationen, Durchstrich), `TicketEditSheet` (Karten-Editor),
  `StatsPopover`, `FindPopover`, `SettingsView`, `EmptyBoardNotice`, `BoardTooltip`
  (eigenes Glas-Tooltip statt `.help()`), `MoveFeedback` (Klang und Haptik beim Zug),
  `HUDGlassMaterial` (Fenstermaterial), `WindowPlacementController` (hält das Board auf
  seinem Bildschirm — die einzige Stelle, die `NSWindow` anfasst), dazu `ContentView` und
  `GlassKanbanApp`.
- **DesignSystem.swift** — alle Tokens (Farben, Maße, Animationskurven). Neue Werte
  gehören hierher, nicht in die Views.
- **Reine, testbare Regeln ohne UI/EventKit** — `TicketRename`, `EditorKeyCommand`,
  `TextSanitizer`, `BacklogTicketTargeting`, `StreakCalculator`, `WrappedStats`,
  `ReminderDeepLink`, `CorrectionLedger` (Koexistenz mit fremden Schreibern),
  `RecurringHandoff` (Undo-Zaun bei Wiederholungen), `RecurringSeriesMatch` (Durchgang
  ↔ Serie über das Anlegedatum), `RecurringTagRelease` (stille Freigabe eines
  verbrauchten Pulls), `ColumnState` (die Spalte, siehe oben),
  `TicketURL` (was das URL-Feld speichern kann), `WindowPlacement` (auf welchem Bildschirm
  das Board steht und wohin es zurückgehört), `StoredSetting` (jeder
  `UserDefaults`-Wert und ob er dem Nutzer oder dem Rechner gehört — die Einordnung
  steht in einem `switch`, den der Compiler nicht unvollständig lässt; ein neuer Fall
  ohne Entscheidung baut nicht). **Muster für neue Logik:** Entscheidung
  aus der View herausziehen, dann testen.
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
  **Nach jeder Katalog-Änderung `scripts/check-localization.py` laufen lassen, nie
  per Augenmaß.** Es prüft dreierlei, jedes davon aus einem tatsächlich passierten
  Fehler entstanden:
  1. **Vollständigkeit** — jede `String(localized:)`/`LocalizedStringKey`-Stelle hat
     einen Schlüssel. Ein fehlender fällt sonst nicht auf: er zeigt still den
     englischen Quelltext. Fand am 07.08.2026 vier Lücken, die vier Augenpaare
     übersehen hatten, darunter eine reine Anführungszeichen-Abweichung (gerade `"`
     gegen typografische `“ ”`).
  2. **Übersetzung** — jeder Schlüssel trägt `en` *und* `de` im Zustand `translated`.
  3. **Plurale** — jeder Schlüssel mit Zähler trägt entweder `variations.plural` oder
     steht mit Begründung auf der Ausnahmeliste im Skript. **Diese Prüfung fehlte beim
     ersten Durchgang und das hat gekostet:** beim Auflösen von `GermanPlural` gingen
     fünf Pluralregeln verloren, „1 Aufgaben" war zurück — ein Fehlerbild, das im Juli
     2026 schon einmal in genau dieser Form behoben worden war. Vollständigkeit allein
     sagt nichts über Korrektheit.

  **Grenze des Skripts:** Die Ausnahmeliste ist eine *Zusicherung*, keine Messung. Wer
  einen Schlüssel dort einträgt, behauptet „diese Zahl wird nie 1" oder „liest sich bei
  1 sauber" — das kann das Skript nicht nachprüfen. Ausnahmen deshalb sparsam und mit
  echtem Grund; ein umformulierter Satz ohne gebeugtes Substantiv ist besser als ein
  Eintrag in der Liste.
- **Tests** — `GlassKanbanTests/`, 22 Dateien mit rund 340 Tests, benannt nach der Regel
  statt nach der Datei (z. B. `BacklogFoldTests` liegt in `CardSortingTests.swift`).

## Arbeitsweise

- Design- und Verhaltensentscheidungen immer in BACKLOG.md, SPEC.md oder CONCEPT.md
  festhalten (mit Datum), damit sie Sessions überleben. **Das ist keine Bitte, sondern
  wird geprüft:** `scripts/doc-guard.sh` läuft über zwei Hooks in
  `.claude/settings.json` — beim Sessionstart als Hinweis auf geerbte Drift, am Ende
  jedes Zuges als einmalige Nachfrage, wenn der Branch Swift-Dateien, aber keine
  Dokumentation geändert hat. Ist wirklich keine Doku-Änderung nötig, genügt ein
  ausdrücklicher Satz dazu; der Wächter blockt pro Zug nur einmal.
- Vor Änderungen an bestehendem UI-Verhalten `git log --all` auf die betroffene Datei
  prüfen — Feature-History, nicht nur Diff gegen main. **Auch vor vermeintlich neuen
  Features:** Am 14.08.2026 wurde die Bildschirmzuordnung ein zweites Mal gebaut, obwohl
  sie seit dem 10.08. auf einem eigenen Branch lag — und die dort schon gelöste
  Kernschwierigkeit fehlte im Nachbau.
- **Ein Feature ist fertig, wenn ein Lauf das Ergebnis hinterlassen hat** — nicht, wenn es
  baut und die Tests grün sind. Die Bildschirmzuordnung war vier Tage lang „fertig" und
  hat nie funktioniert: Build grün, Tests grün, App startet, sie merkte sich nur nie
  etwas. Der Nachweis ist die geschriebene Datei, der Defaults-Eintrag, die veränderte
  Zeile — etwas, das nach dem Lauf noch da ist.
- **Diagnose in der laufenden App: `os.Logger` ist hier keine verlässliche Quelle.**
  Ausgaben dieser App waren am 14.08.2026 weder über `log show` noch über `log stream`
  auffindbar. Was funktioniert hat: einen Wert nach `UserDefaults` schreiben und die
  Container-plist **direkt** lesen (`plutil -p ~/Library/Containers/…/Preferences/…plist`)
  — `defaults read` zeigte ihn wegen des cfprefsd-Zwischenspeichers ebenfalls nicht.
- **Branches nicht liegen lassen.** Ein Branch, der nicht innerhalb weniger Tage in `main`
  landet, ist verloren: Die Bildschirmzuordnung war nach vier Tagen 42 Commits hinter main
  und musste dateiweise herausgelöst werden, `feature/board-hugs-content` lag am Ende 131
  Commits zurück, `feature/backlog-release-readiness` 179. Gegenbedingung: Zusammengeführt
  wird nur, was **das Verhalten nicht ändert oder nachweislich funktioniert**.
- **Ton der Texte: knapp und sachlich, benennen statt kommentieren.** Die App spricht wie
  ein Werkzeug, nicht wie ein Begleiter — kein Coaching, kein Trost, kein Ansporn.
  Hergeleitet samt sieben Prüffragen und Beispieltabelle in CONCEPT.md („Ton der Texte");
  vor jeder Textänderung dort nachlesen. Drei Regeln, die dort am häufigsten verletzt
  wurden: Besitz benennen, wo der Zustand aus einer eigenen Einstellung folgt („Über
  deinem Limit"); die Frage stellen die Knöpfe, nicht der Meldungstext; und ein Punkt
  steht nur hinter einem vollständigen Satz, nie hinter einer Zahlenzeile. Ein
  Textvorschlag ohne Vorher-Nachher-Gegenüberstellung ist keiner.
- UI-Änderungen selbst per Screenshot prüfen und eigenständig nachbessern; vorher alte
  App-Instanzen aus früheren Sessions beenden.
- **Drag & Drop lässt sich nicht synthetisch auslösen** (14.08.2026 gemessen): Ein per
  computer-use erzeugter Press-Move-Release wird von SwiftUIs Drag-System nicht als Zug
  angenommen — die Karte bleibt liegen, und weil das Board-Fenster sich am Hintergrund
  ziehen lässt, wandert stattdessen das Fenster. Für einen Spaltenwechsel im UI-Test
  deshalb das **Kontextmenü** („Verschieben nach") nehmen: derselbe `move()`-Pfad, nur
  ohne Geste. Die Geste selbst kann nur der Nutzer prüfen. Nebenbefund: Ein Fenster einer
  nicht freigegebenen App (hier Home Assistant) wird aus dem Screenshot herausgefiltert,
  liegt aber weiter davor und blockiert jeden Klick — Fenster verschieben oder maximieren.
- **Tastaturbefunde nie aus synthetischen Tastendrücken ableiten, ohne sie mit einer
  echten Tastatur gegenzuprüfen.** Am 26.07.2026 blieb der Karten-Editor bei einem
  synthetischen Escape scheinbar offen (kein Codefehler — der Monitor erreicht solche
  Ereignisse anders als echte); am 10.08.2026 wiederholte sich dasselbe Muster, als ein
  per `osascript` gesendetes Escape an ein anderes, gerade fokussiertes Fenster ging statt
  an die App. Screenshot-Automatisierung, die Tasten sendet, muss Aktivieren, Taste **und**
  Screenshot in einem Zug ausführen (ein Skript, keine Einzelaufrufe dazwischen) — sonst
  holt sich Claude zwischen den Aufrufen den Fokus zurück.
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
