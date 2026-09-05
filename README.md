# Glass Kanban

Ein natives macOS-Kanban-Board für Apple Erinnerungen (Reminders) im Liquid-Glass-Design.

Deine Aufgaben leben in Erinnerungen — Glass Kanban liest und schreibt sie über EventKit
und legt nichts davon woanders ab. Nur die Spalte gehört dem Board selbst und liegt in
einer eigenen Datei auf diesem Mac (seit 13.08.2026, siehe „Funktionsweise"). Kein Server,
kein Konto, keine Cloud-Komponente, keine Zugangsdaten: Die einzige Berechtigung ist der macOS-Systemdialog für den
Erinnerungs-Zugriff. Deutsch und Englisch, folgt der Systemsprache.

## Funktionsweise

- **Vier Spalten:** Backlog → Als Nächstes → In Bearbeitung → Erledigt
- **Die Spalte gehört dem Board** — sie steht in einer eigenen Datei der App, nicht in
  der Erinnerung. Damit kann kein anderes Programm eine Karte verschieben. Erledigt
  bleibt `isCompleted` in Reminders, die Listenzugehörigkeit bleibt unangetastet.
  (Bis 13.08.2026 stand die Spalte als Hashtag in den Notizen; vorhandene Tags werden
  beim ersten Start einmalig übernommen und danach aus den Notizen entfernt.)
- **Drag & Drop** zwischen den Spalten; **Klick** auf eine Karte öffnet den Karten-Editor
  direkt auf dem Board (Titel, Notizen, URL, Liste, Dringlichkeit, Fälligkeit)
- **Tickets anlegen** über das „+" im Backlog — Titel tippen, Return, fertig
- **Alles widerrufbar:** Verschieben, Bearbeiten, Umbenennen, Anlegen und Löschen lassen
  sich mit ⌘Z rückgängig machen; Löschen fragt zusätzlich nach, weil EventKit
  Unteraufgaben und Anhänge nicht wiederherstellen kann
- **Bidirektionaler Live-Sync**: Änderungen in der Erinnerungen-App (auch auf
  iPhone/iPad via iCloud) erscheinen sofort im Board — Titel, Notizen, Fälligkeit und
  Erledigt-Status. Die Spalte selbst wird am Mac gezogen, an dem das Board läuft
- **Finden** (⌘F): Suche, Dringlichkeit, Fälligkeit und wiederkehrende Aufgaben in einem
  Bedienelement; **Listen-Auswahl** und **WIP-Limits** in den Einstellungen
- **Motivation, dezent:** Streak-Flamme (🔥) mit Statistik-Fenster („Jetzt" und
  „Rückblick" — Auslastung, Durchlaufzeit-Schätzung, bester Tag, häufigste Liste)
- **Das Board bleibt auf seinem Bildschirm:** Wird der Monitor abgezogen, auf dem es
  steht, und später wieder angesteckt, kehrt das Fenster dorthin zurück — statt auf dem
  eingebauten Display liegenzubleiben

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

**Immer aktuelle App zum Doppelklick:** `Glass Kanban.app` im Projektordner wird von
`scripts/build-app.sh` automatisch aktuell gehalten — kein manueller Build nötig, um die
App im Finder zu öffnen. Details siehe [CLAUDE.md](CLAUDE.md).

## Ordner

So wenig wie möglich, so viel wie nötig — jeder Eintrag im Stamm hat genau eine Aufgabe:

```
GlassKanban/            Quellen, flach; darin Tests/ (Unit-Tests) und AppIcon.icon/
GlassKanban.xcodeproj/  von XcodeGen erzeugt, nicht in Git
plans/                  Baupläne für entschiedene, noch nicht gebaute Vorhaben
scripts/                Build, Doku-Wächter, Lokalisierungsprüfung
social/                 Material für Beiträge (LinkedIn: Ablauf-README, Konzept, Skripte, fertiges Video)
project.yml             Projektbeschreibung für XcodeGen — die Quelle des .xcodeproj
README / SPEC / CONCEPT / BACKLOG / RELEASE / CLAUDE .md
Glass Kanban.app        der jeweils aktuelle Build, nicht in Git
```

## Dokumentation

| Datei | Inhalt |
|---|---|
| [SPEC.md](SPEC.md) | Was die App heute tut (lebende Spezifikation) |
| [CONCEPT.md](CONCEPT.md) | Warum sie so ist (Herleitung, verworfene Alternativen) |
| [BACKLOG.md](BACKLOG.md) | Was bewusst (noch) nicht umgesetzt ist |
| [RELEASE.md](RELEASE.md) | Fahrplan und Arbeitsstand zum Mac-App-Store-Release |
| [CLAUDE.md](CLAUDE.md) | Kompass für die Arbeit am Projekt: die drei Design-Prinzipien, Dokument- und Code-Landkarte |

## Hinweise

- „In Erinnerungen öffnen" (Kontextmenü und ↗ im Karten-Editor) springt über ein
  undokumentiertes URL-Schema der Erinnerungen-App direkt zur Aufgabe
  (`x-apple-reminderkit://…/details`); lässt es sich nicht auflösen — etwa bei rein
  lokalen Listen —, öffnet sich ersatzweise die Erinnerungen-App selbst. Für die
  1.0-Einreichung wird der Deep-Link entfernt (siehe [RELEASE.md](RELEASE.md), Phase 2)
- Reminders-Tags, Flags und Unteraufgaben sind über die öffentliche EventKit-API nicht
  zugänglich
- Die Spalte ist in Reminders nicht sichtbar und gilt je Mac — der Preis dafür, dass kein
  anderes Programm sie ändern kann
