# Menüleisten-Panel: Ergänzungen — Bauplan (12.09.2026)

Entschieden am 12.09.2026 (BACKLOG.md, „Fensterverhalten" → „Ergänzungen, entschieden am
12.09.2026"). Dieser Plan ist für eine eigene Session geschrieben; die Begründungen stehen
im BACKLOG-Eintrag und werden hier **nicht** neu verhandelt. Kästchen abhaken, Messungen
unten protokollieren. Der Vorgängerplan `plans/menubar-tablett.md` beschreibt den Bau des
Panels selbst; sein Schritt 4c ist überholt, seine Messungen gelten.

## Zuerst lesen (in dieser Reihenfolge)

1. `CLAUDE.md` — ganz. Vor allem: die drei Prinzipien, „Arbeitsweise" (ein Feature ist
   fertig, wenn ein Lauf etwas hinterlassen hat; Tastaturbefunde nie aus synthetischen
   Tastendrücken ableiten; Build außerhalb `~/Documents`).
2. `SPEC.md`, „Menüleiste: das Tablett" und „Anzeigen in" — das gebaute Panel.
3. `CONCEPT.md`, „Design-Anspruch" (bis „Grenze der Regel (12.09.2026)") und „Ton der
   Texte" (vor jedem neuen String; die sieben Fragen).
4. `BACKLOG.md`, der Eintrag oben, und „Explizit abgelehnt" (Tastaturfokus auf Karten,
   Karten-Tooltips — beides gilt auch im Panel).
5. Code, in dieser Reihenfolge: `GlassKanban/MenuBarTrayView.swift` (ganz — `TraySection`,
   `TrayRow`, `BacklogHead`, `TrayActionRow`, `OverflowQuestionRow`),
   `MenuBarTrayController.swift` (`TrayPanel`, `TrayGlassController`, `TrayAnchor`),
   `MenuBarTray.swift`, `DesignSystem.swift` (Block „The menu bar tray"),
   `CardParts.swift`; in `RemindersStore.swift` `createTicketForEditing` (≈ Zeile 1296),
   `targetCalendarForNewTicket`, `openInReminders(cardID:)` (≈ Zeile 2036); in
   `Models.swift` `KanbanCard.daysInColumn` (≈ Zeile 186); in `CardView.swift`
   `agingLabel` und `openInReminders()`; `TicketRename.swift` und `TextSanitizer.swift`
   (wie ein Titel bereinigt wird); `SettingsView.swift`, Section „Menu Bar";
   `StoredSetting.swift`.

## Ziel

Fünf Ergänzungen am Panel: Symbole vor den vier Köpfen, die Verweildauer in „In
Bearbeitung", „In Erinnerungen öffnen" im Kontextmenü, eine Schnellerfassung ins Backlog
unter dem Backlog-Kopf, und ein globaler Kurzbefehl zum Öffnen des Panels. Jede reist
über die vorhandenen Store-Pfade; keine baut ein zweites Werkzeug.

## Nicht-Ziel

Kein Editor im Panel (Titel genügt, alles Weitere hat das Board). Keine Tastaturnavigation
über Zeilen (Kartenfokus ist abgelehnt) — der Fokus im Panel gehört allein dem Textfeld
der Erfassung, solange es offen ist. Kein ⌘Z im Panel (SPEC). Kein Zustand am
Menüleisten-Symbol. Keine Symbole auf dem Board.

## Regeln, die beim Bauen gelten

- **Alle Werte aus `DesignSystem.swift`.** Neue Maße (Symbolfeld) gehören dorthin.
- **Kein zweiter Schreibpfad.** Erfassung → eine Store-Funktion neben
  `createTicketForEditing`, mit derselben Listenwahl (`targetCalendarForNewTicket`).
- **Entscheidungen aus der View heraus, dann testen:** Symbolzuordnung, Kurzbefehl-Typ,
  Sichtbarkeitsregel der Verweildauer sind reine Regeln im Testziel.
- **Strings:** Englisch im Code, Deutsch im Katalog; nach jeder Änderung
  `python3 scripts/check-localization.py`. Keine interpolierten `String(localized:)` in
  Dateien des Testziels. Vorher/Nachher für jeden neuen Satz, Ton nach CONCEPT.md.
- **Ein Branch:** auf `feature/menubar-tray` weiterbauen, solange PR #55 offen ist; sonst
  `feature/menubar-panel-additions` von `main`. Nicht liegen lassen.
- **Nach jedem Schritt bauen; nach 1, 2, 4, 5 testen; nach 1, 2, 4 Fensterbild prüfen.**

## Befehle

```bash
xcodegen generate
```

```bash
xcodebuild -project GlassKanban.xcodeproj -scheme GlassKanban -derivedDataPath ~/Library/Caches/GlassKanban/DerivedData build 2>&1 | tail -20
```

```bash
xcodebuild -project GlassKanban.xcodeproj -scheme GlassKanban -derivedDataPath ~/Library/Caches/GlassKanban/DerivedData test 2>&1 | grep -E "Executed .* tests, with|error:" | tail -3
```

```bash
python3 scripts/check-localization.py
```

**Panel am Bildschirm prüfen, ohne Bildschirmübernahme** (bewährt 11./12.09.2026): App
aus `~/Library/Caches/GlassKanban/DerivedData/Build/Products/Debug/` starten, Finder nach
vorn (`osascript -e 'tell application "Finder" to activate'`), Panel per
`osascript -e 'tell application "System Events" to tell process "Glass Kanban" to click menu bar item 1 of menu bar 2'`
öffnen, Fenster-ID über `CGWindowListCopyWindowInfo` (Owner „Glass Kanban", Breite 340)
ermitteln und den **Bildschirmausschnitt** mit `screencapture -x -R x,y,w,h` nehmen — ein
Fensterbild (`-l`) zeigt bei Liquid Glass nur die Füllung, nicht die Refraktion. Für
Vergrößerungen `PIL` (`Image.crop(...).resize(..., NEAREST)`). Die Einstellung „Anzeigen
in" per `defaults write ~/Library/Containers/com.davidtrogemann.GlassKanban/Data/Library/Preferences/com.davidtrogemann.GlassKanban appPresence both`
bei beendeter App setzen. Nachweise in `UserDefaults` direkt aus der plist lesen
(`plutil -p …/com.davidtrogemann.GlassKanban.plist`), nicht mit `defaults read`.

---

## Schritt 0 — Messen, bevor Code entsteht

### M1 — Nimmt ein Textfeld im nicht aktivierenden Panel Tastatureingaben an, während eine andere App vorn ist?

Die Erfassung steht und fällt damit. `TrayPanel` kann Key werden (`canBecomeKey`), aber
Key-Fenster einer nicht aktiven App bekommen Tastatur nur, wenn macOS das Panel wie
Spotlight behandelt.

- [ ] Wegwerf-Aufbau: in `MenuBarTrayView.tray` unter `BacklogHead` ein
      `TextField("Probe", text: $probe)` mit `.focused($probeFocus)` und
      `.onAppear { probeFocus = true }`; `.onSubmit { UserDefaults.standard.set(probe, forKey: "probeCapture") }`.
- [ ] App starten, Finder nach vorn, Panel öffnen, **mit der echten Tastatur** ein Wort
      tippen und Return drücken (CLAUDE.md: Tastaturbefunde nie synthetisch). Nachweis:
      `probeCapture` in der plist.
- [ ] Beobachten: Bekommt das Feld den Fokus ohne Klick? Bleibt Finder die aktive App
      (Menüleiste zeigt „Finder")? Schließt Escape das Feld/Panel?

**Weiche:**
- *Tippen kommt an, App bleibt inaktiv* → Schritt 4 wie beschrieben.
- *Tippen kommt nicht an* → in `open()` vor `makeKey()` ein `NSApp.activate()`
  **nur, wenn die Erfassung geöffnet wird** (nicht beim bloßen Öffnen des Panels — das
  Panel soll die App nicht nach vorn holen); nach Return/Escape die vorherige App wieder
  aktivieren (`NSRunningApplication` der zuvor frontmost App merken, `.activate()`). Im
  Protokoll festhalten. Bleibt auch das aus → Erfassung im Panel entfällt, die Zeile
  „Neue Aufgabe" öffnet stattdessen das Board mit neuem Ticket (`createTicketForEditing`
  + Editor), und BACKLOG bekommt den Befund.

### M2 — Feuert `RegisterEventHotKey` (Carbon) in der Sandbox, auch bei `.accessory`?

Der einzige Weg zu einem globalen Kurzbefehl ohne Bedienungshilfen-Berechtigung und ohne
Fremdpaket. Er ist alt, aber in Sandbox-Apps erlaubt.

- [ ] Wegwerf-Aufbau in `AppearanceDelegate.applicationDidFinishLaunching`:
      `RegisterEventHotKey(UInt32(kVK_ANSI_K), UInt32(cmdKey | optionKey), EventHotKeyID(signature: OSType(0x474B4E42), id: 1), GetEventDispatcherTarget(), 0, &ref)`
      plus `InstallEventHandler` für `kEventHotKeyPressed`, das
      `UserDefaults.standard.set(Date(), forKey: "probeHotkey")` schreibt.
- [ ] Bauen, starten, Finder nach vorn, ⌥⌘K **mit der echten Tastatur**; Nachweis in
      der plist. Dann „Anzeigen in" auf „Menüleiste" (Policy `.accessory`) und noch einmal.
- [ ] Zweite Instanz der Probe (oder eine andere App mit demselben Kürzel): gibt
      `RegisterEventHotKey` einen Fehler zurück (`eventHotKeyExistsErr`)? Das entscheidet,
      ob Schritt 5 Konflikte melden kann.

**Weiche:**
- *Feuert in beiden Policies* → Schritt 5 wie beschrieben.
- *Feuert nicht* → Schritt 5 entfällt; BACKLOG bekommt den Befund und den Hinweis auf
  App Intents („Spätere Apple-/Mac-Ausbaustufen") als späteren Weg.

### M3 — Nachholen: Hover- und Ablegeglas

Am 12.09.2026 gebaut, aber nicht gesehen (Bildschirmfreigabe kam nicht durch): Hover als
`.glassEffect(.regular)` auf `TrayRow`/`TrayActionRow`/`BacklogHead`, Ablegeziel als
akzentgetöntes Glas auf `TraySection`.

- [ ] Mit echter Maus über eine Zeile fahren, eine Zeile in einen anderen Abschnitt
      ziehen. Liest sich die Hervorhebung als hellere Glasschicht — oder als zweites,
      härteres Rechteck?
- *Zweites Rechteck* → Rückfall: `Board.trayRowShape.fill(Color.primary.opacity(Board.trayHoverTint))`
  bzw. `Color.accentColor.opacity(Board.trayDropTint)`; Token `trayHoverTint` existiert.

---

## Schritt 1 — Symbole vor den Köpfen

**`Models.swift`** (Testziel): auf `KanbanStatus` eine Zuordnung, gepinnt per Test —
Symbole sind ein Vertrag mit dem Auge des Nutzers, kein Zufallswert:

```swift
/// The stage as a glyph, for the menu bar panel's section heads (SPEC.md,
/// "Menüleiste"). The system's own task vocabulary: the inbox, then three
/// circles filling up. Not used on the board — there the lane explains
/// itself through the cards in it.
var traySymbolName: String {
    switch self {
    case .backlog: "tray"
    case .next: "circle"
    case .inProgress: "circle.lefthalf.filled"
    case .done: "checkmark.circle"
    }
}
```

**`DesignSystem.swift`:** `Board.traySymbolSlot: CGFloat = 16` — das Feld vor dem Namen,
**und dasselbe Feld für den Punkt der Zeilen** (`TrayRow`: `Circle().frame(width: trayDotSize)`
in einem `frame(width: traySymbolSlot)`), damit Kopftext und Zeilentitel in einer Flucht
stehen. Abstand Feld → Text: 6 pt (heute 8 zwischen Punkt und Titel — auf 6 vereinheitlichen).

**`MenuBarTrayView.swift`:** in `TraySection.header` und `BacklogHead` vor dem Namen
`Image(systemName: status.traySymbolName).font(BoardText.chip).frame(width: Board.traySymbolSlot)`,
sekundär wie der Text, `.accessibilityHidden(true)` (der Name steht daneben).

- [ ] `traySymbolName` + Test (`MenuBarTrayTests`: vier Werte gepinnt; alle vier
      verschieden; `NSImage(systemSymbolName:)` liefert für jeden ein Bild — der Test darf
      AppKit importieren, das Testziel tut es schon in `AppPresenceTests`).
- [ ] Token, Kopf, Zeilenpunkt im selben Feld.
- [ ] Fensterbild hell und dunkel, vergrößert: Symbole 11 pt, sekundär; **Kopftext und
      Zeilentitel beginnen auf derselben x-Position**; die Zahlen rechts bleiben in ihrer
      Flucht (Chevron-Feld unverändert).

## Schritt 2 — Verweildauer in „In Bearbeitung"

**Regel** (`MenuBarTray.swift`, Testziel):

```swift
/// Which rows say how long they have been sitting: only "In Bearbeitung",
/// only from the board's own threshold on. The tray is for finishing, and
/// "this has been started for five days" is the one fact that helps with
/// that; on the other sections it would be a number without a question.
static func showsDwellTime(status: KanbanStatus, days: Int?) -> Bool {
    guard status == .inProgress, let days else { return false }
    return days >= Board.agingThresholdDays
}
```

`Board.agingThresholdDays` liegt in `DesignSystem.swift` (App-Ziel). Entweder die Zahl
nach `Models.swift` ziehen (dann `Board.agingThresholdDays = KanbanCard.agingThresholdDays`),
oder `days >= threshold` als Parameter — ersteres, damit es **eine** Zahl bleibt.

**`TrayRow`:** rechts, vor dem Badge, `Text("\(days) days")` (Schlüssel `%lld days`
existiert, Pluralregel vorhanden) in `BoardText.meta`, sekundär, `monospacedDigit`. Kein
Uhr-Glyph (das Board hat ihn in der vollen Karte; in der Menüzeile ist die Zahl genug).
VoiceOver: `CardParts.accessibilityLabel` spricht „In dieser Spalte seit N Tagen" bereits.

- [ ] Regel + Tests (nur `.inProgress`; `nil` → false; Schwelle − 1 → false; Schwelle → true).
- [ ] Zeile; Fensterbild mit einer alten Karte (Karte per Kontextmenü auf dem Board nach
      „In Bearbeitung" ziehen und `pulledAt` in `columns.json` **nicht** fälschen — statt
      dessen `Board.agingThresholdDays` **temporär** auf 0 setzen, Bild machen, zurück).

## Schritt 3 — „In Erinnerungen öffnen" im Kontextmenü

**`TraySection.row(for:)`:** das `.contextMenu` bekommt für **jede** Zeile — auch Erledigt,
das bisher keins hat — `Button("Open in Reminders")` (Schlüssel existiert), darunter für
bewegliche Zeilen ein `Divider()` und das vorhandene `Menu("Move to")`. Reihenfolge wie
`CardView`: erst Öffnen, dann Verschieben.

Aktion: `MenuBarTrayController.shared.close()` **vor** `store.openInReminders(cardID:)` —
der App-Wechsel zu Erinnerungen darf das Panel nicht stehen lassen (dasselbe Muster wie
`openBoard`). VoiceOver: `accessibilityActions` bekommt denselben Knopf.

- [ ] Kontextmenü, Aktion, VoiceOver-Aktion.
- [ ] Prüfen: Rechtsklick auf eine Erledigt-Zeile zeigt genau einen Eintrag; auf eine
      Arbeitszeile zwei Gruppen; Erinnerungen öffnet mit der Karte, das Panel ist zu.

## Schritt 4 — Schnellerfassung ins Backlog

**Store (`RemindersStore.swift`):** neben `createTicketForEditing`:

```swift
/// Creates a Backlog ticket from a title alone — the menu bar panel's
/// capture. Same list rule as the "+" (`targetCalendarForNewTicket`), same
/// title clean-up as a rename, no editor: everything else the ticket may
/// need is one click away on the board. No undo entry — the panel has no
/// ⌘Z (SPEC.md), and an entry only the board could reach would surprise
/// there; a captured ticket is taken back by deleting it on the board.
@discardableResult
func createTicket(title: String) -> String? {
    let cleaned = TicketRename.cleaned(title)   // die vorhandene Bereinigung, Name prüfen
    guard !cleaned.isEmpty, let calendar = targetCalendarForNewTicket() else { return nil }
    let reminder = EKReminder(eventStore: eventStore)
    reminder.calendar = calendar
    reminder.title = cleaned
    do { try eventStore.save(reminder, commit: true) } catch {
        scheduleRefreshAfterWrite(); return nil
    }
    if let card = card(from: reminder) { cards.append(card) }   // optimistisch, wie beim "+"
    scheduleRefreshAfterWrite()
    return reminder.calendarItemIdentifier
}
```

`newlyCreatedCardID` wird **nicht** gesetzt: Das ist der Zaun für leere Neuanlagen aus dem
Editor; ein Titel-Ticket ist nie leer.

**Fehlerfall:** `save` kann scheitern (Liste nimmt nichts an — `ReminderWriteFailure`,
CONCEPT.md 09.09.2026). Das Board zeigt dafür `pendingSaveFailure`; das Panel zeigt
stattdessen **inline** unter dem Feld eine Zeile in `BoardText.meta`, sekundär, mit dem
Text aus `ReminderWriteFailure` (derselbe Grund, dieselben Worte) — kein Alert (nimmt den
Fokus, schließt das Panel). Der getippte Titel bleibt im Feld stehen.

**View (`MenuBarTrayView.swift`):** neue `BacklogCaptureRow` direkt unter `BacklogHead`,
innerhalb derselben Gruppe (kein Gruppenabstand dazwischen):

- **Ruhezustand:** eine Zeile in Zeilenhöhe, im Symbolfeld `plus` (11 pt, sekundär),
  daneben `Text("New Task")` in `BoardText.trayRow`, sekundär. Hover wie jede Zeile.
  Klick → Bearbeitungszustand.
- **Bearbeitungszustand:** `TextField("New Task", text: $draft)` (`.textFieldStyle(.plain)`,
  `BoardText.trayRow`, primär) an derselben Stelle, `@FocusState` gesetzt beim Wechsel.
  Return mit Inhalt → `store.createTicket(title:)`, Feld leeren, **Fokus behalten** (mehrere
  Gedanken hintereinander sind der Normalfall). Return ohne Inhalt → Ruhezustand.
  Escape (`onExitCommand`) → Entwurf verwerfen, Ruhezustand. Fokusverlust → Entwurf
  verwerfen, Ruhezustand. Schließt sich das Panel (Klick außerhalb), setzt `onDisappear`
  nichts zurück — das Panel bleibt am Leben; deshalb beim Öffnen (`MenuBarTrayController.open`)
  eine Notification `glassKanbanTrayWillOpen` posten, auf die die Zeile in den
  Ruhezustand geht. Kein Entwurf überlebt ein Schließen: Was im Kopf war, ist nach dem
  Schließen entweder angelegt oder weg — halb Getipptes, das Tage später wieder auftaucht,
  ist Rauschen.
- **Rückmeldung:** keine eigene. Die Zahl im Backlog-Kopf springt (`numericText`), das
  Feld ist leer — das ist der Beleg. Kein Klang (der gehört dem Zug).
- **Sperre:** Während `OverflowQuestionRow` steht, bleibt die Erfassung bedienbar — sie
  ist kein Zug und überschreibt keine Frage.
- **Fokusregel:** `TrayPanel.canBecomeKey` ist da. Nach M1 ggf. die Aktivierungs-Weiche.
  `.focusable()` bekommt **nur** das Textfeld; Zeilen bleiben ohne Fokus (BACKLOG,
  „Explizit abgelehnt").

**Strings:** `New Task` → „Neue Aufgabe" (Vorher: kein Text; Prüfung gegen die sieben
Fragen: benennt, kein Punkt, kein Verb). Das Menü des Boards sagt `New Ticket` — im Panel
bewusst „Aufgabe": Es spricht wie Erinnerungen, aus dem der Gedanke kommt, nicht wie das
Board. Wer die Wörter angleichen will, tut es an **einer** Stelle in SPEC.

- [ ] `createTicket(title:)` im Store; Bereinigungsfunktion beim Namen nennen
      (`TicketRename`/`TextSanitizer` lesen).
- [ ] `BacklogCaptureRow` mit den drei Zuständen; Notification beim Öffnen.
- [ ] Katalog: `New Task`; `check-localization.py` sauber.
- [ ] **Der Lauf, der etwas hinterlässt:** Finder vorn, Panel öffnen, Zeile klicken,
      „Probe 12.09." tippen, Return. Nachweis: die Erinnerung existiert in Erinnerungen
      (Liste = Vorgabeliste bzw. erste gezeigte), das Board zeigt sie im Backlog, die Zahl
      im Kopf ist um eins höher, das Feld ist leer und hat noch den Fokus. Escape → Ruhezeile.
      Danach die Probe löschen (Board, Kontextmenü).

## Schritt 5 — Globaler Kurzbefehl

**Typ (`GlassKanban/TrayShortcut.swift`, Testziel):**

```swift
/// A global key combination, as the user recorded it. Stored as text
/// ("cmd+opt+k"), read back the same way; anything unreadable is "none".
struct TrayShortcut: Equatable, Codable {
    let keyCode: UInt16
    let modifiers: Modifiers            // OptionSet: command, option, control, shift
    /// At least one of ⌘, ⌥, ⌃ — a bare letter or ⇧+letter would swallow typing everywhere.
    var isValid: Bool
    var displayString: String           // "⌥⌘K", Reihenfolge ⌃⌥⇧⌘ wie in Menüs
    static func parse(_ stored: String) -> TrayShortcut?
    var stored: String
}
```

Tests: Rundreise `stored → parse`; `isValid` für ⇧K false, ⌘K true; `displayString`
Reihenfolge; unlesbare Strings → nil.

**Registrierung (`GlassKanban/GlobalHotkey.swift`, App-Ziel):** Carbon
`RegisterEventHotKey`/`UnregisterEventHotKey` + ein `InstallEventHandler` für
`kEventHotKeyPressed`; Klasse `GlobalHotkey` mit `set(_ shortcut: TrayShortcut?) throws`,
Fehler bei `eventHotKeyExistsErr` als eigener Typ. `MenuBarTrayController.start` liest
`StoredSetting.trayShortcut`, registriert, und `toggle()` ist die Aktion. Nur registriert,
solange `showsMenuBarItem` — ohne Symbol kein Panel, also kein Kürzel.

**Einstellung:** `StoredSetting.trayShortcut = "trayShortcut"`, Geltung `.thisDevice`
(Tastatur und Kürzel gehören dem Rechner; ein Kürzel, das auf dem anderen Mac mit einer
dortigen App kollidiert, wäre ein Sync-Schaden). Test in `StoredSettingTests` (Schlüssel
gepinnt, Scope).

**Oberfläche (`SettingsView.swift`, Section „Menu Bar"):** unter „Show In" eine Zeile
`Shortcut` mit einem `ShortcutRecorder` (NSViewRepresentable: ein `NSButton`-artiges Feld,
das im Aufnahmezustand `keyDown` fängt, Escape bricht ab, Backspace/„×" löscht). Anzeige:
`displayString` oder `None`. Fußzeile ergänzt: „The shortcut opens and closes the panel
from any app." (de: „Der Kurzbefehl öffnet und schließt das Panel aus jeder App.").
Konflikt: registriert das System das Kürzel nicht, springt das Feld zurück und zeigt
darunter `In use by another app` (de: „Von einer anderen App belegt") — benennt, kommentiert
nicht. Nur sichtbar, wenn „Anzeigen in" ein Symbol vorsieht; sonst `disabled` mit
demselben Aussehen wie andere deaktivierte Zeilen. `SettingsMetrics.generalHeight` neu
messen (Erwartung ≈ +40).

**Strings:** `Shortcut` → „Kurzbefehl"; `None` → „Keiner" (prüfen, ob ein Schlüssel
`None`/„Kein Limit" schon existiert — nicht wiederverwenden, andere Bedeutung);
`Record Shortcut` → „Kurzbefehl aufnehmen" (Beschriftung im Aufnahmezustand);
`In use by another app` → „Von einer anderen App belegt"; Fußzeilensatz.

- [ ] `TrayShortcut` + Tests; `StoredSetting` + Tests.
- [ ] `GlobalHotkey`; Kopplung an `PresenceController.selection` **und** an die
      Einstellung (beide `@Published`/Notification, `Combine` wie beim Symbol).
- [ ] Recorder; Konfliktfall; Höhe gemessen.
- [ ] **Der Lauf:** Kürzel ⌥⌘K aufnehmen, Einstellungen schließen, Safari vorn, ⌥⌘K mit
      echter Tastatur → Panel öffnet **auf dem Bildschirm des Zeigers**, noch einmal →
      schließt. App beenden, starten → Kürzel gilt noch (plist zeigt `trayShortcut`).
      „Anzeigen in: Dock" → Kürzel tot; zurück → lebt.

## Doku-Pflichten (im selben Branch, vor dem Merge)

- [ ] `SPEC.md`, „Menüleiste: das Tablett": Tabelle um Symbole, Verweildauer,
      Kontextmenü (auch Erledigt), Erfassung (drei Zustände, Return/Escape/Fokusverlust,
      kein Entwurf über das Schließen hinaus, Fehlerzeile inline, kein ⌘Z) ergänzen; unter
      „Anzeigen in" der Kurzbefehl (Wirkung, Geltung, Konfliktfall). Datum.
- [ ] `README.md`: den Menüleisten-Satz um Erfassung und Kurzbefehl erweitern.
- [ ] `CLAUDE.md`, Code-Landkarte: `TrayShortcut` (reine Regel), `GlobalHotkey`,
      `BacklogCaptureRow` in der Zeile zu `MenuBarTrayView`; `createTicket(title:)` beim
      Store.
- [ ] `RELEASE.md`, Phase 1: „Neue Aufgabe", „Kurzbefehl", „Von einer anderen App belegt"
      in die Längenprüfung. Phase 2: prüfen, ob `RegisterEventHotKey` in den Review-Notizen
      erwähnt werden muss (kein Entitlement nötig — nur festhalten, dass es keins braucht).
- [ ] `BACKLOG.md`: Eintrag „Ergänzungen, entschieden am 12.09.2026" als umgesetzt
      markieren; Tabelle „Was wohin gehört" um `trayShortcut` ergänzen; falls M1/M2
      negativ: den Befund dort festhalten.
- [ ] `scripts/check-localization.py`: neue Zähl-Schlüssel gibt es nicht (`%lld days` ist
      vorhanden und hat Plural) — prüfen, nicht annehmen.
- [ ] Diesen Plan und `plans/menubar-tablett.md` mit dem Merge löschen.

## Abnahme (Definition of Done)

1. Build grün, Tests grün, `check-localization.py` sauber.
2. Die vier Läufe aus Schritt 2–5 haben etwas hinterlassen (Erinnerung, plist, Bild).
3. Fensterbild hell und dunkel: Symbole, Flucht der Titel, Flucht der Zahlen; ein Bild
   mit offener Erfassung, eins mit Verweildauer.
4. M3 nachgeholt (Hover/Ablegen gesehen).
5. Doku-Pflichten erledigt; Doku-Wächter still.

## Messprotokoll

| Datum | Messung | Ergebnis | Folge |
|---|---|---|---|
| | M1 Textfeld im nicht aktivierenden Panel | | |
| | M2 `RegisterEventHotKey` (regular / accessory / Konflikt) | | |
| | M3 Hover- und Ablegeglas | | |
| | `SettingsMetrics.generalHeight` mit Kurzbefehl-Zeile | | |
