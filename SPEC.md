# Glass Kanban — Funktionsspezifikation

Diese Datei beschreibt, **was die App heute tut**. Sie wird mit der App
weiterentwickelt: Ändert sich Verhalten, ändert sich diese Datei mit.

- Warum es so ist (Herleitung, verworfene Alternativen): [CONCEPT.md](CONCEPT.md)
- Was bewusst *nicht* umgesetzt ist: [BACKLOG.md](BACKLOG.md)

> **Historie:** Diese Datei hieß bis Juli 2026 `MVP.md` und war die verbindliche
> Vorab-Spezifikation für die Erstumsetzung. Der MVP ist erreicht und die App inzwischen
> darüber hinausgewachsen — eine Datei, die einen abgeschlossenen Planungsstand festhält,
> während die App weiterläuft, wird zur Fehlerquelle statt zur Referenz. Sie beschreibt
> deshalb ab jetzt den Ist-Stand; der ursprüngliche MVP-Umfang steht in der Git-History.

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
- Bidirektionaler Sync über `EKEventStoreChangedNotification`, kein Polling; zusätzlich
  Refresh um Mitternacht und nach dem Aufwachen aus dem Ruhezustand, damit „Heute"/
  „Überfällig" auf einem tagelang offenen Fenster nicht veralten
- Wird der Erinnerungs-Zugriff nachträglich in den Systemeinstellungen erteilt, übernimmt
  die App das beim nächsten Aktivieren des Fensters — ohne Neustart
- Normales Fenster, kein Always-on-Top
- Login-Item (Start bei Anmeldung) + gespeicherte Fensterposition/-größe
- Native Toolbar (SwiftUI `.toolbar`/`NSToolbar`) statt selbstgebauter Titelleiste
- Volles natives App-Menü + Tastaturkürzel (siehe unten)
- Respektiert macOS-Bedienungshilfen: „Transparenz reduzieren", „Bewegung reduzieren",
  „Kontrast erhöhen"

## Datenmodell

### Spalten = Hashtag in den Notizen (kein Listenwechsel)

`EKReminder.calendar` ist ein einzelnes Objekt, keine Menge — eine Erinnerung kann nur in
einer Liste gleichzeitig sein. Deshalb: Status wird über einen Hashtag im Notizen-Text
abgebildet, nicht über die Listenzugehörigkeit. Die ursprüngliche Liste bleibt bei jedem
Spaltenwechsel unverändert.

| Spalte (technisch) | Anzeige (Deutsch) | Hashtag in den Notizen |
|---|---|---|
| Backlog | Backlog | kein Tag (Standard/Fallback) |
| Next | Als Nächstes | `#alsnächstes` |
| In Progress | In Bearbeitung | `#inbearbeitung` |
| Done | Erledigt | — (`isCompleted = true`, kein Tag) |

**Schreiben (bei Drag & Drop bzw. „Verschieben nach"):**

| Ziel-Spalte | Aktion in den Notizen |
|---|---|
| Backlog | vorhandene Status-Zeile entfernen |
| Als Nächstes | Status-Zeile entfernen, `#alsnächstes` als neue, eigene letzte Zeile anhängen |
| In Bearbeitung | Status-Zeile entfernen, `#inbearbeitung` als neue, eigene letzte Zeile anhängen |
| Erledigt | `isCompleted = true` setzen, Status-Zeile entfernen |

**Lesen:** Der Hashtag wird an beliebiger Stelle im Notizen-Text gesucht, ohne Rücksicht auf
Groß-/Kleinschreibung und mit Wortgrenze (`#inbearbeitungszeit` zählt also nicht). Die
umlautfreie Schreibweise `#alsnaechstes` wird beim Lesen akzeptiert (unterwegs ohne Umlaute
getippt) und beim nächsten Schreiben normalisiert. Stehen mehrere Tags im Text, gewinnt der
**zuletzt** im Text stehende. Erinnerungen ohne erkannten Hashtag und ohne `isCompleted`
fallen automatisch in „Backlog".

**Nutzertext bleibt unangetastet:** Beim Schreiben werden ausschließlich Tags entfernt bzw.
angehängt. Zeilen ohne Tag werden zeichengenau durchgereicht — auch Leerzeilen, die als
Absatztrenner gesetzt wurden. Nur die Zeile, auf der ein Tag stand, verschwindet mit ihm;
nachlaufender Leerraum wird bereinigt, wenn die App am Textende ohnehin arbeitet.

**Datenhygiene beim Sync** — die App schreibt eine Erinnerung nur dann um, wenn eines davon
zutrifft:

1. `isCompleted = true`, aber es steht noch ein Status-Hashtag in den Notizen (z. B. direkt
   in Reminders abgehakt)
2. mehrere Status-Hashtags gleichzeitig vorhanden (z. B. am iPhone von Hand ergänzt)
3. ein Hashtag in einer alten Schreibweise früherer Builds (`#next`, `#progress`,
   `#nächstes`, `#bearbeitung`) — wird auf die aktuelle Form migriert

Der Vorgang ist konvergent: Nach einem Umschreiben existiert genau ein Tag der aktuellen
Form (oder keiner), es entsteht also keine Schreibschleife über die
Änderungs-Benachrichtigung.

### Listen-Filter

In den Einstellungen wird gewählt, welche vorhandenen Listen als Quelle einbezogen werden
(z. B. Einkaufsliste ausschließen). Flache Liste aller Listen, keine Gruppierung nach Konto.
Erinnerungen aus gewählten Listen werden gepoolt angezeigt; die Liste selbst wird nie von
der App gewechselt.

## Interaktion

Die App schreibt: den Status-Hashtag (Spaltenwechsel), die Editor-Felder (Titel, Notizen,
URL, Liste, Priorität, Fälligkeit), neue Tickets und Löschungen. Nicht bearbeitbar in der
App bleiben nur die Felder, die EventKit nicht öffentlich anbietet (Tags, Flags,
Unteraufgaben, Personen) sowie Wiederholungsregeln — dafür gibt es den Sprung nach
Reminders.

| Geste | Wirkung |
|---|---|
| **Drag & Drop** zwischen Spalten | Spaltenwechsel (siehe Datenmodell) |
| **Einfacher Klick** auf eine Karte | öffnet den **Karten-Editor** direkt auf dem Board |
| **Rechtsklick** | Kontextmenü: Bearbeiten, In Erinnerungen öffnen, Verschieben nach, Umbenennen, Löschen |
| **„+" im Backlog** | Neues Ticket anlegen und sofort im Karten-Editor öffnen |

### Karten-Editor (`TicketEditSheet`)

Der Klick öffnet die Karte vergrößert und zentriert über dem abgeblendeten Board — dieselbe
Karte, näher herangeholt, kein separates Formularfenster. Editierbar: **Titel, Notizen
(mehrzeilig, Absätze bleiben erhalten), URL-Feld, Liste, Dringlichkeit, Fälligkeit** (mit
oder ohne Uhrzeit — ohne bleibt die Erinnerung ganztägig). Änderungen werden beim Verlassen
eines Feldes direkt gespeichert; Escape oder ein Klick aufs Board schließt die Karte. Der
↗-Knopf springt zur Aufgabe in der Reminders-App, für alles, was der Editor bewusst
auslässt. Der Status-Hashtag ist im Notizen-Feld nie sichtbar und wird beim Speichern für
die aktuelle Spalte wieder angehängt — ein Inhalts-Edit kann eine Karte nie verschieben.
Ein Listenwechsel bietet nur beschreibbare, nicht ausgeblendete Listen an.

**Karten tragen keinen Tastaturfokus und keine Hover-Tooltips** — beides war kurz
implementiert und wurde als bewusste Entscheidung wieder entfernt (Begründung in
BACKLOG.md, Abschnitt „Explizit abgelehnt"). Karten werden mit der Maus bewegt; ein
Fokusrahmen betont Karten ohne Not, ein Hover-Text ist Dauerrauschen. VoiceOver ist davon
unberührt: Karten behalten Labels, Hints und alle Aktionen.

**Umbenennen** (Kontextmenü, für die schnelle Ein-Zeilen-Korrektur ohne Editor) startet
immer beim *gespeicherten* Titel, nicht bei dem, was die Karte anzeigt (die Karte blendet
URLs aus, siehe unten). Ein unverändert gelassenes oder leer gemachtes Feld schreibt
nichts. Escape verwirft, Return und ein Klick daneben übernehmen.

**Ticket anlegen = Karten-Editor.** Das „+" im Backlog legt das Ticket an (Standardliste
bzw. erste eingeschlossene Liste) und öffnet sofort den Karten-Editor mit dem Cursor im
Titel — Name, Notizen, Datum und alles Weitere entstehen an einem Ort, ohne zweiten
Schritt. Wird der Editor ohne jede Eingabe geschlossen, entfernt die App das Ticket
rückstandslos wieder; der ↗-Sprung nach Reminders zählt dabei als Behalten.

**Löschen fragt nicht nach, sondern lässt sich rückgängig machen.** Jede Schreib-Aktion der
App — Verschieben, Umbenennen, Anlegen, Löschen — registriert ihr Gegenteil beim
Undo-Manager des Fensters und ist mit **⌘Z** widerrufbar, ⇧⌘Z stellt sie wieder her. Beim
Wiederherstellen einer gelöschten Aufgabe legt die App eine neue Erinnerung mit demselben
Inhalt an (Titel, Notizen, URL, Ort, Priorität, Datum, Wiederholung, Erinnerungen,
Erledigt-Status samt ursprünglichem Erledigt-Datum) — EventKit kennt kein echtes
Wiederherstellen, die Erinnerung bekommt also eine neue interne ID.

### Tastaturkürzel

| Kürzel | Wirkung |
|---|---|
| ⌘F | Finden-Popover (Suche + Filter) |
| ⇧⌘F | Filter zurücksetzen |
| ⌘N | Erinnerungen-App öffnen |
| ⌘R | Board aktualisieren |
| ⌘Z / ⇧⌘Z | letzte Board-Änderung rückgängig / wiederherstellen |
| ⌘, | Einstellungen |

## Karten-Anzeige

Die Kartendichte richtet sich nach der Spalte — das ist der Fokus-Mechanismus des Boards:

| Spalte | Karte zeigt |
|---|---|
| Als Nächstes, In Bearbeitung | Titel, Prioritätsmarken, Notizen-Auszug (bis 3 Zeilen), Fälligkeits-Badge, Wiederholungs-Icon, Listenname, Verweildauer |
| Backlog | eine Zeile: Prioritätsmarken, Titel, Wiederholungs-Icon, Fälligkeits-Badge |
| Erledigt | nur der Titel, durchgestrichen |

- **Listenfarbe als Akzent:** `EKCalendar.color` als schmaler Streifen an der linken
  Kartenkante
- **Verweildauer:** ab 3 Tagen in derselben Spalte zeigt die Karte „N Tage" (approximiert
  über `lastModifiedDate`)
- **Links werden auf der Karte immer ausgeblendet:** URL-artige Textteile werden vor der
  Anzeige aus Titel und Notizen entfernt. Das betrifft **nur die Karten-Darstellung** — in
  EventKit wird nichts zurückgeschrieben, auch nicht beim Umbenennen, und der Editor zeigt
  Notizen und URL-Feld ungefiltert
- **Status-Hashtag** wird aus der Notizen-Anzeige immer herausgefiltert
- **Backlog klappt ab 15 Karten ein** („N weitere anzeigen")
- **Keine Tooltips auf Karten** (siehe Interaktion) — Tooltips gibt es nur am Chrome:
  Spaltenkopf (Zähler/Regeln) und „+"-Button

**Sortierung** in den offenen Spalten: Dringlichkeit (überfällig/heute zuerst) → Priorität →
frühestes Fälligkeitsdatum (Karten ohne Datum zuletzt) → Titel. Der Titel als letztes
Kriterium sorgt dafür, dass die Reihenfolge zwischen zwei Refreshes nicht springt.
„Erledigt" sortiert nach Erledigt-Datum, neueste zuerst.

**Erledigt zeigt die letzten 14 Tage.** Lang genug, dass die Arbeit einer Woche als Nachweis
stehen bleibt, kurz genug, dass die Spalte kein Archiv wird.

## Finden (Suche + Filter)

Ein einziges Bedienelement in der Toolbar (Lupe, ⌘F) enthält alles zum Finden:

| Element | Datenquelle |
|---|---|
| Suche | Titel + angezeigte Notizen, ohne Groß-/Kleinschreibung und Diakritika, Wortreihenfolge egal |
| Dringlichkeit | `EKReminder.priority` (Hoch/Mittel/Niedrig/Keine) |
| Fälligkeit | `EKReminder.dueDateComponents` (Überfällig/Heute/Diese Woche/Ohne Datum) |
| Wiederkehrende | `EKReminder.hasRecurrenceRules` (Wenn fällig/Immer) |

Ist gefiltert, trägt das eingeklappte Lupensymbol die Anzahl aktiver Einschränkungen und die
Akzentfarbe — ein Board darf nie gefiltert sein, ohne das zu zeigen.

**Wiederkehrende Aufgaben im Backlog:** Standard ist „Wenn fällig" — die Karte erscheint
erst, wenn sie heute fällig oder überfällig ist. Betrifft **nur Backlog**; ohne
Fälligkeitsdatum bleibt sie immer sichtbar. Der Standardwert zählt nicht als aktive
Filterung (sonst leuchtete das Finden-Symbol dauerhaft). Was er ausblendet, meldet der
Spalten-Tooltip („N wiederkehrende Karten").

**Leeres Board:** Zeigt das Board gar nichts, sagt es warum — „Board leer, Kopf frei"
(nichts da), „Kein Treffer, nichts verloren" (Filter, mit Zurücksetzen-Link) oder „Nichts
fällig, Wiederkehrendes wartet" (nur noch nicht fällige Wiederholungen, mit Link zum
Einblenden).

## WIP-Limits

- Konfigurierbar in den Einstellungen für „Als Nächstes" (Standard 5) und „In Bearbeitung"
  (Standard 3); 0 = kein Limit
- Das Limit läuft im Spaltenzähler mit (`1 / 3`), die Kapsel färbt sich beim Überschreiten
  teal
- **Nur „In Bearbeitung" fragt nach:** Wird das Limit dort überschritten, erscheint *nach*
  dem Ablegen ein Dialog („Weniger gleichzeitig, mehr fertig. Erst etwas abschließen?").
  Das Board blockt nichts — es lässt die Karte landen und bietet an, sie zurückzulegen. Die
  Frage stellt sich bei jeder Route (Drag & Drop, Kontextmenü, VoiceOver)
- Herleitung (Selbstverpflichtungs-Psychologie, „Reibung statt Verbot"): siehe CONCEPT.md,
  Abschnitt Motivation

## Motivation

- **Streak-Zähler in der Toolbar:** Flamme plus Zahl, rein lesend aus `completionDate`
  berechnet (Blickfenster: 400 Tage). Die Flamme füllt sich mit dem Tagesfortschritt.
  Sichtbar, sobald es überhaupt erledigte Aufgaben gibt; bei Serie 0 zeigt sie **nur die
  graue Flamme ohne Zahl** — eine „0" neben den Fensterknöpfen sieht kaputt aus und liest
  sich als Rüge, aber der Zugang zur Statistik darf nach einem Serienriss nicht verschwinden
  (siehe BACKLOG.md)
- **Statistik-Fenster** (Klick auf die Flamme, `StatsPopover`): zwei Ansichten über
  Textumschalter, damit ein Blick nie zur Navigation wird —
  - **Jetzt:** Folge als Schlagzeile, heute erledigte Aufgaben, aktuelle Auslastung gegen
    das WIP-Limit, Durchlaufzeit-Schätzung nach Little's Law (Bestand ÷ Tempo, bewusst als
    Schätzung beschriftet), 30-Tage-Verlauf als Balken
  - **Rückblick:** dieses Jahr, längste Folge, bester Tag, stärkster Wochentag, häufigste
    Liste, Meilenstein bei einer runden Zahl innerhalb der letzten 7 Tage
  - Alles aus den Erinnerungen abgeleitet, die die App ohnehin lädt — keine zweite
    EventKit-Abfrage, keine eigene Speicherung. Der Meilenstein ist die eine bewusste
    Lockerung der „keine Badges"-Regel: nur ein Moment, nie dauerhaft (siehe CONCEPT.md)
- **Kein täglich wechselnder Motivationssatz** — war im ursprünglichen MVP vorgesehen und
  hat sich als unpraktikabel erwiesen (siehe BACKLOG.md)
- Ausdrücklich **keine** Punkte/Levels/Badges/Bestenlisten

## Design

- Liquid Glass auf der Chrome-Ebene (Fensterrücken, Toolbar, Popover); Spalten sind
  eingelassene Mulden, Karten deckendes Papier — siehe CONCEPT.md, Abschnitt Design-Anspruch
- **Spalten füllen immer die volle Fensterhöhe** — bewusste Entscheidung, siehe BACKLOG.md
  („Explizit abgelehnt": Spalten enden mit dem Inhalt). Weniger Leerfläche = Fenster kleiner
  ziehen
- **Ein Titelmaß für alle Karten: 15pt** — Arbeitsspalten semibold, Backlog und Erledigt
  medium. Beim Verschieben ändert sich die Titelgröße dadurch nie; was sich ändert, ist der
  Detailgrad der Karte. Die 15 statt der früheren 14 für Lesbarkeit auf Distanz; der Rest
  der Skala bleibt unverändert (Spaltenkopf 13pt, sichtbar kleiner als beide Titel)
- Typografie/Abstände nach Apple HIG (SF Pro), Tokens in `DesignSystem.swift`
- Bewegung wird für Dinge ausgegeben, die *gerade passiert sind* (Karte rastet in „Erledigt"
  ein), nie für stehende Einladungen
- Erscheinungsbild: Nach System / Hell / Dunkel, in den Einstellungen wählbar
- Eigene Hover-Tooltips statt `.help(...)`, mit eigenen VoiceOver-Labels/Hints — nur am
  Chrome (Spaltenkopf, „+"-Button), nie auf Karten
- **Vibe-Referenz:** „Minimal Desk Setup" — die App als ruhiges, fast gegenständliches
  Objekt auf dem Screen statt auffällige Software

## Bekannte Einschränkungen (Apple-Plattform-Grenzen, kein Designfehler)

- Reminders-Tags, Flags und Unteraufgaben sind nicht über die öffentliche EventKit-API
  zugänglich — daher die Hashtag-in-Notizen-Lösung statt echter Tags
- Status ist in der nativen Reminders-Listenansicht nicht auf den ersten Blick sichtbar,
  erst beim Öffnen der Notizen
- Der Deep-Link zum Bearbeiten-Popover nutzt ein undokumentiertes URL-Schema; fällt es weg,
  öffnet sich ersatzweise die Reminders-App selbst
- Ausgeschlossene Listen werden über `calendarIdentifier` gemerkt. Wird ein Konto entfernt
  und neu hinzugefügt, kann eine Liste mit neuer ID zurückkommen und wieder auf dem Board
  auftauchen — Gegenmittel ist ein Schalter in den Einstellungen
- Ein gelöschtes und per ⌘Z wiederhergestelltes Ticket ist technisch eine neue Erinnerung
  mit neuer interner ID
