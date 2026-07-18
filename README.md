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
- **Drag & Drop** zwischen den Spalten ist die einzige Schreib-Interaktion; Aufgaben
  werden ausschließlich in der nativen Erinnerungen-App angelegt und bearbeitet
- **Doppelklick auf eine Karte** öffnet die Aufgabe direkt im Bearbeitungs-Popover
  der Erinnerungen-App
- **Bidirektionaler Live-Sync**: Änderungen in der Erinnerungen-App (auch auf
  iPhone/iPad via iCloud) erscheinen sofort im Board — der Status-Hashtag kann auch
  unterwegs von Hand getippt werden
- **Filter** nach Dringlichkeit und Fälligkeit, **Listen-Auswahl** in den Einstellungen
  (z. B. Einkaufsliste ausblenden)
- **Motivation, dezent:** Streak-Zähler (🔥) und ein täglich wechselnder Satz

## Philosophie

Angelehnt an *Personal Kanban* (Jim Benson & Tonianne DeMaria Barry): Arbeit sichtbar
machen, ohne den bestehenden Workflow zu stören. Optisch orientiert an der
Minimal-Desk-Setup-Ästhetik — ein ruhiges, dauerhaft geöffnetes Board statt auffälliger
Software. Details: [CONCEPT.md](CONCEPT.md), verbindlicher Funktionsumfang:
[MVP.md](MVP.md), bewusst Verschobenes: [BACKLOG.md](BACKLOG.md).

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
