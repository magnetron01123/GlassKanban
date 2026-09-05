# Glass Kanban in der Menüleiste („Das Tablett") — Bauplan (05.09.2026)

Entschieden am 05.09.2026 (BACKLOG.md, „Fensterverhalten"). Mockups zum Nachsehen:
<https://claude.ai/code/artifact/a3b2efd4-9603-418f-9227-0b14031fc8e4> (Seite „Entwurf";
Artboards „A · Das Tablett", „Einstellungen · Allgemein", „Auswahl ‚Anzeigen in'").

Dieser Plan ist für eine eigene Session geschrieben. Er enthält alles, was zum Bauen
nötig ist; die Begründungen stehen im BACKLOG-Eintrag und werden hier **nicht** neu
verhandelt. Kästchen abhaken, Messungen unten protokollieren. Der Plan wurde am
05.09.2026 gegen den Code reviewt; die Befunde stehen am Ende und sind eingearbeitet.

## Zuerst lesen (in dieser Reihenfolge)

1. `CLAUDE.md` — ganz. Vor allem: die drei Prinzipien, „Arbeitsweise" (Drag & Drop ist
   nicht synthetisch auslösbar; `git log --all` vor UI-Änderungen; Build außerhalb
   `~/Documents`; ein Feature ist fertig, wenn ein Lauf etwas hinterlassen hat).
2. `BACKLOG.md`, Abschnitt „Fensterverhalten" → der Eintrag „Glass Kanban in der
   Menüleiste" bis einschließlich „Spannung, bewusst offen". Das ist das Konzept.
3. `CONCEPT.md`, „Design-Anspruch" (Glas ist Chrome; Immer-aktiv; Pull-Signal) und „Ton
   der Texte" (vor jedem neuen String).
4. `SPEC.md`, „Leere Spalte: der angedeutete Platz" und „WIP-Limits".
5. Code, in dieser Reihenfolge: `GlassKanban/GlassKanbanApp.swift`, `ContentView.swift`
   (Zugriffszustände, `store.start()` im `.task`), `SettingsView.swift`,
   `AppAppearance.swift`, `StoredSetting.swift`, `DesignSystem.swift`,
   `HUDGlassMaterial.swift`; in `ColumnView.swift` `.dropDestination` (≈ Zeile 304)
   und `emptySlot` (≈ Zeile 530); in `CardView.swift` `compactBody`; in
   `RemindersStore.swift` `cards(for:)` (≈ Zeile 1939), `move(...)` (≈ Zeile 1022),
   `PendingOverflow` (≈ Zeile 78) und die Stelle, die es setzt (≈ Zeile 1192); in
   `BoardView.swift` den WIP-Alert (≈ Zeile 115–135); in `Models.swift` `DoneWindow`.

## Ziel

Ein Klick auf ein Symbol in der Menüleiste öffnet ein Popover mit **drei Spuren in einer
Reihe, in Board-Reihenfolge**: „Als Nächstes" · „In Bearbeitung" · „Erledigt". Karten
sind Kompaktzeilen (38 pt) und wandern **von links nach rechts** — derselbe `move()`-Pfad
wie auf dem Board, dieselbe WIP-Frage, derselbe Klang. (Eine frühere Fassung legte
Erledigt als Ablage *unter* die Arbeitsspuren; damit lief der letzte Zug nach unten
statt nach rechts, und genau die Richtung ist Kanban. Zurückgenommen am 05.09.2026.)
In den Einstellungen wählt der Nutzer, ob die App im Dock, in der Menüleiste oder in
beidem erscheint.

## Nicht-Ziel

Kein Bearbeiten, kein Anlegen, kein Suchen, keine Filter, keine Streak-Pille, keine
Statistik im Popover. Kein Backlog im Popover (nur die Zahl in der Fußzeile). Keine Zahl
und kein Badge am Menüleisten-Symbol. Keine Notizen/vollen Karten im Popover.
**Erledigte Karten lassen sich im Popover nicht bewegen** — weder ziehen noch per
Kontextmenü; der Rückweg gehört dem Board (Befund R3). **Kein ⌘Z im Popover** (Befund
R8). Kein Widget — das ist ein anderer Eintrag.

## Leitsatz: so nah am Board wie möglich

Wo Board und Tablett dasselbe zeigen, zeigen sie es **gleich** — dieselben Tokens,
dieselben Schlüssel, dieselben Regeln, im Zweifel den Board-Code abschreiben.
Abweichungen gibt es nur aus Platz oder Technik, und jede steht in dieser Tabelle. Wer
beim Bauen eine weitere braucht, trägt sie hier ein, statt sie still zu machen.

| Element | Board | Tablett | Warum anders |
|---|---|---|---|
| Spurkopf, Zähl-Chip, teal bei Überschreitung | `ColumnView.header` | **gleich** | — |
| Leere Spur: Umriss + Satz | alle vier Spuren | **gleich** für die drei gezeigten | — |
| Erledigt-Fenster | 7 Tage, „Show N more" holt 30 | 7 Tage, **ohne** „mehr"-Knopf, Zeilen gedeckelt | kein Knopf im Popover, der Chip zählt alles |
| Karte in den Arbeitsspuren | volle Karte (152 pt) | **Kompaktzeile** (38 pt) wie Backlog | Platz; Inhalt gehört dem Board |
| Zug | Drag, Kontextmenü „Move to", VoiceOver-Aktionen | **gleich** (D3) | — |
| Karte, die jenseits `rowCap` landet | immer sichtbar (SPEC) | nicht sichtbar, der Chip zählt hoch | Platz; kein Scrollen unter einem Drag |
| Zug aus Erledigt heraus | erlaubt, mit „Not Restored"-Alert | **nicht** | der Alert gehört dem Board (R3) |
| WIP-Frage | Alert | **Zeile in der Mulde**, hält das Tablett | Alert schließt das Popover (R2) |
| Filter/Suche | gilt | **gilt nicht** | kein Chrome, das es erklären könnte (R6) |
| ⌘Z | ja | **nein** | kein Fokus im Popover (R8) |
| Spurhöhe | volle Fensterhöhe | alle drei Mulden **gleich hoch** | Popover hat keine Fensterhöhe; atmende Mulden sind verworfen |
| Spurbreite | vier gleich breite, ≥ 280 pt | drei gleich breite, ~200 pt | Platz; schmalere Ablage-Spalten sind verworfen, also alle gleich |
| Richtung | links → rechts | **links → rechts** | — |
| Backlog | Spur | **Zahl** in der Fußzeile | Platz; Planung gehört dem Board |

## Regeln, die beim Bauen gelten

- **Alle Werte aus `DesignSystem.swift`** (`Board.*`, `BoardText.*`). Neue Werte
  gehören dorthin, nicht in die View.
- **Kein zweiter Schreibpfad.** Jeder Zug im Popover ruft `store.move(...)`. Die
  WIP-Frage stellt der Store (`pendingOverflow`); das Popover zeigt sie nur an.
- **Entscheidungen aus der View herausziehen und testen** (CLAUDE.md-Muster): Was das
  Tablett zeigt, entscheidet `MenuBarTray.swift` (reine Logik, im Testziel), nicht die
  View.
- **Strings:** Englisch im Code, Deutsch in `Localizable.xcstrings`; nach jeder
  Katalogänderung `python3 scripts/check-localization.py`. Das Skript scannt auch
  `Text("…")`-Literale — jeder sichtbare Text braucht einen Schlüssel. Keine
  interpolierten `String(localized:)` in Dateien, die ins Testziel kompiliert werden.
- **Ton:** benennen, nicht kommentieren. Kein Punkt hinter Zahlenzeilen.
- **Ein Branch:** `feature/menubar-tray`, von `main`. Nicht liegen lassen.
- **Nach jedem Schritt bauen** (Befehle unten), nach Schritt 1, 2 und 4 testen.

## Befehle

```bash
xcodegen generate
```

```bash
xcodebuild -project GlassKanban.xcodeproj -scheme GlassKanban -derivedDataPath ~/Library/Caches/GlassKanban/DerivedData build 2>&1 | tail -20
```

```bash
xcodebuild -project GlassKanban.xcodeproj -scheme GlassKanban -derivedDataPath ~/Library/Caches/GlassKanban/DerivedData test 2>&1 | grep -E "Test Suite|passed|failed|error:" | tail -20
```

```bash
python3 scripts/check-localization.py
```

```bash
scripts/build-app.sh --manual
```

Der letzte Befehl legt `Glass Kanban.app` frisch in den Projektordner; die App danach
per Doppelklick starten (vorher alte Instanzen beenden: `pkill -x "Glass Kanban"`).
Nachweise in `UserDefaults` **direkt aus der plist** lesen (CLAUDE.md, `defaults read`
zeigt sie wegen cfprefsd nicht):

```bash
plutil -p ~/Library/Containers/com.davidtrogemann.GlassKanban/Data/Library/Preferences/com.davidtrogemann.GlassKanban.plist
```

---

## Schritt 0 — Messen, bevor Code entsteht

Drei Fragen, die der Plan nicht beantworten kann. Mit einem **Wegwerf-Aufbau** in
`GlassKanbanApp.swift` messen, den Befund unten protokollieren, den Aufbau danach
wieder entfernen (kein Commit davon).

### M1 — Lebt ein Drag in einem `MenuBarExtra`-Popover, und schließt es sich, wenn ein anderes Fenster den Fokus nimmt?

- [ ] In `GlassKanbanApp.body` **temporär** eine zweite Szene ergänzen:

```swift
MenuBarExtra("Probe", systemImage: "rectangle.split.3x1") {
    ProbeView()
}
.menuBarExtraStyle(.window)
```

```swift
struct ProbeView: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                Text("Karte").padding().background(.white).draggable("probe")
                Rectangle().fill(.gray.opacity(0.2)).frame(width: 120, height: 60)
                    .dropDestination(for: String.self) { ids, _ in
                        UserDefaults.standard.set(Date(), forKey: "probeDrop")
                        return true
                    }
            }
            Button("Board") {
                openWindow(id: "board")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .padding(20)
    }
}
```

- [ ] App bauen, starten, das Symbol in der Menüleiste anklicken, die Karte mit der
      **echten Maus** auf das Rechteck ziehen. Nur der Nutzer kann das tun (CLAUDE.md:
      synthetische Drags werden nicht angenommen) — ihn bitten und das Ergebnis abfragen.
      Nachweis: `probeDrop` in der plist (Befehl oben).
- [ ] Beobachten: Schließt sich das Popover beim Beginn des Zugs? Beim Loslassen?
- [ ] Board-Fenster schließen, Popover öffnen, „Board" klicken: Kommt das Fenster, und
      **schließt sich das Popover dabei von selbst**? (Es gibt keine API, ein
      `.window`-Popover programmatisch zu schließen — der Fokuswechsel muss es tun.)

**Weiche:**
- *Drop kommt an, Popover bleibt beim Zug offen und schließt beim Fokuswechsel* → weiter
  wie beschrieben (`MenuBarExtra`, Stil `.window`).
- *Popover schließt beim Zug oder Drop kommt nicht an* → Rückfall: In Schritt 3 statt
  `MenuBarExtra` ein `NSStatusItem` mit eigenem `NSPanel` (Stil
  `[.nonactivatingPanel, .titled, .fullSizeContentView]`, `isFloatingPanel = true`,
  `level = .popUpMenu`, `hidesOnDeactivate = false`, Inhalt per `NSHostingView`,
  Position unter dem Statusitem aus `statusItem.button!.window!.frame`; schließen bei
  Klick außerhalb über `NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown)`
  und explizit nach „Open Board"). Das Panel bekommt `HUDGlassMaterial` als
  Hintergrund. Der Rest des Plans bleibt gleich.
- *Popover schließt nach „Board" nicht* → vor `openWindow` den Popover-Schlüssel
  schließen: `NSApp.keyWindow?.close()` (das Popover ist in dem Moment das Key-Window).
  Im Protokoll festhalten.

### M2 — Verschwindet das Dock-Symbol zur Laufzeit sauber?

- [ ] Temporär in `AppearanceDelegate.applicationDidFinishLaunching` nach 5 Sekunden
      `NSApp.setActivationPolicy(.accessory)` aufrufen (`DispatchQueue.main.asyncAfter`),
      nach weiteren 5 Sekunden `.regular`.
- [ ] Beobachten: Verschwindet das Dock-Symbol? Bleibt das Board-Fenster offen und
      bedienbar, oder rutscht es hinter andere Fenster? Kommt das Symbol zurück?
- [ ] Während `.accessory` das Board anklicken: **Erscheint die Menüleiste der App**
      (Menü „Glass Kanban" → „Einstellungen …")? Ohne sie wäre im Modus „Menüleiste"
      kein Weg zurück zu den Einstellungen.

**Weiche:**
- *Sauber* → die Einstellung wirkt sofort (Schritt 1, `apply()` im `didSet`).
- *Fenster verschwindet oder Symbol bleibt* → `apply()` nur beim Start anwenden
  (`applicationWillFinishLaunching`), das `didSet` speichert nur, und die Fußzeile in
  den Einstellungen bekommt den Zusatz „Takes effect after the next launch." (de:
  „Wirkt nach dem nächsten Start.").
- *Keine App-Menüleiste im Accessory-Modus* → die Fußzeile des Tabletts bekommt im
  Modus „Menüleiste" zusätzlich `Settings…` (de: „Einstellungen …"), das
  `SettingsLink` öffnet — nur dort, nur dann.

### M3 — Bleibt das Board beim Start im Menüleisten-Modus zu?

SwiftUI öffnet die `Window`-Szene beim Start von selbst. Im Modus „Menüleiste" (vor
allem mit „Bei der Anmeldung starten") soll kein Board aufspringen.

- [ ] Temporär auf die `Window`-Szene `.defaultLaunchBehavior(.suppressed)` setzen, App
      beenden und neu starten: Bleibt das Fenster zu? Kommt es über „Board" (M1) und
      über einen Dock-Klick (bei `.regular`)?

**Weiche:**
- *Funktioniert* → Schritt 3 setzt den Modifier abhängig von `presence.selection`.
- *Fenster kommt trotzdem* → im App-Delegate `applicationDidFinishLaunching` bei
  `.menuBar` alle Fenster mit `identifier == "board"` schließen, und im Protokoll
  festhalten.

---

## Schritt 1 — Die Einstellung als Typ

**Neue Datei `GlassKanban/AppPresence.swift`** nach dem Muster von `AppAppearance.swift`:

```swift
import SwiftUI
import AppKit

/// Where the app shows itself: Dock, menu bar, or both.
enum AppPresence: String, CaseIterable, Identifiable {
    case dock
    case menuBar
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dock: String(localized: "Dock")
        case .menuBar: String(localized: "Menu Bar")
        case .both: String(localized: "Dock and Menu Bar")
        }
    }

    var showsDockIcon: Bool { self != .menuBar }
    var showsMenuBarItem: Bool { self != .dock }

    /// Whether the board window may open on its own at launch. In the menu
    /// bar mode the tray is the app; the board comes when asked for.
    var opensBoardAtLaunch: Bool { self != .menuBar }

    var activationPolicy: NSApplication.ActivationPolicy {
        showsDockIcon ? .regular : .accessory
    }

    /// The user dragged the item out of the menu bar (⌘-drag). Without a
    /// Dock icon the app would be unreachable, so this always lands on Dock.
    var afterMenuBarItemRemoved: AppPresence { .dock }

    func apply() {
        NSApplication.shared.setActivationPolicy(activationPolicy)
    }

    static let storageKey = StoredSetting.presence.key

    /// Default is the behaviour every existing user already has.
    static var stored: AppPresence {
        UserDefaults.standard.string(forKey: storageKey)
            .flatMap(AppPresence.init(rawValue:)) ?? .dock
    }
}

final class PresenceController: ObservableObject {
    static let shared = PresenceController()

    @Published var selection: AppPresence {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: AppPresence.storageKey)
            selection.apply()   // nach Weiche M2 ggf. nur beim Start
        }
    }

    private init() { selection = AppPresence.stored }

    func applyStored() { selection.apply() }
}
```

- [ ] Datei anlegen.
- [ ] `StoredSetting.swift`: Fall `case presence = "appPresence"` ergänzen, im `switch`
      unter `.thisDevice` einordnen (Kommentar: wo die App sichtbar ist, gehört dem
      Rechner, wie das Erscheinungsbild).
- [ ] `project.yml`: `GlassKanban/AppPresence.swift` in die `sources` des Targets
      `GlassKanbanTests` aufnehmen. Danach `xcodegen generate`.
- [ ] `AppearanceDelegate.applicationWillFinishLaunching`: nach dem `applyStored()` der
      Appearance `PresenceController.shared.applyStored()` aufrufen.
- [ ] Tests:
  - `GlassKanbanTests/StoredSettingTests.swift`: in
    `testKeysArePinnedToWhatIsAlreadyStored` die Zeile
    `XCTAssertEqual(StoredSetting.presence.key, "appPresence")`; in
    `testWhatBelongsToTheMachineStaysOnIt` `.presence == .thisDevice`.
    `testExactlyTheExpectedSettingsTravel` bleibt unverändert grün (die Menge der
    reisenden Werte ändert sich nicht) — laufen lassen, nicht annehmen.
  - Neue Datei `GlassKanbanTests/AppPresenceTests.swift`: Rohwerte gepinnt (`dock`,
    `menuBar`, `both` — persistierter Vertrag), Vorgabe ohne gespeicherten Wert ist
    `.dock`, `showsDockIcon`/`showsMenuBarItem`/`opensBoardAtLaunch`/`activationPolicy`
    je Fall, `afterMenuBarItemRemoved == .dock` für alle drei.
- [ ] Bauen und testen.

## Schritt 2 — Die Einstellung in der Oberfläche

**`SettingsView.swift`, `GeneralSettingsView`:** zwischen den drei Einzelzeilen
(Appearance, Login, Sound) und der Section „Backlog" eine neue Section:

```swift
Section {
    Picker("Show In", selection: $presence.selection) {
        ForEach(AppPresence.allCases) { option in
            Text(option.displayName).tag(option)
        }
    }
} header: {
    Text("Menu Bar")
} footer: {
    Text("The menu bar holds the two working lanes. Without a Dock icon the app keeps running while the board is closed.")
}
```

mit `@ObservedObject private var presence = PresenceController.shared` neben der
Appearance. Kein `onChange` — der Controller wendet selbst an.

- [ ] Section einbauen.
- [ ] `SettingsMetrics.generalHeight` erhöhen — gemessen: Fenster öffnen, prüfen, dass
      die letzte Fußzeile vollständig sichtbar ist (Erwartung ≈ +90).
- [ ] Katalog: Schlüssel `Show In`, `Menu Bar`, `Dock`, `Dock and Menu Bar`, der
      Fußzeilentext; Deutsch: „Anzeigen in", „Menüleiste", „Dock", „Dock und
      Menüleiste", „In der Menüleiste liegen die beiden Arbeitsspuren. Ohne Dock-Symbol
      läuft die App weiter, wenn das Board geschlossen ist." Format wie die vorhandenen
      Einträge (`extractionState: manual`, beide Sprachen `translated`).
- [ ] `python3 scripts/check-localization.py` → sauber.
- [ ] Bauen, App starten, Einstellungen öffnen, umschalten, App beenden, neu starten:
      Die Wahl steht. Nachweis: `appPresence` in der plist.

## Schritt 3 — Symbol, Szene und Startverhalten

**`GlassKanbanApp.swift`:**

```swift
@ObservedObject private var presence = PresenceController.shared

var body: some Scene {
    Window("Glass Kanban", id: "board") { … }
        .defaultSize(width: 1280, height: 760)
        // Menu bar mode: the board waits to be asked for (measured M3).
        .defaultLaunchBehavior(presence.selection.opensBoardAtLaunch ? .automatic : .suppressed)
        .commands { … }

    MenuBarExtra(
        "Glass Kanban",
        systemImage: "rectangle.split.3x1",
        isInserted: Binding(
            get: { presence.selection.showsMenuBarItem },
            // The user dragged the item out of the menu bar. Never leave the
            // app without any presence at all.
            set: { inserted in
                if !inserted { presence.selection = presence.selection.afterMenuBarItemRemoved }
            })
    ) {
        MenuBarTrayView()
            .environmentObject(store)
    }
    .menuBarExtraStyle(.window)

    Settings { … }
}
```

(Falls Weiche M1 → Rückfall: statt der `MenuBarExtra`-Szene ein `MenuBarTrayController`
mit `NSStatusItem`/`NSPanel`, gestartet aus dem App-Delegate und an
`PresenceController.selection` gekoppelt; `MenuBarTrayView` bleibt dieselbe.)

- [ ] Szene und Launch-Verhalten ergänzen. Symbol: `rectangle.split.3x1` ist der
      SF-Symbol-Platzhalter; ein eigenes Template-Glyph (drei Spuren, zwei mit Karten —
      siehe Mockup) kommt als Asset, sobald das Popover steht. Keine Zahl, kein Badge —
      nie.
- [ ] Bauen, prüfen: Symbol erscheint bei „Menüleiste" und „Dock und Menüleiste", nicht
      bei „Dock"; Umschalten in den Einstellungen wirkt (gemäß M2); Symbol per ⌘-Ziehen
      entfernen → Einstellung springt auf „Dock", Dock-Symbol ist da.

## Schritt 4a — Die Regeln des Tabletts (reine Logik, testbar)

**Neue Datei `GlassKanban/MenuBarTray.swift`** — ins Testziel (`project.yml`). Keine
Views, kein EventKit, keine interpolierten Strings.

```swift
import Foundation

/// What the menu bar tray shows. Decisions only; the view draws them.
enum MenuBarTray {
    /// Rows a lane shows at most. The count chip always tells the whole truth.
    static let rowCap = 6

    /// The pull slot appears where the board's does: "In Progress" is empty
    /// and there is something upstream to pull (SPEC.md, "Leere Spalte").
    static func showsPullSlot(inProgress: [KanbanCard], next: [KanbanCard]) -> Bool {
        inProgress.isEmpty && !next.isEmpty
    }

    /// Whether the footer offers Quit: only when there is no Dock to quit from.
    static func offersQuit(_ presence: AppPresence) -> Bool { !presence.showsDockIcon }

    /// Both working lanes share one height: the fuller lane's rows, never
    /// fewer than three, never more than the cap. Lanes that each hug their
    /// content were rejected for the board; the tray keeps the same posture.
    static func laneRows(next: Int, inProgress: Int, done: Int) -> Int {
        min(rowCap, max(3, next, inProgress, done))
    }

    /// While the tray's own WIP question stands, nothing else moves — a second
    /// drag would overwrite the first question unanswered.
    static func allowsMoves(pendingSource: RemindersStore.MoveSource?) -> Bool {
        pendingSource != .tray
    }
}
```

- [ ] Datei anlegen, in `project.yml` beim Testziel eintragen, `xcodegen generate`.
- [ ] `GlassKanbanTests/MenuBarTrayTests.swift`: Pull-Slot nur bei leerem „In
      Bearbeitung" **und** nicht-leerem „Als Nächstes"; `offersQuit` nur bei `.menuBar`;
      `laneRows` liefert 3 für (0,0,0), 5 für (5,1,2), `rowCap` für (20,0,0);
      `allowsMoves` ist false nur bei `.tray`; `rowCap` gepinnt. Karten-Fixtures
      wie in `DoneWindowTests.swift` bauen. `MoveSource` muss dafür im Testziel
      sichtbar sein — liegt es in `RemindersStore.swift` (nicht im Testziel), es als
      eigene kleine Datei `MoveSource.swift` anlegen und ins Testziel nehmen.
- [ ] Testen.

## Schritt 4b — Ungefilterte Spuren und die Herkunft eines Zugs (Store)

Zwei kleine Änderungen in `RemindersStore.swift`, beide ohne Verhaltensänderung für
das Board:

1. **`cards(for:)` bekommt einen Schalter für die Filter.** Das Tablett hat kein Chrome,
   das eine aktive Suche oder einen Filter erklären könnte — dort würden Karten grundlos
   fehlen. Es zeigt deshalb die Spur ungefiltert, in derselben Sortierung:

```swift
func cards(for status: KanbanStatus, applyingFilters: Bool = true) -> [KanbanCard] {
    let filtered = cards.filter {
        $0.status == status && (!applyingFilters || (
            priorityFilter.matches($0.priority)
                && dueFilter.matches($0.dueDate)
                && listFilter.matches($0.listID)
                && $0.matches(search: searchTerm)))
    }
    // Sortierung unverändert …
}
```

2. **`PendingOverflow` trägt, wo der Zug herkam.** Board und Tablett beobachten
   denselben Store; ohne Herkunft stellte das Board die Frage auch für einen Zug im
   Tablett (oder beide gleichzeitig). Und ein `.alert` im Popover ist keine Option: Der
   Alert nimmt den Fokus, das Popover schließt, die Frage verwaist. Das Tablett stellt
   sie deshalb **inline** (Schritt 4c), und jeder zeigt nur seine eigene:

```swift
enum MoveSource { case board, tray }

struct PendingOverflow: Identifiable {
    let cardID: String
    let origin: KanbanStatus
    let status: KanbanStatus
    let source: MoveSource
    var id: String { cardID }
}

func move(cardID: String, to status: KanbanStatus, undoManager: UndoManager? = nil,
          feedback: Bool = true, restoredCompletion: Date? = nil,
          source: MoveSource = .board) -> KanbanStatus?
// … pendingOverflow = PendingOverflow(cardID:origin:status:source: source)
```

   In `BoardView` präsentiert `overflowBinding` nur noch, wenn
   `store.pendingOverflow?.source == .board`.

- [ ] Beide Änderungen; vorher `git log --all -- GlassKanban/RemindersStore.swift
      GlassKanban/BoardView.swift` überfliegen (Feature-History, CLAUDE.md).
- [ ] `WIPLimitTests.swift` konstruiert `PendingOverflow` nicht (geprüft 05.09.2026);
      trotzdem die ganze Suite laufen lassen. Tests grün.

## Schritt 4c — Das Tablett (View)

**Neue Datei `GlassKanban/MenuBarTrayView.swift`.** Aufbau (siehe Mockup):

```
MenuBarTrayView                            ← .task { await store.start() }  (R1)
├─ switch store.accessState
│  ├─ .granted   → Tray
│  ├─ .denied    → eine Zeile (Schlüssel aus AccessDeniedView übernehmen) + „Open Board"
│  └─ sonst      → ProgressView("Accessing Reminders…")  (Schlüssel existiert)
└─ Tray = VStack(spacing: 12), Padding 16, Breite Board.trayWidth
   ├─ HStack(spacing: 12)         ← drei gleich breite, gleich hohe Mulden
   │  ├─ TrayLane(.next)          ← Mulde: columnShape, columnFill, columnBorder,
   │  ├─ TrayLane(.inProgress)       columnInnerShadow; Karten beweglich (3 Routen)
   │  └─ TrayLane(.done)          ← 7-Tage-Fenster, neueste zuerst; Karten NICHT beweglich
   └─ Fußzeile (BoardText.meta, secondary):
        „Backlog · %lld"      |      „Open Board"   [„Quit Glass Kanban" bei offersQuit]
```

Jede `TrayLane(status)`:

- Daten: `store.cards(for: status, applyingFilters: false)`; bei `.done` durch
  `DoneWindow.recent` (dasselbe 7-Tage-Fenster wie die Board-Spalte, neueste zuerst).
  Gezeigt werden höchstens `MenuBarTray.rowCap` Zeilen; der Zähl-Chip zeigt **immer**
  die volle Zahl. Kein „Show N more"-Knopf, kein Scrollen (ein Scrollbereich unter
  einem Drag ist Ärger ohne Nutzen).
- Kopf **wörtlich wie `ColumnView.header`** (≈ Zeile 383): `status.displayName` in
  `BoardText.header`/`.secondary`, rechts **ein** Zähl-Chip (`Board.chipShape`,
  `BoardText.chip`, `.quaternary`-Füllung), der bei `store.isOverWIPLimit(status)`
  teal wird (`Board.wipLimitTint.opacity(Board.wipCapsuleFill)`, Text `.primary`).
  **Keinen zweiten „Limit N"-Chip** — den zeigte das erste Mockup, das Board hat ihn
  nicht; ein Kopf sagt eine Zahl. **Kein „done today"** — das Board hat genau diesen Zusatz
  abgelegt (Kommentar dort: das eine Stück Dauer-Chrome je Spur sagte zwei Dinge). Der
  Chip zählt **alles in der Spur** (bei Erledigt: das 7-Tage-Fenster), auch wenn
  weniger Zeilen gezeigt werden — und steht auch bei 0, wie auf dem Board (Leitsatz).
  Darunter die Haarlinie. **Der Tooltip des Board-Kopfs kommt mit** —
  `.boardTooltip(countHelp)` auf dem ganzen Kopfband wie in `ColumnView` (≈ Zeile
  433): Ein Spaltenkopf ist Chrome, Chrome-Tooltips erklären Regeln, und „make
  policies explicit" gilt auch hier. Auf Karten weiterhin keine.
- Karten: **`TrayCardView`** (eigene, kleine View in derselben Datei). Anatomie
  **wörtlich nach SPEC „Karten-Anzeige"** und dem Board-Code:
  - `.next`/`.inProgress`: die Backlog-Zeile — `CardView.compactBody` (≈ Zeile 311)
    abschreiben: Prioritätsmarken + Titel (`titleOrField`-Inhalt, `BoardText.titleCompact`,
    `lineLimit(1)`), dann Fälligkeits-Badge (`badgeView`/`compactBadge`, drei Stufen),
    dann Wiederholungs-Icon (`repeatIcon`) — in genau dieser Reihenfolge, Insets
    `cardInsetLeading`/`cardInsetTrailing`, Höhe `compactCardHeight` fest.
  - `.done`: `CardView.minimalBody` (≈ Zeile 336) — nur der Titel, **in primärer
    Textfarbe** (SPEC: „Erledigt-Titel in voller Textfarbe, nicht gedämpft — der
    Durchstrich ist das Signal"), Strich als statische `strikeLine` in voller Breite,
    ohne den Zeichen-Sweep (der ist die Board-Belohnung und bleibt dort);
    `cardFill(isDone: true)`.
  - Gemeinsam: `Board.cardShape`, `cardFill`, `cardBorder(contrast)`, Listenstreifen
    `Board.cardStripeWidth` (`stripeColor`-Regel aus `CardView` ≈ Zeile 515), Schatten
    `cardShadowResting` + `cardShadowAmbient`, `cardTopHighlight`.
  **Bewusst nicht `CardView` selbst:** die trägt Umbenennen, Editor-Öffnen, Löschen im
  Kontextmenü, Tooltips und Settle-Animationen, die im Tablett alle nicht existieren
  sollen. Ihre Bausteine (`badgeView`, `repeatIcon`, `strikeLine`, Prioritätsmarken)
  sind privat — sie in eine gemeinsame Datei `CardParts.swift` heben, wenn das
  Abschreiben mehr als ~40 Zeilen wäre; nicht zweimal pflegen.
- **Kontrast erhöhen** (SPEC „App"): `@Environment(\.colorSchemeContrast)` lesen und
  `Board.columnBorder(contrast)` / `Board.cardBorder(contrast)` verwenden — sonst ist
  die Bedienungshilfe im Tablett wirkungslos.
- Zug — **drei Routen wie auf dem Board** (SPEC „WIP-Limits": die Frage stellt sich
  bei jeder Route; SPEC „Motivation": Maus, Kontextmenü und VoiceOver gleich
  behandelt), alle über `store.move(cardID:to:undoManager: nil, source: .tray)`,
  alle nur für Karten in `.next` und `.inProgress`:
  1. `.draggable(card.id)`; `.dropDestination(for: String.self)` auf allen drei
     Mulden, wörtlich wie `ColumnView` (≈ Zeile 304). `isTargeted` →
     `MoveFeedback.dragEnteredTarget()` nur beim Eintritt und nicht für die
     Quellmulde; währenddessen ein `insertionSlot` wie in `ColumnView`. Das Tablett
     ruft **nicht** `store.beginDrag` (kein Ghosting) — ein Zug, der ins Leere endet,
     hinterlässt so von selbst keinen halben Zustand (SPEC „Was das Board gegen sich
     selbst absichert"); `store.endDrag()` im Drop bleibt, wie im Board, unschädlich.
  2. `.contextMenu` mit `Menu("Move to")` über `moveTargets` — wie `CardView` ≈ Zeile
     96–110, ohne „Delete"/„Open in Reminders".
  3. `.accessibilityActions` „Move to …" — wie `CardView` ≈ Zeile 143–150.
  Bei `MenuBarTray.allowsMoves(pendingSource:) == false` (offene WIP-Frage) sind alle
  drei Routen aus.
- Leerer Platz: `MenuBarTray.showsPullSlot(...)` → `.inProgress` zeigt den gestrichelten
  Umriss mit `String(localized: "Finishing starts here")` (Schlüssel existiert),
  `BoardText.titleCompact`, `.secondary`, Höhe `compactCardHeight`, Strich wie
  `ColumnView.emptySlot`. `.next` leer zeigt — wie auf dem Board — den Umriss mit
  `Choose, don't collect` nur, wenn der Backlog nicht leer ist (SPEC „Wann er
  erscheint"); `.done` leer zeigt den Umriss mit `Only finished counts` (Schlüssel
  existiert). Dieselben Regeln, derselbe Code: `ColumnView.emptySlotText` und die
  Bedingung dazu nachlesen und übernehmen — nicht nachbauen.
- **Höhen:** Alle drei Mulden sind **immer gleich hoch** —
  `MenuBarTray.laneRows(next:inProgress:done:)` Zeilen, das Maximum der drei,
  mindestens 3, höchstens `rowCap`. Mulden, die je mit ihrem Inhalt atmen, wären genau
  das Bild, das für das Board verworfen wurde („Spalten enden mit dem Inhalt", BACKLOG
  „Explizit abgelehnt").
- **WIP-Frage inline** (kein Alert): Ist `store.pendingOverflow?.source == .tray`, zeigt
  die Mulde `.inProgress` **oberhalb** ihrer Karten eine Zeile in Kompakthöhe:
  links der Titel wie im Board-Alert (`overflowTitle` aus `BoardView` in eine Funktion
  auf dem Store ziehen: `overflowTitle(for:)`, damit der Text nur einmal existiert),
  rechts zwei Textknöpfe `Finish First` (führt `store.move(cardID:to: origin,
  undoManager: nil, feedback: false)` aus und setzt `pendingOverflow = nil`) und
  `That's Fine` (setzt nur `pendingOverflow = nil`). Beide Schlüssel existieren. Die
  Zeile ist Chrome, nicht Karte: `Board.wellFill`, `Board.wellShape`, `BoardText.meta`.
  Kein „Less at once, more done" — die Botschaft ist der Alert-Text des Boards, hier
  reicht die Zahlenzeile. Escape/Return gibt es im Popover nicht; die sichere Antwort
  steht links. **Die Frage hält das Tablett:** Solange sie steht, lässt sich keine
  Karte im Tablett bewegen — auf keiner der drei Routen
  (`MenuBarTray.allowsMoves(pendingSource:)`) —, damit kein zweiter Zug die erste
  Frage unbeantwortet überschreibt; das wäre stilles Zulassen. Schließt
  der Nutzer das Popover mit offener Frage, bleibt sie stehen und steht beim nächsten
  Öffnen wieder da; beantwortet wird nichts von selbst — weder still zugelassen noch
  still zurückgelegt („Karte springt zurück" ist das Muster, das dieses Projekt am
  teuersten bezahlt hat). Der Zustand selbst ist unterdessen nicht versteckt: Der
  Zähl-Chip der Mulde ist teal, im Tablett wie auf dem Board.
- Karten sind keine `Button`s (kein Fokusring, kein Tastaturfokus — BACKLOG „Explizit
  abgelehnt"), Fußzeilen-Knöpfe `.buttonStyle(.plain)`. Keine Tooltips auf Karten.
- Tap auf eine Karte (nur `.next`/`.inProgress`): erst `openWindow(id: "board")` und
  `NSApp.activate(ignoringOtherApps: true)`, **dann** `store.editingCardID = card.id`
  — nie umgekehrt: `editingCardID` wird nur von `BoardView.closeEditor` (≈ Zeile 247)
  zurückgesetzt, ein gesetzter Wert ohne Fenster bliebe stehen. Gemäß M1 vorher ggf.
  `NSApp.keyWindow?.close()`.
- „Open Board": dasselbe ohne `editingCardID`. „Quit Glass Kanban": `NSApp.terminate(nil)`.
- Hintergrund: zuerst mit dem Systemmaterial des `.window`-Stils bauen und **ansehen**.
  Liest es sich nicht wie das Fenster der App (Immer-aktiv-Regel, CONCEPT.md), als
  `.background` `HUDGlassMaterial()` setzen — und bei
  `accessibilityReduceTransparency` stattdessen `Color(nsColor: .windowBackgroundColor)`,
  wie `ContentView.windowBackground`.
- Bewegung: `.animation(reduceMotion ? nil : Board.cardMoveAnimation, value: store.cards)`
  auf der Wurzel, wie `BoardView`. Sonst keine Animation.
- Barrierefreiheit: `TrayCardView` bekommt `accessibilityLabel` und `accessibilityHint`
  nach dem Muster von `CardView` (≈ Zeile 133–136) — dieselben Schlüssel, keine neuen;
  die WIP-Zeile ist als Gruppe mit beiden Knöpfen erreichbar.

Neue Strings (en → de), alle in den Katalog: `Open Board` → „Board öffnen";
`Quit Glass Kanban` → „Glass Kanban beenden"; `Backlog · %lld` → „Backlog · %lld" —
in `PLURAL_EXEMPT` von `check-localization.py` eintragen mit Grund „Zahlenzeile ohne
gebeugtes Substantiv"; bei Weiche M2 zusätzlich `Takes effect after the next launch.`.
Bereits vorhanden und zu übernehmen: `Finishing starts here`, `Finish First`,
`That's Fine`, `Accessing Reminders…`, `Over your limit` (Accessibility-Wert des
teal Chips), `Choose, don't collect`, `Only finished counts`, `Move to`,
`Move to %@` (VoiceOver-Aktion — Schlüssel in `CardView` nachsehen), die Zeilen aus
`AccessDeniedView`. **Nicht** verwenden: `%lld done today` (siehe Kopf).
**Deutsche Längen prüfen** (RELEASE.md, Phase 1): „Glass Kanban beenden" und die
Kopfzeilen müssen in ~200 pt Mulde bzw. in der Fußzeile ohne Umbruch stehen.

- [ ] `Board.trayWidth = 660` in `DesignSystem.swift`, mit Begründung: Drei gleich
      breite Mulden à ~200 pt (660 − 2·16 Rand − 2·12 Abstand = 604 / 3) tragen bei
      15 pt rund 22 Zeichen Titel plus Datums-Chip — genug für einen Titel, der
      wiedererkannt statt gelesen wird. Drei statt zwei, weil der Zug nach Erledigt
      nach rechts laufen muss, nicht nach unten; gleich breit, weil schmalere
      Ablage-Spalten verworfen sind. Breiter läse sich das Popover als zweites Fenster.
- [ ] `MenuBarTrayView.swift` mit `TrayLane` und `TrayCardView` schreiben.
- [ ] `overflowTitle` in den Store ziehen, in `BoardView` verwenden.
- [ ] Katalog ergänzen, `PLURAL_EXEMPT` ergänzen, `check-localization.py` sauber.
- [ ] Bauen, Tests grün, `scripts/build-app.sh --manual`, App starten.
- [ ] **Selbst per Screenshot prüfen** (CLAUDE.md): Popover öffnen, mit dem Board
      daneben vergleichen — Kopfzeilen, Chips, Karten müssen dieselben sein. Hell und
      dunkel. „Transparenz reduzieren" und „Bewegung reduzieren" je einmal einschalten.

## Schritt 5 — Der Lauf, der etwas hinterlässt

Nur der Nutzer kann ziehen. Ihn um genau diese Abfolge bitten und die Nachweise
selbst lesen:

- [ ] Eine Karte im Tablett von „Als Nächstes" nach „In Bearbeitung" ziehen. Nachweis:
      `columns.json` (Pfad: `ColumnState.knownFileURLs`) trägt danach einen jüngeren
      Zeitstempel und die Karten-ID unter der Arbeitsspur; das offene Board-Fenster
      zeigt die Karte in der neuen Spalte, ohne Neuladen.
- [ ] Bei vollem Limit ziehen → die Frage erscheint **nur im Tablett**, nicht als
      Alert auf dem Board; der Chip der Mulde ist teal; solange die Frage steht, lässt
      sich keine Karte ziehen; Popover schließen und öffnen → Frage steht noch;
      „Finish First" legt die Karte zurück, ohne Klang; „That's Fine" lässt sie liegen.
- [ ] Erledigt-Ablage und Board-Spalte „Erledigt" nebeneinander: dieselben Karten oben,
      derselbe Chip.
- [ ] Mit Board-Filter (⌘F, ein Wort) → das Tablett zeigt weiterhin alle Karten der
      Spur.
- [ ] Rechtsklick auf eine Tablett-Karte → „Move to" mit den zwei anderen Zielen;
      derselbe Zug, dieselbe WIP-Frage. VoiceOver einschalten, Karte anspringen,
      Aktionen-Rotor: „Move to …" vorhanden.
- [ ] „Kontrast erhöhen" einschalten: Mulden- und Kartenkonturen im Tablett werden
      kräftiger wie auf dem Board.
- [ ] Eine Karte nach „Erledigt" ziehen → Klang (wenn eingeschaltet), Reminders zeigt
      sie erledigt, sie steht oben in der Erledigt-Ablage des Tabletts. Versuch, sie
      dort wieder herauszuziehen → nichts passiert.
- [ ] „Menüleiste" wählen, Board schließen: Die App läuft weiter, Popover öffnet und
      zeigt Karten (nicht leer — R1). App beenden und neu starten: **kein** Board
      springt auf (M3); „Open Board" bringt es; „Quit Glass Kanban" beendet.
- [ ] „Dock und Menüleiste": Board schließen, Dock-Symbol klicken → Board kommt zurück.
- [ ] „Dock" wählen: Symbol weg, alles wie vor diesem Vorhaben.

## Doku-Pflichten (im selben Branch, vor dem PR)

- [ ] `SPEC.md`: neuer Abschnitt „Menüleiste (Tablett)" unter „Interaktion" — was das
      Popover zeigt (zwei Arbeitsspuren, Erledigt heute, Fußzeile), was es nicht zeigt
      (Backlog, Filter, Editor), dass Erledigt-Karten dort nicht ziehbar sind, dass es
      kein ⌘Z gibt, die drei Werte der Einstellung und ihre Wirkung (inkl.
      Startverhalten und ⌘-Herausziehen), dass jeder Zug über `move()` läuft und die
      WIP-Frage inline steht. Datum.
- [ ] `README.md`: ein Satz zur Menüleiste bei den Funktionen.
- [ ] `RELEASE.md`, Phase 3: Screenshot-Liste um „Menüleiste (Tablett)" ergänzen;
      Phase 1: die neuen deutschen Strings in die Längenprüfung aufnehmen.
- [ ] `BACKLOG.md`, Tabelle „Was wohin gehört": Zeile `appPresence` ist bereits
      eingetragen (05.09.2026) — prüfen, dass sie zum Code passt.
- [ ] `BACKLOG.md`: den Eintrag in „Fensterverhalten" als **umgesetzt** markieren
      (durchgestrichener Titel wie bei den anderen), Konzept-Absätze stehen lassen.
      Den ersten Einzeiler „Menüleisten-Modus / Always-on-Top" auf Always-on-Top
      reduzieren.
- [ ] `CLAUDE.md`, Code-Landkarte: `AppPresence`, `MenuBarTray` (reine Regeln, im
      Testziel) und `MenuBarTrayView` eintragen; `MoveSource` bei `RemindersStore`
      erwähnen.
- [ ] Diese Datei löschen. `plans/README.md` bleibt.

## Abnahme (Definition of Done)

1. Build grün, Tests grün, `check-localization.py` sauber.
2. Schritt 5 vollständig, Nachweise gelesen (Datei, plist, Reminders).
3. Screenshot-Vergleich Tablett/Board ohne sichtbaren Bruch in Hell und Dunkel.
4. Doku-Pflichten erledigt; Doku-Wächter still.
5. PR gegen `main`, Beschreibung nennt die Messbefunde aus dem Protokoll.

## Messprotokoll

| Datum | Messung | Ergebnis | Folge |
|---|---|---|---|
| | M1 Drag im MenuBarExtra-Popover | | |
| | M1 Popover schließt bei „Board" | | |
| | M2 Activation Policy zur Laufzeit | | |
| | M3 `defaultLaunchBehavior(.suppressed)` | | |
| | Hintergrund: Systemmaterial vs. HUDGlassMaterial | | |
| | `SettingsMetrics.generalHeight` gemessen | | |

## Review-Befunde vom 05.09.2026 (eingearbeitet)

Gegen den Code geprüft, nicht gegen den Plantext. Jede Zeile nennt, was falsch war und
wo es im Plan gelandet ist.

- **R1 — Der Store startet nur im Board-Fenster.** `store.start()` (Zugriff anfragen,
  laden, beobachten) hängt an `ContentView.task`. Im Menüleisten-Modus ohne Fenster wäre
  das Tablett leer und hätte nie nach Zugriff gefragt. `start()` ist idempotent
  (`hasStarted`), also ruft das Tablett es ebenfalls. → Schritt 4c, erste Zeile.
- **R2 — `.alert` im Popover ist doppelt und verwaist.** Board und Tablett beobachten
  denselben `pendingOverflow`; das Board hätte die Frage auch für Tablett-Züge
  gestellt. Und ein Alert nimmt den Fokus — das `.window`-Popover schließt dann. →
  `MoveSource` im Store (4b), Frage inline in der Mulde (4c).
- **R3 — `pendingSaveFailure` („Not Restored") zeigt nur das Board.** Ein Zug aus
  Erledigt heraus kann bei Serien scheitern und würde im Tablett stumm verpuffen. →
  Erledigt-Karten im Tablett nicht ziehbar; Nicht-Ziel, SPEC.
- **R4 — SwiftUI öffnet das Board beim Start von selbst.** Mit „Bei der Anmeldung
  starten" und Modus „Menüleiste" spränge bei jedem Login ein Board auf. →
  `opensBoardAtLaunch`, `.defaultLaunchBehavior(.suppressed)`, Messung M3.
- **R5 — `isInserted` mit leerem Setter.** ⌘-Herausziehen des Symbols ruft
  `set(false)`; im Modus „Menüleiste" wäre die App danach ohne Dock und ohne Symbol
  unerreichbar. → `afterMenuBarItemRemoved == .dock`, Test dafür.
- **R6 — `cards(for:)` wendet Board-Filter und Suche an.** Das Tablett hat kein Chrome,
  das erklärt, warum Karten fehlen. → `applyingFilters:` (4b), Prüfung in Schritt 5.
- **R7 — „Show N more" wäre im Tablett ein totes Label.** Im Board ist es ein Knopf. →
  kein Knopf, Zeilen gedeckelt mit `rowCap`, der Chip zählt immer alles.
- **R8 — Undo.** Das Popover hat keinen Text-Fokus und kein ⌘Z; ein registrierter
  Undo-Eintrag wäre nur vom Board aus erreichbar und dort überraschend. →
  `undoManager: nil`, dokumentiert als „kein ⌘Z im Tablett".
- **R9 — Zugriffszustand fehlte.** `denied`/`requesting` müssen im Tablett etwas zeigen,
  sonst ist es beim ersten Start leer und stumm. → Schritt 4c, `switch accessState`.
- **R10 — Popover programmatisch schließen gibt es nicht.** „Open Board" verlässt sich
  auf den Fokuswechsel; das wird in M1 mitgemessen, mit `keyWindow?.close()` als
  Rückfall.
- **R11 — `Text("…")` wird vom Lokalisierungsskript gescannt.** `Backlog · N` ohne
  Schlüssel hätte Check 1 ausgelöst. → Schlüssel plus `PLURAL_EXEMPT`-Eintrag.
- **R12 — Regeln in der View wären untestbar.** → `MenuBarTray.swift` im Testziel, mit
  vier Tests (CLAUDE.md-Muster).
- **R13 — Volle Spuren.** Ein Limit von 20 gäbe 20 Zeilen, das Popover ragte über den
  Bildschirm. → `rowCap = 6`, kein Scrollen.
- **R14 — Transparenz reduzieren.** Ein `HUDGlassMaterial` ohne Rückfall verletzte
  dieselbe Regel wie das Fenster. → wie `ContentView.windowBackground`.
- **R15 — Dock-Klick bei geschlossenem Board** war nicht in der Abnahme. → Schritt 5.

Zweiter Durchgang, gegen Philosophie und Prinzipien (05.09.2026):

- **W1 — „%lld done today" im Kopf.** Das Board hat genau diesen Zusatz abgelegt
  (`ColumnView.header`: ein Stück Dauer-Chrome sagt eine Sache). → nur der Zähl-Chip,
  wie das Board — auch bei 0.
- **W2 — „Limit N"-Chip.** Existiert auf dem Board nicht; das Mockup hat ihn erfunden.
  → ein Chip, teal bei Überschreitung, wie das Board. Das Mockup ist hier nicht
  maßgeblich.
- **W3 — Leere Ablage.** Zuerst als „schweigt" geplant (ein eigenes Heute-Fenster hätte
  den Satz jeden Morgen stehen lassen). Mit dem Leitsatz „so nah am Board wie möglich"
  (Nutzer, 05.09.2026) zurückgenommen: Die Ablage nimmt das 7-Tage-Fenster des Boards
  und damit dessen Regel — leer zeigt sie `Only finished counts`, wie die Spalte.
- **W4 — Mulden, die mit dem Inhalt atmen.** Für das Board ausdrücklich verworfen. →
  gleiche Höhe für beide Arbeitsmulden, `laneRows`.
- **W5 — Zweiter Zug bei offener WIP-Frage** hätte die erste still überschrieben; ein
  Schließen des Popovers hätte still zugelassen oder still zurückgelegt. → die Frage
  hält das Tablett und bleibt stehen, bis sie beantwortet ist.
- **W6 — Einstellungen im Modus „Menüleiste"** hängen daran, ob eine Accessory-App
  ihre Menüleiste zeigt. → Messung in M2, `Settings…` als Rückfall.
- **W7 — Fokus und Tooltips** auf Karten sind abgelehnt. → keine `Button`s, keine
  Tooltips, `.plain`-Knöpfe in der Fußzeile.
- **W8 — Erledigt unter den Arbeitsspuren** (Nutzer, 05.09.2026): Der Zug nach
  Erledigt lief nach unten, das Board zieht nach rechts — die Richtung *ist* Kanban.
  → drei Spuren in einer Reihe, gleich breit, gleich hoch; `trayWidth` 660.

Dritter Durchgang, gegen SPEC/CONCEPT/RELEASE/README (05.09.2026):

- **D1 — Erledigt-Titel `.secondary`** widersprach SPEC „Karten-Anzeige" (voller
  Farbton, der Durchstrich ist das Signal). → primär, `minimalBody` abschreiben.
  Und die Kompaktzeile hatte nur Titel + Badge; SPEC nennt Prioritätsmarken und
  Wiederholungs-Icon. → `compactBody` vollständig.
- **D2 — „Kontrast erhöhen"** (SPEC „App") fehlte. → `colorSchemeContrast`.
- **D3 — Nur Drag** verletzte SPEC: „Die Frage stellt sich bei jeder Route", „Maus,
  Kontextmenü und VoiceOver gleich behandelt". Ein Tablett, in dem VoiceOver nichts
  bewegen kann, ist kein Tablett. → Kontextmenü und VoiceOver-Aktionen wie `CardView`.
- **D4 — Kopf-Tooltip** war ausgeschlossen; Chrome-Tooltips sind aber ausdrücklich
  erlaubt und tragen „make policies explicit". → übernommen.
- **D5 — `editingCardID` ohne Fenster** bliebe stehen. → Reihenfolge festgelegt.
- **D6 — Karte jenseits `rowCap`** verletzt „Eine gezogene Karte bleibt sichtbar, wo
  sie landet". Bewusst in Kauf genommen und in der Tabelle benannt: kein Scrollen
  unter einem Drag; der Chip zählt sichtbar hoch.
- **D7 — RELEASE.md** (Screenshots, deutsche Längen) und die Tabelle „Was wohin gehört"
  fehlten in den Doku-Pflichten. → ergänzt.
- **Geprüft, bleibt:** „Backlog · N" in der Fußzeile — eine Zahl für eine Spur, die
  nicht gezeigt wird, ist die kleinste Form von „Arbeit sichtbar machen"; sie zählt,
  klagt nicht. Der Pull-Umriss in Board **und** Tablett ist dieselbe Einladung am
  selben Platz, zweimal gezeigt — nicht zwei Einladungen; die Regel zielt auf
  Mehrdeutigkeit, und die entsteht hier nicht. Tap auf eine Karte öffnet Board und
  Karte — dieselbe Geste wie auf dem Board.
