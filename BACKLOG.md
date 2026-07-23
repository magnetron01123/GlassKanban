# Glass Kanban — Backlog

Alles, was bewusst **nicht** in den MVP geht. Sortiert nach Kategorie, jeweils mit kurzer
Begründung, warum später (oder warum grundsätzlich nicht).

## Karten-Anzeige (später ergänzen)

- **Prioritäts-Icon auf der Karte** — MVP zeigt nur Titel, Notizen-Vorschau und Fälligkeit, um
  die Karte bewusst reduziert zu halten. Dringlichkeit bleibt trotzdem als Filter nutzbar, nur
  nicht als Dauer-Badge auf jeder Karte.
- **Verantwortliche-Person-Avatar auf der Karte** — hängt am Verantwortliche-Person-Filter
  (s. u.), daher zusammen verschoben.
- **Eigene Hashtags aus den Notizen als Tag auf der Karte anzeigen** — wer Erinnerungen schon
  mit eigenen Hashtags kategorisiert (z. B. `#projektx`), sieht die aktuell nur als rohen Text
  in der Notizen-Vorschau, sofern es nicht zufällig der Status-Hashtag ist (der schon
  herausgefiltert wird, siehe SPEC.md). Vorschlag: eigene Hashtags erkennen und als kleine
  Tag-Chips auf der Karte anzeigen statt/zusätzlich zur reinen Notizen-Vorschau. Bewusst nicht
  im MVP: Karte soll reduziert bleiben, und Hashtag-Erkennung im Notiztext ist bereits fürs
  interne Status-Tag reserviert — Kollision/Abgrenzung zwischen Status-Hashtag und
  Nutzer-Hashtag (und Darstellung bei mehreren Tags) müsste sauber gelöst werden.

## Filter

- **Verantwortliche-Person-Filter** (`EKCalendarItem.attendees`) — funktioniert nur bei über
  iCloud geteilten Listen, nur lesend (EventKit erlaubt kein Zuweisen). Mehr Sonderfall-Logik
  für einen Filter, der nur bei einem Teil der Nutzer/Listen überhaupt Daten liefert. Sinnvoll
  nachzuholen, sobald geteilte Listen im Alltag tatsächlich genutzt werden.

## Board-Struktur

- ~~**WIP-Limit für "In Bearbeitung"**~~ — umgesetzt, siehe SPEC.md (Herleitung in
  CONCEPT.md, Abschnitt Motivation). Anders als hier gedacht in den Einstellungen
  konfigurierbar, teal statt amber (amber liegt zu nah an der Dringlichkeitsfarbe), und
  "In Bearbeitung" fragt beim Überschreiten einmal nach, statt nur die Farbe zu wechseln.
- **Swimlane-Trennung im Backlog ("Heute-Absatz")** — dringliche Karten (überfällig/heute)
  schwimmen bereits nach oben, gehen aber nahtlos in den Rest über. Eine einzige feine
  Trennlinie unter der letzten dringlichen Karte würde den Backlog in zwei stille Absätze
  teilen: "heute dran" und "später" — kein Text, keine Farbe, nur Raum-Typografie (vgl.
  Things' Today-Moment). Gehört inhaltlich mit dem WIP-Limit zusammen: beide machen
  *Menge* sichtbar, ohne zu bevormunden. Zurückgestellt, bis das Kartendesign final ist,
  weil beide Signale sonst mit der Dringlichkeitsfarbe konkurrieren könnten.
- **Frei anlegbare Swimlanes** — horizontale Gruppen, die Nutzer:innen selbst benennen,
  anlegen und Karten zuordnen können (z. B. nach Projekt oder eigener Kategorie), quer über
  die Spalten. Deutlich größerer Scope als die "Heute-Absatz"-Trennung oben (die ist
  automatisch und ungestaltbar, nur im Backlog) — hier braucht es Verwaltungs-UI (anlegen,
  umbenennen, löschen) und eine Datenquelle für die Zuordnung. Offene Frage: gleicher
  Hashtag-Mechanismus wie bei den Spalten, oder etwas anderes, das nicht mit dem
  Status-Hashtag kollidiert.
- **Mehrere Boards** — MVP ist bewusst ein einzelnes Board.
- **Konfigurierbare Spaltenanzahl/-namen** — MVP hat vier feste Spalten.
- **Manuelle Kartenreihenfolge innerhalb einer Spalte** — MVP sortiert automatisch nach
  Fälligkeitsdatum.

## Wiederkehrende Aufgaben (Reminders-Wiederholung)

- **Verhalten wiederkehrender Erinnerungen beim Abhaken klären** — Reminders erlaubt
  Wiederholungsregeln (täglich/wöchentlich/…) pro Erinnerung; wie sich das mit dem
  Status-Hashtag-Mechanismus und dem Erledigt-Zustand verträgt, ist ungeklärt. Offene Fragen:
  (1) Setzt EventKit beim Abhaken einer wiederkehrenden Erinnerung `isCompleted` überhaupt
  sichtbar/dauerhaft, oder springt sie sofort auf die nächste Fälligkeit, ohne dass die App den
  "Erledigt"-Moment je beobachten kann? (2) Falls ja: bleibt der alte Status-Hashtag (z. B.
  `#inbearbeitung`) in den Notizen stehen, bis die bestehende Hygiene-Pass beim nächsten Sync
  greift, oder kann das mit dem Wiederholungs-Sprung kollidieren (Karte taucht kurz in der
  falschen Spalte auf)? (3) Zählt eine wiederkehrende Erledigung überhaupt zum Streak-Zähler,
  oder fehlt dafür schlicht ein beobachtbares `completionDate`? Muss erst gegen echtes
  EventKit-Verhalten geprüft werden — kein Blocker fürs MVP, aber ein bekannter blinder Fleck.
  (Das ↻-Icon auf der Karte, das eine Wiederholung überhaupt erst sichtbar macht, gibt es
  bereits — `CardView.repeatIcon` — hier geht es nur noch um das Verhalten beim Abhaken.)
- ~~**Backlog-Sichtbarkeit wiederkehrender, noch nicht fälliger Karten**~~ — umgesetzt, siehe
  SPEC.md (Filterleiste, Zeile "Wiederkehrende").

## Fensterverhalten

- **Menüleisten-Modus / Always-on-Top** — MVP nutzt ein normales Fenster.

## Bewegung / Animation

- **Ausgebautere, aber weiterhin zurückhaltende Übergänge** — über die MVP-Basis (dezente
  Animation bei Spaltenwechsel/Live-Update) hinaus ein eigenes Bewegungs-Vokabular, das den
  Kanban-Fluss-Gedanken spürbar macht: Karten sollen beim Spaltenwechsel wirken, als würden
  sie fließen, nicht springen (z. B. weiches Einrasten nach Drag & Drop, sanftes Nachrücken
  beim automatischen Umsortieren nach Fälligkeit, dezenter Puls beim Streak-Wechsel). Bewusst
  zurückgestellt: MVP-Animation reicht fürs Erst-Release, ein eigenes Timing-/Easing-System ist
  ein eigener Gestaltungs-Durchgang und sollte erst nach final abgenommenem visuellem Design
  (Farben, Kanten, Glas) kommen, damit Bewegung nicht gegen ein sich noch änderndes visuelles
  System gebaut wird. Muss weiterhin "Bewegung reduzieren" respektieren (bereits
  MVP-Anforderung) — mehr Fluss darf für die, die das abgeschaltet haben, nicht bedeuten, dass
  gar keine Rückmeldung mehr da ist, sondern nur, dass sie sofort statt fließend passiert.

## Funktionen mit harter Apple-Plattform-Grenze (nicht nur "später", sondern aktuell technisch
nicht möglich)

- **Unteraufgaben/Subtasks anzeigen** — nicht über die öffentliche EventKit-API zugänglich,
  ähnlich wie Tags eine private Reminders-Funktion.
- **Personen aus Glass Kanban heraus zuweisen** — `attendees` ist bei EventKit nur lesbar,
  Zuweisen muss in der nativen Reminders-App passieren.

## Aufgaben-Bearbeitung in der App

- ~~**Titel, Notizen, URL, Liste, Priorität und Fälligkeit bearbeiten**~~ — **umgesetzt**
  als Karten-Editor (`TicketEditSheet`, siehe SPEC.md): Ein Klick öffnet die Karte
  vergrößert über dem Board. Die ursprüngliche Grundsatzentscheidung „read-only außer
  Drag & Drop" ist damit bewusst und schrittweise revidiert worden — erst der Titel
  (einzeilig, ohne eigene UI), dann die restlichen Felder, als der Umweg über die
  Reminders-App für jede Kleinigkeit einen App-Wechsel kostete.
- **Wiederholungsregeln bearbeiten** — bleibt draußen: eigene, komplexe UI
  (täglich/wöchentlich/benutzerdefiniert…), die Reminders bereits gut löst. Der ↗-Knopf im
  Editor führt genau dafür in die native App.

## Spätere Apple-/Mac-Ausbaustufen

- **Desktop-Widget (WidgetKit)** — kompakte Ambient-Ansicht direkt auf dem Schreibtisch,
  ergänzend oder alternativ zum offenen Fenster.
- **Shortcuts-App/App Intents** — z. B. Karte per Kurzbefehl/Automation verschieben oder
  Kennzahlen abfragen.
- **Fokus-Modi-Integration (Focus Filters)** — Board passt Filter automatisch an aktiven
  macOS-Fokus an (z. B. Arbeit vs. Privat).
- **App-Icon im neuen Icon-Composer-Format** — Light/Dark/Tinted-Varianten mit
  Liquid-Glass-Spiegelungen.

## Statistiken / Jahresrückblick

- ~~**Produktivitäts-Statistiken im Spotify-Wrapped-Stil**~~ — **umgesetzt** als
  Statistik-Fenster hinter der Toolbar-Flamme (Reiter „Jetzt": Folge, heute, Auslastung
  gegen WIP-Limit, Durchlaufzeit-Schätzung, 30-Tage-Verlauf; Reiter „Rückblick":
  Jahreszahl, längste Folge, bester Tag, stärkster Wochentag, häufigste Liste,
  Meilenstein). Die Aggregations-Logik sitzt in `WrappedStats.swift` und läuft ohne zweite
  EventKit-Abfrage in derselben Auswertung mit, die den Streak berechnet.
- **Teilbare Zusammenfassung** — der ursprüngliche Wrapped-Gedanke enthielt eine Share-Ansicht
  zum Weitergeben. Bewusst nicht mitgebaut: das Fenster ist auf einen Blick ausgelegt, eine
  Export-/Teilen-Darstellung wäre ein eigenes Layout mit eigenen Fragen (was darf ein
  Screenshot über Listennamen verraten?).

## Plattform-Erweiterung: iOS-App

- **Begleitende iOS-App (iPhone + iPad)** — eigene Glass-Kanban-Ansicht auf iPhone/iPad statt
  nur über die native Reminders-App unterwegs Hashtags zu setzen (das funktioniert schon jetzt
  ohne eigene App, siehe Bonus-Hinweis in SPEC.md). Eigenes Xcode-Multiplatform-Target, eigene
  UI-Anpassung für kleinere Bildschirme/Touch-Bedienung, eigene App-Store-Überlegungen — klare
  Plattformerweiterung nach dem Mac-MVP, nicht Teil davon.

## Explizit abgelehnt (kein "später", sondern bewusst ausgeschlossen)

- **Eigene Push-Benachrichtigungen der App** — Reminders hat bereits eigene
  Benachrichtigungen; eigene Notifications würden sich doppeln und widersprechen dem ruhigen
  Minimal-Desk-Setup-Vibe der App.
- **Punkte/Levels/Bestenlisten und ein dauerhaftes Abzeichen-Regal** — zu viel Komplexität
  ohne echten Mehrwert für ein Einzelnutzer-Ambient-Board. **Ausnahme (umgesetzt):** der
  Meilenstein-Hinweis im Statistik-Fenster, der nur bei einer in den letzten sieben Tagen
  überschrittenen runden Zahl erscheint und rein abgeleitet ist — siehe CONCEPT.md,
  „Motivation".
- **Täglich wechselnder Motivationssatz** — war ursprünglich als zweites
  Motivationselement neben dem Streak-Zähler geplant (~20 lokale Sätze, Auswahl nach
  Kalendertag) und hat sich in der Praxis als unpraktikabel erwiesen. Ein fest stehender
  Satz auf einem Board, das den ganzen Tag offen liegt, wird nach zwei Tagen weggefiltert
  wie eine Bannerwerbung und kostet trotzdem dauerhaft Fläche — dasselbe Muster, das
  bereits das pulsierende Pull-Signal gekostet hat (siehe CONCEPT.md): Aufmerksamkeit
  gehört Dingen, die gerade passiert sind, nicht Dauerzuständen. Aus derselben Überlegung
  ist das Motivierende dorthin gewandert, wo es an ein Ereignis gekoppelt ist: die sich
  füllende Streak-Flamme und der Settle-Moment beim Erledigen.
- **Bestätigungsdialog vor dem Löschen** — abgelöst durch Undo (⌘Z). Eine Rückfrage
  besteuert jede Löschung, um die seltene falsche abzufangen; ein Undo kostet nur die
  Person etwas, die sich tatsächlich vertan hat, und ist das, wonach ein Mac-Nutzer
  ohnehin greift.
- **Tastaturfokus und Pfeiltasten-Navigation auf Karten** — war im Juli 2026 kurz
  implementiert (fokussierbare Karten, Pfeiltasten über die Spalten, Akzent-Kontur als
  Fokus-Cursor) und wurde auf Nutzerentscheidung wieder entfernt. Karten werden mit der
  Maus hin- und hergeschoben — ein Rahmen, der dauerhaft eine davon hervorhebt, betont
  genau das, was keine Betonung braucht, und stört das ruhige Bild. Nicht wieder
  einführen, ohne diese Entscheidung bewusst zu revidieren. VoiceOver bleibt davon
  unberührt (eigener Cursor, eigene Aktionen auf jeder Karte).
- **Hover-Tooltips auf Karten** — ebenfalls Juli 2026 auf Nutzerentscheidung entfernt
  (vorher: Notizen-Vorschau, Listenname und Gestenhinweis beim Überfahren, Verweildauer-
  und Wiederholungs-Tooltip). Ein Text, der auf jeder berührten Karte aufspringt, ist
  Dauerrauschen und widerspricht dem Minimalismus-Anspruch; alles, was er zeigte, ist
  einen Klick entfernt in Reminders. Tooltips bleiben dem Chrome vorbehalten
  (Spaltenkopf, „+"-Button), wo sie Regeln erklären statt Inhalte zu doppeln. Die
  Inhalte bleiben für VoiceOver als Label/Hint erhalten.
- **„0" in der Streak-Pille anzeigen** — abgelehnt. Eine „0" neben den Fensterknöpfen sieht
  kaputt aus und liest sich als Rüge. Die gültige Lösung steht in SPEC.md und ist bereits
  gebaut: Die Pille erscheint, sobald es überhaupt Historie gibt (`totalCompleted > 0`),
  und zeigt bei Serie 0 **nur die graue Flamme ohne Zahl**. Damit bleibt der Zugang zum
  Statistik-Fenster auch nach einem Serienriss erhalten, ohne die Zahl zu zeigen.
  **Vorgeschichte, damit sie sich nicht wiederholt:** Am 18.07.2026 (`90634bc`) wurde die
  Pille bei Serie 0 komplett ausgeblendet — was den einzigen Zugang zur Statistik mit
  verschwinden ließ. Am 21.07.2026 (`5718915`) wurde daraus die heutige Regel entwickelt.
  Am 23.07.2026 habe ich beim Review beides übersehen, weil ich nur gegen `main` verglichen
  habe statt gegen die tatsächliche Feature-History — erst „immer sichtbar mit 0", dann
  wieder „ganz versteckt". Beides falsch. **Vor Änderungen an bestehendem UI-Verhalten
  immer `git log --all` auf die betroffene Datei prüfen.**
