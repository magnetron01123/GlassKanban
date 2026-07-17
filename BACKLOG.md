# Glass Kanban — Backlog

Alles, was bewusst **nicht** in den MVP geht. Sortiert nach Kategorie, jeweils mit kurzer
Begründung, warum später (oder warum grundsätzlich nicht).

## Karten-Anzeige (später ergänzen)

- **Prioritäts-Icon auf der Karte** — MVP zeigt nur Titel, Notizen-Vorschau und Fälligkeit, um
  die Karte bewusst reduziert zu halten. Dringlichkeit bleibt trotzdem als Filter nutzbar, nur
  nicht als Dauer-Badge auf jeder Karte.
- **Verantwortliche-Person-Avatar auf der Karte** — hängt am Verantwortliche-Person-Filter
  (s. u.), daher zusammen verschoben.

## Filter

- **Verantwortliche-Person-Filter** (`EKCalendarItem.attendees`) — funktioniert nur bei über
  iCloud geteilten Listen, nur lesend (EventKit erlaubt kein Zuweisen). Mehr Sonderfall-Logik
  für einen Filter, der nur bei einem Teil der Nutzer/Listen überhaupt Daten liefert. Sinnvoll
  nachzuholen, sobald geteilte Listen im Alltag tatsächlich genutzt werden.

## Board-Struktur

- **WIP-Limit für "In Bearbeitung"** — passt thematisch zur Personal-Kanban-Philosophie,
  aber zusätzlicher Konfigurations- und UI-Aufwand fürs Erst-Release.
- **Mehrere Boards** — MVP ist bewusst ein einzelnes Board.
- **Konfigurierbare Spaltenanzahl/-namen** — MVP hat vier feste Spalten.
- **Manuelle Kartenreihenfolge innerhalb einer Spalte** — MVP sortiert automatisch nach
  Fälligkeitsdatum.

## Fensterverhalten

- **Menüleisten-Modus / Always-on-Top** — MVP nutzt ein normales Fenster.

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
