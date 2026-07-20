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
  herausgefiltert wird, siehe MVP.md). Vorschlag: eigene Hashtags erkennen und als kleine
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

- **WIP-Limit für "In Bearbeitung"** — passt thematisch zur Personal-Kanban-Philosophie,
  aber zusätzlicher Konfigurations- und UI-Aufwand fürs Erst-Release. Gedachte Umsetzung:
  ab n Karten färbt sich die Zähler-Kapsel der Spalte dezent amber, kein Blocken, kein
  Text — nur ein leises "zu viel offen". Offene Frage: fester Wert oder in den
  Einstellungen konfigurierbar.
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
- **Backlog-Sichtbarkeit wiederkehrender, noch nicht fälliger Karten** — heute zeigt Backlog
  jede Erinnerung mit Datum, auch eine, die monatlich wiederkehrt und erst in drei Wochen wieder
  dran ist. Das verwässert das Backlog mit Karten, die gerade keine echte Entscheidungsoption
  sind (Personal-Kanban-Gedanke: eine Karte im Backlog soll etwas sein, das man als Nächstes
  anfassen könnte — nicht Hintergrundrauschen). Entschieden: **Standard = ausgeblendet**, bis
  die Karte in dasselbe Fälligkeitsfenster fällt, das Badges schon heute nutzen (Überfällig/
  Heute/Diese Woche) — keine neue Fläche, keine Markierung, die Karte erscheint dann einfach mit
  der ohnehin vorhandenen Ankunfts-Animation. Sichtbar/umschaltbar gemacht über eine **dritte
  Zeile im bestehenden Find-Popover** ("Wiederkehrende", gleiche Bauart wie "Dringlichkeit" und
  "Fälligkeit"): Standardwert "Verborgen bis fällig", umschaltbar auf "Immer anzeigen" — dann
  erscheint (wie bei den anderen beiden Filtern beim Abweichen vom Standard) auch der
  "Alles zurücksetzen"-Link. Der Standardwert selbst zählt nicht als aktive Filterung, genau wie
  "Alle" bei den anderen beiden Zeilen nicht zählt — nur "Immer anzeigen" ist eine bewusste
  Nutzerentscheidung. Abhängig davon, wie die Fragen oben zum Abhak-Verhalten ausgehen.

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

- **Aufgaben anlegen/inhaltlich bearbeiten (Titel, Notizen, Fälligkeit, Priorität) in Glass
  Kanban** — bewusste Grundsatzentscheidung, nicht nur Zeitmangel: Inhalte werden
  ausschließlich in der nativen Reminders-App gepflegt, Glass Kanban bleibt überwiegend
  read-only (einzige Ausnahme: Drag & Drop).

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

- **Produktivitäts-Statistiken im Spotify-Wrapped-Stil** — ein jährlicher (oder periodischer)
  Rückblick auf erledigte Karten, ähnlich wie Spotifys Jahresrückblick für gehörte Musik (z. B.
  meistgenutzte Liste, produktivster Wochentag, längste Streak, Gesamtzahl erledigter Aufgaben,
  als teilbare Zusammenfassung). Passt gut zum bestehenden Motivations-Thema (Streak-Zähler),
  braucht aber eigene Aggregations-Logik über historische Daten und eine dedizierte
  Darstellung/Share-Ansicht — deutlich mehr Aufwand als die MVP-Motivationsfeatures, daher erst
  nach stabilem MVP sinnvoll.

## Plattform-Erweiterung: iOS-App

- **Begleitende iOS-App (iPhone + iPad)** — eigene Glass-Kanban-Ansicht auf iPhone/iPad statt
  nur über die native Reminders-App unterwegs Hashtags zu setzen (das funktioniert schon jetzt
  ohne eigene App, siehe Bonus-Hinweis in MVP.md). Eigenes Xcode-Multiplatform-Target, eigene
  UI-Anpassung für kleinere Bildschirme/Touch-Bedienung, eigene App-Store-Überlegungen — klare
  Plattformerweiterung nach dem Mac-MVP, nicht Teil davon.

## Explizit abgelehnt (kein "später", sondern bewusst ausgeschlossen)

- **Eigene Push-Benachrichtigungen der App** — Reminders hat bereits eigene
  Benachrichtigungen; eigene Notifications würden sich doppeln und widersprechen dem ruhigen
  Minimal-Desk-Setup-Vibe der App.
- **Punkte/Levels/Badges/Bestenlisten** — zu viel Komplexität ohne echten Mehrwert für ein
  Einzelnutzer-Ambient-Board.
