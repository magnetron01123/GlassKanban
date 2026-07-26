# Befunde aus dem Test vom 25./26. Juli 2026

Ergebnis aus Testsuite, Build, einem visuellen Review über 28 gerenderte Zustände
(beide Erscheinungsbilder, mit Pixelmessung) und vier Code-Reviews entlang der
Nutzerflüsse.

**Status hinter jedem Befund:**
- `gemessen` — selbst nachgewiesen (ausgeführter Code, gemessene Pixel-/Farbwerte)
- `gerendert` — im Bild sichtbar
- `gelesen` — im Code eindeutig belegt, aber nicht zur Laufzeit ausgelöst
- `offen` — plausibel, braucht einen Lauftest

Nicht enthalten sind Punkte, die BACKLOG.md unter „Explizit abgelehnt" führt.

**Nicht abgedeckt:** Drag & Drop und die WIP-Rückfrage — beide verändern echte
Erinnerungen und wurden ausgelassen. Alles andere wurde an der laufenden App bedient.

**Reihenfolge zum Abarbeiten:** A1 → A2 → C1, dann der Rest nach Schwere.
A1 steht vorn, weil es als einziger Befund Nutzertext ohne Zutun und ohne Undo zerstört.

---

## Übersicht

| # | Befund | Ort | Schwere | Nachweis |
|---|---|---|---|---|
| ~~V0~~ | ~~Escape schließt den Editor nicht~~ — **Fehlalarm**, siehe unten | — | — | widerlegt |
| ~~A1~~ | ~~Hashtag ohne linke Wortgrenze zerstört Nutzertext~~ — **behoben** | `StatusTagger:52` | ~~Kritisch~~ | erledigt |
| ~~A2~~ | ~~Editor schreibt gegen veralteten Stand~~ — **behoben** | `RemindersStore:833` | ~~Kritisch~~ | erledigt |
| ~~V0c~~ | ~~Platzhalter nicht von Inhalt zu unterscheiden~~ — **behoben** | `TicketEditSheet:396` | ~~Hoch~~ | erledigt |
| ~~A3~~ | ~~Undo nach Löschen verliert Unteraufgaben/Anhänge~~ — **Rückfrage eingebaut** | `BoardView:107` | ~~Hoch~~ | erledigt |
| ~~A4~~ | ~~Edit geht stumm verloren, wenn Karte aus dem Cache fällt~~ — **behoben** | `RemindersStore:846` | ~~Hoch~~ | erledigt |
| ~~B1~~ | ~~Zeitzone der Fälligkeit geht verloren~~ — **behoben** | `RemindersStore:897` | ~~Hoch~~ | erledigt |
| ~~B2~~ | ~~URL-Feld verstümmelt Fließtext~~ — **behoben** | `RemindersStore:829` | ~~Hoch~~ | erledigt |
| ~~B3~~ | ~~Entzogene Berechtigung wird nie bemerkt~~ — **behoben** | `RemindersStore:272` | ~~Hoch~~ | erledigt |
| ~~C1~~ | ~~Dunkelmodus + „Transparenz reduzieren" kippt die Tiefenordnung~~ — **behoben** | `DesignSystem:158` | ~~Hoch~~ | erledigt |
| V0b | Editor ist nicht modal — Statistik öffnet darüber | `BoardView:156` | Mittel | live |
| ~~V1~~ | ~~„Keine Notizen" so laut wie eine echte Notiz~~ — **behoben** (Platzhalter sekundär) | `CardView:225` | ~~Mittel~~ | erledigt |
| ~~A5~~ | ~~Leerzeilen-Notizen werden dauerhaft geschrieben~~ — **behoben** | `TicketEditSheet:648` | ~~Mittel~~ | erledigt |
| ~~B4~~ | ~~Alle Listen abgewählt → „Nichts zu tun"~~ — **behoben** | `Models:288` | ~~Mittel~~ | erledigt |
| ~~B5~~ | ~~Schreibfehler sind bis auf einen Pfad stumm~~ — **behoben** | `RemindersStore:92` | ~~Mittel~~ | erledigt |
| ~~B6~~ | ~~Undo-Eintrag vor dem Speichern registriert~~ — **behoben** | `RemindersStore:517` | ~~Mittel~~ | erledigt |
| B8 | Durchsatz teilt immer durch 30 (junges Board rechnet zu niedrig) | `WrappedStats:171` | Mittel | gelesen |
| B10 | Weckzeiten werden beim Datumswechsel nicht mitgeführt | `RemindersStore:874` | Mittel | offen |
| C2 | Karten können über den Kopf von „In Bearbeitung" zeichnen | `ColumnView:188` | Mittel | gelesen |
| ~~C4~~ | ~~Deutsche Pluralfehler („1 Karten")~~ — **behoben** | `Models:GermanPlural` | ~~Mittel~~ | erledigt |
| C7 | „+" bei aktivem Filter erzeugt eine verschwindende Karte | `RemindersStore:562` | Mittel | gelesen |
| D1 | Sichtbare Notizen werden VoiceOver nie vorgelesen | `CardView:125` | Mittel | gelesen |
| D2 | Umbenennen-Feld hat keine eigene Repräsentation | `CardView:350` | Mittel | gelesen |
| ~~E2~~ | ~~Leerzeichen-Suche markiert das Board als gefiltert~~ — **behoben** | `RemindersStore:1105` | ~~Mittel~~ | erledigt |
| E5 | „Beim Anmelden starten" scheitert stumm | `SettingsView:116` | Mittel | gelesen |
| E7 | Fokusdiebstahl bei jedem Fensterwechsel | `TicketEditSheet:866` | Mittel | gelesen |
| ~~A6~~ | ~~Reiner Lesevorgang schreibt bei Randleerzeichen~~ — **behoben** | `TicketEditSheet:615` | ~~Niedrig~~ | erledigt |
| B7 | Verwaiste Undo-Einträge nach abgebrochener Neuanlage | `RemindersStore:578` | Niedrig | gelesen |
| B9 | „0 Tage" bei der Durchlaufzeit | `StatsPopover:652` | Niedrig | gelesen |
| B11 | Undo einer Fertigstellung bei Wiederkehrern | `RemindersStore:382` | Niedrig | offen |
| B12 | ⌘Q mit offenem Editor verliert den Edit | `TicketEditSheet:136` | Niedrig | offen |
| C3 | Dritte Textstufe auf Text („Seit Juni 2025") | `StatsPopover:450` | Niedrig | live |
| C5 | Datum und Wiederholung tauschen die Reihenfolge | `CardView:188` | Niedrig | gelesen |
| C6 | Tooltip auf der geöffneten Karte | `TicketEditSheet:216` | Niedrig | gelesen |
| C8 | Drop-Platzhalter sitzt hinter Fußzeile und „+" | `ColumnView:153` | Niedrig | gelesen |
| C9 | „Kontrast erhöhen" erreicht das Drag-Feedback nicht | `ColumnView:411` | Niedrig | gelesen |
| C10a | `columnInnerShadow` nicht scheme-abhängig | `DesignSystem:142` | Niedrig | gelesen |
| C10b | „Bewegung reduzieren" an drei Stellen ignoriert | `ColumnView:211` | Niedrig | gelesen |
| C10c | Aufgeklappter Backlog klappt in der Sitzung nie zu | `ColumnView:14` | Niedrig | gelesen |
| C10d | „Uhrzeit" einschalten setzt 00:00 (Mitternachtsalarm) | `TicketEditSheet:540` | Niedrig | gelesen |
| C10e | Fälligkeit ist Druckknopf, Liste/Dringlichkeit sind Menüs | `TicketEditSheet:486` | Niedrig | live |
| V0d | Zähler „Erledigt" springt beim Aufklappen (4 → 15) | `ColumnView:362` | Niedrig | live |
| D3 | Listenname doppelt für VoiceOver | `CardView:130` | Niedrig | gelesen |
| D4 | WIP-Zeile erklärt ihre Zahl nicht | `StatsPopover:359` | Niedrig | gelesen |
| ~~E1~~ | ~~„Filter zurücksetzen" ist immer aktiv~~ — **behoben** | `GlassKanbanApp:49` | ~~Niedrig~~ | erledigt |
| E3 | ⌘N liegt auf „In Erinnerungen öffnen" | `GlassKanbanApp:33` | Niedrig | gelesen |
| E4 | ⌘F taucht in keinem Menü auf | `BoardView:280` | Niedrig | gelesen |
| ~~E6~~ | ~~Einstellungen nennen die falsche Ursache~~ — **behoben** | `SettingsView:51` | ~~Niedrig~~ | erledigt |
| ~~F1~~ | ~~`updateTicket` schreibt den unsanitisierten Titel~~ — **behoben** | `RemindersStore:924` | ~~Aufräumen~~ | erledigt |
| F2 | `reminder.calendar` ohne nil-Guard | `RemindersStore:672` | Aufräumen | gelesen |
| F3 | Farbe der „Häufigsten Liste" nicht deterministisch | `WrappedStats:155` | Aufräumen | gelesen |
| F4 | „Letzte 30 Tage" hart kodiert statt `trendWindowDays` | `StatsPopover:534` | Aufräumen | gelesen |
| F5 | Toter Code, durch Tests festgezurrt (`weekCount`, `last7`, …) | `StreakCalculator:17` | Aufräumen | gelesen |
| F6 | Kommentar behauptet „built once per card" — stimmt nicht | `Models:115` | Aufräumen | gelesen |
| F7 | CRLF-Notizen hinterlassen eine Leerzeile | `StatusTagger:112` | Aufräumen | gemessen |
| F8 | Observer wird abgemeldet, aber nicht auf `nil` gesetzt | `TicketEditSheet:863` | Aufräumen | gelesen |

**Geprüft, bewusst nicht übernommen:** V2 — Trennlinien auf Textfarbe ziehen
(Linie 22 Stufen vom Papier, Text 129 — sechsmal kräftiger; würde Struktur zu einer
gezogenen Linie machen).

---

## V — Aus dem visuellen Test

Zwei Durchgänge: 28 Kartenzustände in einem Harnisch gerendert und vermessen, danach
die **laufende App direkt bedient** (Editor, Kontextmenü, Suche, Statistik, Falte,
Einstellungen, Hover).

### ~~V0. Escape schließt den Editor nicht~~ — FEHLALARM · `widerlegt`

Im automatisierten Test blieb der Editor bei Escape offen (⌘Return schloss ihn sofort).
Der Test lief mit **synthetischen** Tastenereignissen; David hat es am 26.07. mit der
echten Tastatur gegengeprüft: **Escape funktioniert.**

Ursache des Fehlalarms: `EditorKeyCommands` hängt an
`NSEvent.addLocalMonitorForEvents` (`TicketEditSheet.swift:784`). Synthetisch erzeugte
Escape-Ereignisse erreichen diesen Monitor offenbar nicht so wie echte — ⌘Return
dagegen schon. Kein Codefehler.

**Lehre für künftige Tests:** Tastaturbefunde an dieser App nicht aus synthetischen
Ereignissen ableiten, ohne sie mit echter Tastatur zu bestätigen.

### V0b. Der Editor ist nicht modal · `live reproduziert`
Bei offenem Editor bleibt die Toolbar bedienbar: Ein Klick auf die Flamme öffnet das
Statistik-Fenster **über** dem offenen Editor, beide sind gleichzeitig sichtbar. In
diesem Zustand schließt Escape gar nichts mehr; nur ein Klick auf die abgedunkelte
Fläche löst ihn auf (und speichert dabei).

### V0c. Platzhalter sind im Editor nicht von Inhalt zu unterscheiden · `live reproduziert`
Im geöffneten Ticket stehen „Keine Notizen" und „Keine URL" in **vollem Schwarz**,
exakt wie getippter Text — direkt darüber steht „Dringlichkeit: Keine" als echter Wert.
Man kann nicht erkennen, ob das Notizfeld leer ist oder den Text „Keine Notizen"
enthält; mit Cursor im Feld verstärkt sich das.

Widerspruch in derselben App: Das Suchfeld zeigt seinen Platzhalter „Aufgabe finden"
normal **gedimmt**. Zwei Platzhalter-Logiken nebeneinander.

Siehe V1 — beide Punkte hängen an derselben Entscheidung und sollten zusammen
entschieden werden.

### V0d. Zähler der Spalte „Erledigt" springt beim Aufklappen · `live reproduziert`
Zugeklappt „4", aufgeklappt „15". Der Kopf zählt sichtbare Karten, nicht erledigte
Arbeit — die Zahl ändert sich, obwohl sich nichts getan hat.

### V0e. Live bestätigt und in Ordnung
- **Beide Statistik-Register exakt gleich hoch** — „Jetzt" und „Rückblick" enden auf
  derselben Pixelzeile, das Fenster springt beim Umschalten nicht (deine Regel hält)
- **Keine Tooltips auf Karten** — nach 2 s Hover erscheint nichts
- **Kontextmenü** vollständig: Bearbeiten, In Erinnerungen öffnen, Verschieben nach ▸,
  Umbenennen, Löschen
- **Falte** in „Erledigt" klappt sauber auf und zu
- **Spaltenkopf-Tooltips** erscheinen korrekt („4 Karten / 1 heute erledigt /
  11 ältere Karten")
- **Suche** setzt über „Alles zurücksetzen" sauber zurück
- **C3 sichtbar bestätigt**: „Seit Juni 2025" im Rückblick ist merklich blasser als
  jede Beschriftung darüber und verschwindet fast im Hintergrund
- **E2 sichtbar bestätigt**: ein getipptes Leerzeichen setzt das Lupen-Badge auf „1"
  und blendet „Alles zurücksetzen" ein, ohne etwas zu verbergen

Aus dem Rendering-Durchgang: `ImageRenderer` stellt `ScrollView`, `TextField`,
`TextEditor` und `Picker` nicht dar — die Spaltenansicht ließ sich so nicht prüfen
(C2 blieb dadurch ungetestet, siehe dort).

### V1. „Keine Notizen" ist jetzt so laut wie eine echte Notiz · `gemessen`
`CardView.swift:220-248`

Folge zweier Entscheidungen, die je für sich gewollt sind: Platzhalter trägt die Stufe
seines Inhalts, und der Notizinhalt ist seit dem 26.07. primär. Ergebnis: Eine Karte
**ohne** Notiz verkündet ihre Leere in vollem Schwarz, genauso kräftig wie eine Karte
mit Inhalt. Auf einem Brett, auf dem die meisten Backlog-Tickets keine Notiz haben,
ist das viel Tinte für „hier steht nichts".

Optionen: (a) so lassen — der Platzhalter ist Teil der Anatomie; (b) Platzhalter
zurück auf sekundär — kostet die eben beschlossene Ein-Farb-Regel für die Zone;
(c) Platzhalter nur in den Arbeitsspalten zeigen, wo die Zone ohnehin steht.
**Entscheidung offen.**

### V2. Trennlinien auf Textfarbe ziehen — geprüft, nicht sinnvoll · `gemessen`

Gemessen: Trennlinie hell (233) / dunkel (79), Listenname hell (126) / dunkel (168),
Kartenpapier hell (255) / dunkel (64). Die Linie steht 22 Stufen vom Papier ab, der
Text 129 — rund sechsmal kräftiger. `zoneDivider` (`CardView.swift:257`) und die
Kartenkontur (`:473`) teilen sich bereits **einen** Token (`Board.cardBorder`), die
Konsistenz innerhalb der Karte ist also gegeben. Eine Linie auf Textstärke wäre keine
Struktur mehr, sondern eine gezogene Linie quer über die Karte.
**Nicht übernehmen.** Falls die Linien zu blass wirken: kleiner Schritt am Token, nicht
Angleichung an Text.

### V3. Visuell geprüft und in Ordnung
Sehr lange Titel (3 Zeilen + Ellipse), unbrechbare Langwörter (brechen sauber über
3 Zeilen), Emoji/CJK/Umlaute (Zeilenhöhe konstant), leerer Titel → „Ohne Titel",
Kompaktzeile mit Priorität + Wiederholung + Datum, Durchstrich in „Erledigt"
(inkl. Ellipse), Fälligkeits-Badge „Heute", Verweildauer „9 Tage", Farbstreifen der
Liste in beiden Erscheinungsbildern. WIP-Kapsel färbt bei 7/3 korrekt als „über Limit".

---

## A — Datenverlust (zuerst)

### ~~A1. Hashtag ohne linke Wortgrenze zerstört Nutzertext, ohne Zutun~~ · BEHOBEN 26.07.
`GlassKanban/StatusTagger.swift:16-29`

Alle sechs Tag-Muster haben `\b` nur rechts. Ausgeführt:

| Notiz vorher | danach |
|---|---|
| `Doku: https://example.com/guide#next` | `Doku: https://example.com/guide` + Karte springt nach „Als Nächstes" |
| `Siehe https://wiki.intern/roadmap#progress` | `Siehe https://wiki.intern/roadmap` |
| `Aufgabe fuer #next-steps Meeting` | `Aufgabe fuer -steps Meeting` |
| `Kunde: #bearbeitung/2024 Akte` | `Kunde: /2024 Akte` |

`performTagHygiene` (`RemindersStore.swift:467`) läuft bei **jedem** Refresh — Start,
jede iCloud-Änderung, Aufwachen, Mitternacht — und schreibt ohne Rückfrage und ohne
Undo-Eintrag. Reichweite: `completed` wird über 400 Tage geholt (`:168`), es werden also
auch längst erledigte Erinnerungen umgeschrieben, die auf dem Board nie sichtbar sind.

Fix: `(?<![\w/])` vor dem `#` in allen sechs Mustern; zusätzlich klären, ob die Hygiene
über das sichtbare Fenster hinaus laufen soll. Testfälle gehören in `StatusTaggerTests`
(dort wird bisher nur die rechte Grenze geprüft, `:33-35`).

### A2. Editor schreibt gegen veralteten Stand (Lost Update) · `gelesen`
`TicketEditSheet.swift:135` (`.task { load() }`, läuft genau einmal),
`RemindersStore.swift:874-883` (schreibt alle Felder unbedingt)

Editor offen lassen → am iPhone die Notiz derselben Erinnerung ergänzen → am Mac nur die
Dringlichkeit ändern und schließen. Die iPhone-Zeile ist weg, ohne Hinweis.

Für den **Status** ist genau dieses Problem erkannt und gelöst (Kommentar bei
`RemindersStore.swift:862-866` liest den Status frisch aus dem Reminder) — für den
Inhalt fehlt die Entsprechung. Von zwei Reviewern unabhängig gefunden.

### A3. Undo nach Löschen stellt Unteraufgaben und Anhänge nicht wieder her · `gelesen`
`RemindersStore.swift:650-663`, `:699-736`

Löschen fragt bewusst nicht nach, ⌘Z ist die einzige Absicherung. `restoreTicket` legt
eine **neue** Erinnerung an und kopiert nur, was EventKit öffentlich anbietet.
Unteraufgaben, Anhänge, Reminders-Tags und -Flags sind endgültig weg.
Entweder Warnung im Menüpunkt oder Rückfrage für Tickets mit solchen Feldern.

### A4. Edit geht stumm verloren, wenn die Karte aus dem Cache fällt · `gelesen`
`RemindersStore.swift:844-845` — `guard … cards.firstIndex(…) else { return }`

Der zweite Teil des Guards dient nur dem optimistischen UI-Update, bricht aber den
ganzen Schreibvorgang ab, ohne `pendingSaveFailure` zu setzen. Auslöser: während der
Editor offen ist, die Liste der Karte in den Einstellungen abwählen — oder die
Erinnerung wird auf einem anderen Gerät gelöscht.

### A5. Leerzeilen-Notizen werden dauerhaft geschrieben · `gelesen`
`TicketEditSheet.swift:259` prüft `notes.isEmpty` statt „nur Whitespace"

Dreimal Return in ein leeres Notizfeld, schließen: In Backlog und Erledigt landet
`"\n\n\n"` im Reminder, `lastModifiedDate` steigt (Verweildauer springt zurück), und
beim erneuten Öffnen fehlt „Keine Notizen" trotz sichtbar leerem Feld — dauerhaft.

### A6. Reiner Lesevorgang schreibt bei Randleerzeichen im Titel · `gelesen`
`TicketEditSheet.swift:645` trimmt, `:655` vergleicht gegen den ungetrimmten Stand.
Titel `"Angebot prüfen "` → Öffnen und Schließen genügt für einen Schreibvorgang.

---

## B — Falsche Werte und stille Fehlschläge

### B1. Zeitzone der Fälligkeit geht bei jedem Speichern verloren · `gemessen`
`RemindersStore.swift:877-879` schreibt `dateComponents` ohne `timeZone`.
Gemessen: 01.08.2026 09:00 Europe/Berlin, Gerät in New York, beliebiges Feld geändert
→ zurück in Berlin gelesen 03:00. Sechs Stunden, ausgelöst durch eine fremde Änderung.
`deleteTicket` macht es richtig (`:677-678`, kopiert die Components unverändert).

### B2. URL-Feld verstümmelt statt zu verwerfen · `gemessen`
`RemindersStore.swift:805-818`. Der Kommentar sagt, Text mit Leerzeichen werde nicht
gespeichert. Ab macOS 14 kodiert `URL(string:)` per Default:

```
"Notiz mit Leerzeichen" -> "Notiz%20mit%20Leerzeichen"
"münchen.de"            -> "m%C3%BCnchen.de"
"https://münchen.de"    -> "https://xn--mnchen-3ya.de"
```

Beim nächsten Öffnen sieht man den eigenen Text verstümmelt.

### B3. Entzogene Berechtigung wird nie bemerkt · `gelesen`
`RemindersStore.swift:266-277` — `evaluateAccess()` läuft nur beim Start und danach nur
hinter `guard accessState == .denied`. Ein Übergang „erlaubt → verweigert" ist zur
Laufzeit unmöglich. Folge: Board zeigt **„Nichts zu tun"** statt „Kein Zugriff",
Streak wirkt gerissen.

### B4. Alle Listen abgewählt → Board behauptet „Nichts zu tun" · `gelesen`
`RemindersStore.swift:354-360` setzt Karten *und* Statistiken zurück; die Toolbar-Flamme
verschwindet trotz vorhandener Historie. `SettingsView.swift:44-59` warnt nicht.

### B5. Schreibfehler sind bis auf einen Pfad stumm · `gelesen`
`move` (`:508`), `renameTicket` (`:755`), `deleteTicket` (`:684`),
`createTicketForEditing` (`:569`) fangen den Fehler und rufen nur `scheduleRefresh()`.
Nur `updateTicket` setzt `pendingSaveFailure`. Betrifft besonders schreibgeschützte
(geteilte, abonnierte) Listen — `allowsContentModifications` wird nur an einer einzigen
Stelle geprüft (`:825`, Listen-Picker).

### B6. Undo-Eintrag wird vor dem Speichern registriert · `gelesen`
`RemindersStore.swift:500` (`move`) und `:848-861` (`updateTicket`). Schlägt der Save
fehl, liegt ein wirkungsloser Eintrag auf dem Stapel: ⌘Z tut scheinbar nichts und
verbraucht einen Schritt, der nächste ⌘Z nimmt dann eine ältere Änderung zurück.
Alle übrigen Pfade registrieren korrekt **nach** dem Save.

### B7. Verwaiste Undo-Einträge nach abgebrochener Neuanlage · `gelesen`
`RemindersStore.swift:578-580` vs. `:623-628` — das „+"-Undo bleibt liegen, nachdem
`cancelNewTicket` den Reminder wieder entfernt hat.

### B8. Durchsatz teilt immer durch 30 · `gelesen`
`WrappedStats.swift:171`. Board mit 6 Tagen Historie und 30 Erledigungen meldet 1,0/Tag
statt 5. Schlägt auf „Pro Woche" (7 statt 35) und die „Bis fertig"-Schätzung durch.
`historyStart` (`:56`) läge vor und könnte das Fenster kappen.

### B9. „0 Tage" bei der Durchlaufzeit · `gelesen`
`StatsPopover.swift:652-657`. Aufgaben, die am selben Tag erfasst und erledigt werden,
ergeben „0 Tage". Sinnvoll wäre „Unter 1 Tag" oder „Am selben Tag".

### B10. Weckzeiten werden beim Datumswechsel nicht mitgeführt · `offen`
`RemindersStore.swift:874-883` fasst `reminder.alarms` nicht an, obwohl
`deleteTicket`/`restoreTicket` sie ausdrücklich sichern und wiederherstellen.
Datum verschieben → Benachrichtigung kommt zur alten Zeit; Datum entfernen → Alarm
bleibt. EventKit-Seite gehört am Gerät verifiziert.

### B11. Undo einer Fertigstellung bei Wiederkehrern · `offen`
`RemindersStore.swift:382-391` hält fest, dass EventKit die erledigte Instanz aus der
Serie löst. `move` behandelt Wiederholungen nicht gesondert. Verdacht: nach „auf Erledigt
ziehen → ⌘Z" stehen zwei offene Instanzen auf dem Board. Braucht einen echten Wiederkehrer.

### B12. ⌘Q mit offenem Editor · `offen`
`TicketEditSheet.swift:136-154` — `.onDisappear` ist der einzige Schreibzeitpunkt.
Bei Terminierung ruft SwiftUI ihn typischerweise nicht: Edit weg, und ein gerade per „+"
angelegtes Ticket bleibt als leere Erinnerung liegen.

---

## C — Darstellung

### C1. Dunkelmodus + „Transparenz reduzieren" kippt die Tiefenordnung · `gemessen, gerendert`
`CardView.swift:462-466`, `ColumnView.swift:624-628`, `:660`

Gemessene Helligkeit:

| Fläche | Hell | Dunkel |
|---|---|---|
| Karte (`controlBackgroundColor`) | 1.000 | **0.118** |
| Mulde (`underPageBackgroundColor`) | 0.588 | **0.157** |
| „+"-Scheibe (`windowBackgroundColor`) | 1.000 | **0.118** |

Die Karte ist dunkler als die Spalte, auf der sie liegt — exakt die Inversion, gegen die
`DesignSystem.swift:122-126` argumentiert („elevated = lighter" in dark). Der „+"-Knopf
liest sich als Loch. Nebenbefund: der Fallback ignoriert `isDone`, erledigte und aktive
Karten sind dort farblich identisch.

Im Rendering unmissverständlich: die Karten wirken wie ausgestanzte Löcher im Panel
statt wie aufliegendes Papier. Der einzige Befund der Liste, den man auf einen Blick
sieht.

### C2. Karten können über den Kopf von „In Bearbeitung" zeichnen · `gelesen` (Rendering nicht möglich)
`ColumnView.swift:188` — `.scrollClipDisabled(status == .inProgress)` plus 20 pt
Maskenluft. Der Kommentar direkt darüber nennt als Grund, warum die anderen Spalten ihr
Clipping behalten, genau diesen Effekt. Tritt ein, sobald die Spalte scrollt; das
WIP-Limit ist weich („Passt schon").

### C3. Dritte Textstufe auf Text · `gelesen`
`StatsPopover.swift:450-452` — die „Seit …"-Fußnote läuft auf `.tertiary` (nur bei
erhöhtem Kontrast auf `.secondary`). Einzige echte Abweichung von der Zwei-Stufen-Regel;
`CardView`, `ColumnView`, `BoardView`, `EmptyBoardNotice` halten sie lückenlos.
`FindPopover.swift:71` ist ein Button-Glyph, kein Text — kann bleiben.

### C4. Deutsche Pluralfehler · `gelesen`
- `ColumnView.swift:362` → **„1 Karten"** (Spaltenkopf-Tooltip, tritt regelmäßig auf)
- `ColumnView.swift:377` → „1 ältere Karten"
- `BoardView.swift:250` → „Folge: 1 Tage nacheinander" (VoiceOver)
- `BoardView.swift:285` → „1 Einschränkungen aktiv" (VoiceOver, bei jedem einzelnen Filter)
- `StatsPopover.swift:564` → „an 1 Tagen etwas erledigt" (VoiceOver)

Die passenden Helfer existieren bereits: `StatsPopover.swift:639-645` (`days()`, `tasks()`).

### C5. Datum und Wiederholung tauschen die Reihenfolge · `gelesen`
`CardView.swift:188-192` (voll: Badge, dann Icon) vs. `:282-286` (kompakt: Icon, dann
Badge). Eine Karte tauscht beim Wechsel Backlog → Arbeitsspalte ihre beiden Meta-Marken.

### C6. Tooltip auf der geöffneten Karte · `gelesen`
`TicketEditSheet.swift:216` — `.help("In Erinnerungen öffnen")`. Steht quer zur Regel
„keine Tooltips auf Karten, nur am Chrome" und zu `BoardTooltip.swift:101`
(„Replaces `.help()` — do not use both").

### C7. „+" bei aktivem Filter erzeugt eine verschwindende Karte · `gelesen`
`RemindersStore.swift:562-588` + `ColumnView.swift:157`. Das neue Ticket ist leer, fällt
also durch den Filter, sobald der Editor zugeht. Die „keep in sight"-Logik greift nicht,
sie prüft die bereits gefilterte Liste.

### C8. Drop-Platzhalter sitzt hinter Fußzeile und „+" · `gelesen`
`ColumnView.swift:153-165` — im gefalteten Backlog liegt der gestrichelte Rahmen unter
dem Anlegen-Button, vom Stapel abgetrennt.

### C9. „Kontrast erhöhen" erreicht das Drag-Feedback nicht · `gelesen`
`ColumnView.swift:411`, `:413`, `:427`, `:620` nehmen kein `contrast` entgegen, während
`Board.columnBorder`/`cardBorder` es sauber auswerten.

### C10. Kleinigkeiten · `gelesen`
- `DesignSystem.swift:142` — `columnInnerShadow` ist als einziger Mulden-Token nicht
  scheme-abhängig, im Dunkelmodus praktisch unsichtbar
- `ColumnView.swift:211`, `:314`, `:566` — „Bewegung reduzieren" nicht berücksichtigt
  (alle anderen Animationen der Datei sind sauber gegated)
- `ColumnView.swift:14`/`:48` — `expanded` wird nie zurückgesetzt, ein aufgeklappter
  Backlog bleibt es die ganze Sitzung
- `TicketEditSheet.swift:540` — „Uhrzeit" einschalten setzt 00:00, Reminders schickt
  eine Mitternachtsbenachrichtigung
- `TicketEditSheet.swift:486-509` — Fälligkeit ist ein bezelter Button, Liste und
  Dringlichkeit sind Menü-Picker: drei Faktenzeilen, zwei Steuerelement-Typen

---

## D — Barrierefreiheit

### D1. Sichtbare Notizen werden nie vorgelesen · `gelesen`
`CardView.swift:125` (`.accessibilityElement(children: .combine)` + eigenes Label) und
`:382-390` — `helpText` hängt die Notiz nur bei einzeiligen Karten an. Der Auszug, der
auf „Als Nächstes"/„In Bearbeitung" sichtbar auf der Karte steht, erreicht VoiceOver nicht.

### D2. Umbenennen-Feld hat keine eigene Repräsentation · `gelesen`
`CardView.swift:125-127`, `:350-367` — während `isRenaming` bleibt das Label aus
`card.title`, `renameText` taucht nirgends auf. Die Aktion wird angeboten, führt aber in
ein Feld, dessen Inhalt nicht angesagt wird.

### D3. Listenname doppelt · `gelesen`
`CardView.swift:130` + `:387` — steht im Label und im Hint, wird zweimal angesagt.

### D4. WIP-Zeile erklärt ihre Zahl nicht · `gelesen`
`StatsPopover.swift:359-362` — sobald ein Limit gesetzt ist, wird der Limit-Satz zum
`accessibilityValue`; die eigentliche Auslastung wird nie vorgelesen.

---

## E — Bedienung und Menüs

### E1. „Filter zurücksetzen" (⇧⌘F) ist immer aktiv · `gelesen`
`GlassKanbanApp.swift:42-45` ohne `.disabled(…)`, obwohl `RemindersStore.swift:1024`
mit `canResetFindSettings` genau die Bedingung liefert (`FindPopover.swift:38` nutzt sie).

### E2. Leerzeichen-Suche markiert das Board als gefiltert · `gelesen`
`RemindersStore.swift:1009`/`:1016` prüfen nur `!searchText.isEmpty`. Ein getipptes
Leerzeichen färbt die Lupe, setzt das Badge auf „1" und behauptet „Board ist gefiltert",
während nichts versteckt ist.

### E3. ⌘N liegt auf „In Erinnerungen öffnen", „Neue Karte" hat keinen Kurzbefehl · `gelesen`
`GlassKanbanApp.swift:33`. So dokumentiert (SPEC.md:183) — trotzdem der Mac-Reflex.

### E4. ⌘F taucht in keinem Menü auf · `gelesen`
Hängt allein am Toolbar-Button (`BoardView.swift:280`).

### E5. „Beim Anmelden starten" scheitert stumm · `gelesen`
`SettingsView.swift:116-119` — der Schalter springt kommentarlos zurück, wenn macOS die
Registrierung blockiert.

### E6. Einstellungen nennen bei fehlendem Zugriff die falsche Ursache · `gelesen`
`SettingsView.swift:46-47` zeigt „Keine Erinnerungslisten gefunden."

### E7. Fokusdiebstahl bei jedem Fensterwechsel · `gelesen`
`TicketEditSheet.swift:866-872` — der `didBecomeKeyNotification`-Observer lebt so lange
wie der Editor und setzt bei **jedem** Key-Werden den First Responder zurück. Notizen
tippen → ⌘Tab weg → zurück → Cursor ist weg. Der Kommentar (`:851-855`) begründet nur
den einmaligen Reset beim Öffnen. Bei einem neuen Ticket schlimmer: die Eingabe geht ins
Leere und `finalizeNewTicket` löscht es beim Schließen als „leer".

---

## F — Aufräumen

- `RemindersStore.swift:891` — `updateTicket` schreibt den **unsanitisierten** Titel in
  die Karte; `renameTicket` macht es an derselben Stelle korrekt (`:766`)
- `RemindersStore.swift:672` — `reminder.calendar` ohne nil-Guard, überall sonst geguardet
- `WrappedStats.swift:155-158` — Farbe der „Häufigsten Liste" hängt an der
  EventKit-Reihenfolge, kann zwischen Refreshes wechseln
- `StatsPopover.swift:534` — „Letzte 30 Tage" hart kodiert statt `trendWindowDays`
- Toter Code, durch Tests festgezurrt: `StreakStats.weekCount`, `StreakStats.last7`,
  `WrappedStats.consistencyRatio`. Dazu veraltet: `StreakCalculator.swift:3` spricht vom
  7-Tage-Streifen, das Popover zeigt 30
- `Models.swift:115-118` — Kommentar behauptet „built once per card", `searchHaystack`
  ist ein `var` und wird pro Tastendruck neu gebaut
- `StatusTagger.swift` — CRLF-Notizen hinterlassen beim Entfernen der Tag-Zeile eine
  Leerzeile (`.whitespaces` enthält kein `\r`)
- `TicketEditSheet.swift:863` — Observer wird abgemeldet, aber nicht auf `nil` gesetzt

---

## Geprüft und in Ordnung

- **160 Unit-Tests grün**, Build fehlerfrei
- **Zwei-Textstufen-Regel** hält in `CardView`, `ColumnView`, `BoardView`,
  `EmptyBoardNotice` lückenlos (einzige Abweichung: C3)
- **Statistik-Register gleich hoch** — `ZStack` + `fixedSize` intakt
  (`StatsPopover.swift:115-136`)
- **Toolbar-Flamme** korrekt an Historie gekoppelt (Ausnahme: B4)
- **Konvergenz der Tag-Hygiene** — Fuzz über alle Fragment-Kombinationen, kein Fall
  brauchte mehr als einen Durchlauf, keine Schreibschleife
- **Notizen zeichengenau** — Absätze und Leerzeilen überleben (Ausnahme: CRLF, F)
- **Zeitzonen in Serie und Statistik** — durchgehend `startOfDay`, Mitternachts-Timer,
  Refresh nach Aufwachen
- **Randfälle der Karte** — sehr lange Titel, unbrechbare Langwörter, Emoji/CJK/Umlaute
  (Zeilenhöhe konstant), leerer Titel → „Ohne Titel", lange Listennamen, fehlende Notiz,
  fehlende Fälligkeit
- **Startabsturz vom 20. Juli** (`AppAppearance.apply()`) behoben, Fix kam 5 Minuten
  nach dem Absturzbericht

## Fehlalarm

Die App schien ohne Fenster zu starten. Safari, Mail und Finder meldeten zur selben Zeit
ebenfalls null Fenster — Ursache war der laufende Bildschirmschoner, kein App-Fehler.

## Seit dem Test bereits erledigt

- **Notiz auf der Karte auf primär gezogen** (`CardView.swift:220`), damit derselbe Text
  beim Öffnen des Tickets nicht die Farbe wechselt. Regel in `DesignSystem.swift` und
  SPEC.md neu gefasst: primär = was das Ticket *sagt* (Titel, Notiz), sekundär = was es
  *beschreibt*. Zieht V1 nach sich.
- **Erledigt-Titel nicht mehr gedämpft** (Commit `9147c08`) — der Durchstrich sagt es
  bereits.
- **Platzhalter-Stufe vereinheitlicht** (Commit `9147c08`) — keine eigene dritte
  Graustufe mehr für „Keine …".
