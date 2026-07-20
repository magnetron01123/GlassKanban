# Glass Kanban — MVP-Spezifikation

Diese Datei ist die verbindliche, umsetzungsfertige Grundlage für die Implementierung
(Claude Code). Herleitung und Begründungen stehen in [CONCEPT.md](CONCEPT.md), abgelehnte/
verschobene Ideen in [BACKLOG.md](BACKLOG.md).

## App

- **Name:** Glass Kanban
- **Plattform:** natives SwiftUI, macOS 26 (Tahoe)+
- **Grundprinzipien:** Personal-Kanban-Philosophie (Arbeit sichtbar machen, Workflow nicht
  stören) + komplett lokal (keine Cloud-Komponente, kein Server, kein Konto, keine
  Zugangsdaten in der App — einzige Berechtigung ist der macOS-Systemdialog für
  Erinnerungs-Zugriff)

## Architektur

- Datenzugriff ausschließlich über EventKit (`EKEventStore`/`EKReminder`), kein eigener
  Datenspeicher
- Bidirektionaler Sync über `EKEventStoreChangedNotification`, kein Polling
- Normales Fenster, kein Always-on-Top
- Login-Item (Start bei Anmeldung) + gespeicherte Fensterposition/-größe
- Native Toolbar (SwiftUI `.toolbar`/`NSToolbar`) statt selbstgebauter Titelleiste
- Volles natives App-Menü + Tastaturkürzel (z. B. ⌘F für Filter-Fokus, Pfeiltasten zur
  Kartennavigation)
- Respektiert macOS-Bedienungshilfen: "Transparenz reduzieren" und "Bewegung reduzieren"

## Datenmodell

### Spalten = Hashtag in den Notizen (kein Listenwechsel)

`EKReminder.calendar` ist ein einzelnes Objekt, keine Menge — eine Erinnerung kann nur in
einer Liste gleichzeitig sein. Deshalb: Status wird über einen Hashtag im Notizen-Text
abgebildet, nicht über die Listenzugehörigkeit. Ursprüngliche Liste bleibt bei jedem
Spaltenwechsel unverändert.

| Spalte (technisch) | Anzeige (Deutsch) | Hashtag in den Notizen |
|---|---|---|
| Backlog | Backlog | kein Tag (Standard/Fallback) |
| Next | Als Nächstes | `#alsnächstes` |
| In Progress | In Bearbeitung | `#inbearbeitung` |
| Done | Erledigt | — (`isCompleted = true`, kein Tag) |

**Schreiben (bei Drag & Drop):**

| Ziel-Spalte | Aktion in den Notizen |
|---|---|
| Backlog | vorhandene Status-Zeile entfernen |
| Als Nächstes | Status-Zeile entfernen, `#alsnächstes` als neue, eigene letzte Zeile anhängen |
| In Bearbeitung | Status-Zeile entfernen, `#inbearbeitung` als neue, eigene letzte Zeile anhängen |
| Erledigt | `isCompleted = true` setzen, Status-Zeile entfernen |

**Lesen:** Hashtag wird an beliebiger Stelle im Notizen-Text gesucht (nicht nur letzte Zeile).
Erinnerungen ohne erkannten Hashtag und ohne `isCompleted` fallen automatisch in "Backlog".

**Datenhygiene:** Ist eine Erinnerung `isCompleted = true`, aber es steht noch ein alter
Status-Hashtag in den Notizen (z. B. direkt in Reminders abgehakt), entfernt die App die
Status-Zeile automatisch beim nächsten Sync.

### Listen-Filter

Nutzer wählt in den Einstellungen, welche vorhandenen Listen als Quelle einbezogen werden
(z. B. Einkaufsliste ausschließen). Flache Liste aller Listen zur Auswahl, keine Gruppierung
nach Konto. Erinnerungen aus gewählten Listen werden gepoolt im Board angezeigt; die Liste
selbst wird nie von der App gewechselt.

## Interaktion

**Read-only außer Drag & Drop.** Anlegen und inhaltliches Bearbeiten von Aufgaben (Titel,
Notizen, Fälligkeit, Priorität) passiert ausschließlich in der nativen Reminders-App.

Einzige Schreib-Interaktion: Drag & Drop einer Karte zwischen den vier Spalten (siehe
Datenmodell oben).

**Doppelklick auf eine Karte** öffnet die Aufgabe direkt im Bearbeitungs-Popover der
Reminders-App (Deep Link `x-apple-reminderkit://REMCDReminder/<interne UUID>/details`;
die interne UUID wird über `calendarItemExternalIdentifier` bzw. als Fallback über das
private Backing-Objekt aufgelöst — undokumentiertes Schema, bei Wegfall öffnet sich
ersatzweise die Reminders-App selbst). Damit bleibt das Bearbeiten vollständig in
Reminders, ist aber nur einen Doppelklick entfernt. Zusätzlich per Kontextmenü
("In Erinnerungen öffnen") erreichbar.

## Karten-Anzeige (MVP: minimal)

Jede Karte zeigt:

- Titel
- Notizen-Vorschau (gekürzt, siehe unten)
- Fälligkeitsdatum

Bewusst **nicht** auf der Karte (siehe BACKLOG.md): Prioritäts-Icon, Personen-Avatar.
Sortierung innerhalb einer Spalte nach Fälligkeitsdatum.

**Links werden immer ausgeblendet:** Bevor Titel oder Notizen angezeigt werden, entfernt die
App alle URL-artigen Textteile aus der Anzeige (z. B. per Regex-Erkennung). Das betrifft nur
die Darstellung — der eigentliche Reminders-Eintrag bleibt unverändert, es wird nichts in
EventKit zurückgeschrieben. Der Status-Hashtag (`#alsnächstes`/`#inbearbeitung`) wird aus der
Notizen-Vorschau ebenfalls immer herausgefiltert, da er ein internes Steuerzeichen ist, kein
echter Notizinhalt.

**Notizen-Vorschau auf sinnvolle Länge kürzen:** eine Zeile, mit "…" abgeschnitten, sobald die
verbleibende (linkbereinigte) Notiz länger ist. Bleibt die Notiz nach dem Entfernen von Links/
Hashtag leer, bleibt die Zeile einfach leer (reservierter Platz bleibt trotzdem bestehen).

**Einheitliche Kartenhöhe:** Titel ist auf zwei Zeilen begrenzt, Notizen-Vorschau auf eine
Zeile — beides mit fest reserviertem Platz, unabhängig vom tatsächlichen Inhalt (auch bei
kurzem Titel/leerer Notiz bleibt der Platz gleich groß). Dadurch sind alle Karten unabhängig
vom Inhalt exakt gleich hoch.

**Listenfarbe als Akzent:** `EKCalendar.color` (Farbe der Ursprungsliste in Reminders) wird
als kleiner Farbpunkt/-akzent auf der Karte angezeigt.

## Filter (Filterleiste)

| Filter | Datenquelle |
|---|---|
| Dringlichkeit | `EKReminder.priority` (gruppiert: Hoch/Mittel/Niedrig/Keine) |
| Fälligkeit | `EKReminder.dueDateComponents` (Überfällig/Heute/Diese Woche/Ohne Datum) |
| Wiederkehrende | `EKReminder.hasRecurrenceRules` (Verborgen bis fällig/Immer anzeigen) |

(Verantwortliche-Person-Filter → Backlog, siehe BACKLOG.md)

**Wiederkehrende Aufgaben im Backlog:** Eine wiederkehrende Erinnerung hat immer schon ein
*nächstes* Fälligkeitsdatum — eine monatliche Routine stünde sonst jeden Tag des Monats im
Backlog, obwohl sie gerade keine Entscheidung ist. Standard ist deshalb **"Verborgen bis
fällig"**: die Karte erscheint erst, wenn sie dasselbe Fälligkeitsfenster erreicht, das der
Fälligkeits-Filter Überfällig/Heute/Diese Woche nennt (Kalenderwoche, d. h. Montagfrüh kommen
die Routinen der Woche gemeinsam an). Betrifft **nur Backlog** — eine wiederkehrende Karte, die
bereits in einer Arbeitsspalte liegt, ist eine getroffene Entscheidung, eine erledigte ist ein
Nachweis. Ohne Fälligkeitsdatum bleibt sie immer sichtbar, sonst verschwände sie dauerhaft.

Anders als die beiden anderen Filter ruht dieser also nicht auf "alles zeigen". Er bleibt
trotzdem eine sichtbare Zeile statt einer stillen Regel — dasselbe Prinzip, nach dem das
WIP-Limit in der Spaltenzahl mitläuft: Das Board soll sagen können, was es nicht zeigt. Der
Standardwert zählt aber nicht als aktive Filterung (sonst leuchtete das Finden-Symbol dauerhaft);
nur "Immer anzeigen" ist eine bewusste Abweichung und bringt den Zurücksetzen-Link.

## Motivation (leichtgewichtige Gamification)

- **Streak-Zähler:** z. B. „🔥 5 Tage in Folge" im Fensterrahmen, rein lesend aus
  `completionDate` aller erledigten Erinnerungen berechnet (an wie vielen aufeinanderfolgenden
  Tagen wurde mindestens eine Karte erledigt)
- **Täglich wechselnder, motivierender Satz:** lokale, statische Liste (~20 Sätze), Auswahl
  nach Kalendertag, dezent unter dem Board angezeigt

Ausdrücklich **keine** Punkte/Levels/Badges/Bestenlisten.

## Design

- Liquid Glass auf der Chrome-Ebene (Fensterrücken, Toolbar, Popover); Spalten sind
  eingelassene Mulden, Karten deckendes Papier — siehe CONCEPT.md, Abschnitt Design-Anspruch
- Typografie/Abstände nach Apple HIG (SF Pro)
- Dezente Animationen bei Spaltenwechsel und Live-Updates
- Automatisches Light/Dark Mode + System-Akzentfarbe
- **Vibe-Referenz:** "Minimal Desk Setup"-Szene — reduzierte Flächen, ruhige/neutrale
  Farbgebung, wenige bewusst platzierte Elemente, kein visuelles Rauschen. Die App als
  ruhiges, fast gegenständliches Objekt auf dem Screen statt auffällige Software.

## Bekannte Einschränkungen (Apple-Plattform-Grenzen, kein Designfehler)

- Reminders-Tags, Flags und Unteraufgaben sind nicht über die öffentliche EventKit-API
  zugänglich — daher die Hashtag-in-Notizen-Lösung statt echter Tags
- Status ist in der nativen Reminders-Listenansicht nicht auf den ersten Blick sichtbar,
  erst beim Öffnen der Notizen
