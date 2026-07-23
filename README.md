# Glass Kanban

Ein natives macOS-Kanban-Board für Apple Erinnerungen (Reminders) im Liquid-Glass-Design.

Alle Daten leben ausschließlich in Erinnerungen — Glass Kanban ist reine Visualisierung
und Steuerung über EventKit. Kein Server, kein Konto, keine Cloud-Komponente, keine
Zugangsdaten: Die einzige Berechtigung ist der macOS-Systemdialog für den
Erinnerungs-Zugriff.

## Funktionsweise

- **Vier Spalten:** Backlog → Als Nächstes → In Bearbeitung → Erledigt
- **Status als Hashtag in den Notizen** (`#alsnächstes`, `#inbearbeitung`) — die
  Listenzugehörigkeit der Erinnerung bleibt unangetastet, Backlog = kein Tag,
  Erledigt = abgehakt (`isCompleted`)
- **Drag & Drop** zwischen den Spalten; **Klick** auf eine Karte öffnet die Aufgabe im
  Bearbeitungs-Popover der Erinnerungen-App, **Doppelklick** benennt sie direkt auf der
  Karte um
- **Tickets anlegen** über das „+" im Backlog (nur der Titel — Notizen, Datum und
  Priorität bleiben Sache der Erinnerungen-App)
- **Alles widerrufbar:** Verschieben, Umbenennen, Anlegen und Löschen lassen sich mit ⌘Z
  rückgängig machen — deshalb fragt das Löschen nicht nach
- **Bidirektionaler Live-Sync**: Änderungen in der Erinnerungen-App (auch auf
  iPhone/iPad via iCloud) erscheinen sofort im Board — der Status-Hashtag kann auch
  unterwegs von Hand getippt werden
- **Finden** (⌘F): Suche, Dringlichkeit, Fälligkeit und wiederkehrende Aufgaben in einem
  Bedienelement; **Listen-Auswahl** und **WIP-Limits** in den Einstellungen
- **Motivation, dezent:** Streak-Zähler (🔥) mit Wochenübersicht

## Philosophie

Angelehnt an *Personal Kanban* (Jim Benson & Tonianne DeMaria Barry): Arbeit sichtbar
machen, ohne den bestehenden Workflow zu stören. Optisch orientiert an der
Minimal-Desk-Setup-Ästhetik — ein ruhiges, dauerhaft geöffnetes Board statt auffälliger
Software.

Drei Dokumente, drei Fragen: **Warum** es so ist — [CONCEPT.md](CONCEPT.md). **Was** die
App heute tut — [SPEC.md](SPEC.md). Was bewusst **nicht** drin ist —
[BACKLOG.md](BACKLOG.md).

## Build

Voraussetzungen: macOS 26 (Tahoe)+, Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```sh
xcodegen generate
open GlassKanban.xcodeproj   # in Xcode: ⌘R
```

Tests:

```sh
xcodebuild -project GlassKanban.xcodeproj -scheme GlassKanban \
  -destination 'platform=macOS' test
```

## Hinweise

- Der Doppelklick-Deep-Link nutzt ein undokumentiertes URL-Schema der Erinnerungen-App
  (`x-apple-reminderkit://…/details`); falls Apple es ändert, öffnet sich ersatzweise
  die Erinnerungen-App selbst
- Reminders-Tags, Flags und Unteraufgaben sind über die öffentliche EventKit-API nicht
  zugänglich — daher die Hashtag-Lösung
