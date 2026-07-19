# Glass Kanban für macOS-Erinnerungen — Konzept & Begründung

> **Hinweis:** Der verbindliche, umsetzungsfertige Funktionsumfang steht in [MVP.md](MVP.md),
> verschobene/abgelehnte Ideen in [BACKLOG.md](BACKLOG.md). Dieses Dokument liefert die
> Herleitung und Begründung der Entscheidungen — bei Widersprüchen gilt MVP.md.

App-Name: **Glass Kanban** — der Name benennt direkt die beiden Kerneigenschaften der App:
das Liquid-Glass-Design und das Kanban-Prinzip. Inhaltlich bleibt das Buch *Personal Kanban:
Mapping Work | Navigating Life* von Jim Benson & Tonianne DeMaria Barry die philosophische
Grundlage: Arbeit sichtbar machen, ohne den bestehenden Workflow (hier: die normale Nutzung
von Erinnerungen) zu stören.

**Zweites Grundprinzip: komplett lokal, keine Zugangsdaten in der App.** Die App hat keine
eigene Cloud-Komponente, keinen Server, kein Konto, keine Analyse, keine Netzwerkaufrufe. Sie
funktioniert vollständig offline als reiner lokaler EventKit-Client — Datenhoheit bleibt zu
100 % bei dir. Konkret bedeutet das: Es gibt in der App **kein Eingabefeld für Apple-ID,
Passwort oder sonstige Zugangsdaten** — das ist bei EventKit technisch gar nicht vorgesehen.
Der einzige Berechtigungsschritt ist der macOS-Standarddialog "Zugriff auf Erinnerungen
erlauben?" beim ersten Start. Ob im Hintergrund iCloud, Exchange oder nur lokale Listen
verwendet werden, regelt ausschließlich macOS selbst (Systemeinstellungen) — die App bekommt
nach der Erlaubnis nur Lesezugriff auf die vorhandenen Daten, niemals Zugangsdaten. Optionale
Funktionen, die von sich aus iCloud voraussetzen würden (z. B. mit anderen Personen geteilte
Listen), werden nur dann aktiv, wenn *du* dich aktiv dafür entscheidest — sie sind nie
Voraussetzung für die Kernfunktion der App.

## Grundidee

Eine native macOS-App, die eine Kanban-Ansicht über macOS-Erinnerungen (Reminders) legt.
Alle Daten leben ausschließlich in Erinnerungen — die App speichert selbst nichts, sie ist
reine Visualisierung/Steuerung über EventKit. Änderungen sind in beide Richtungen sofort
sichtbar: in Glass Kanban und in der nativen Reminders-App.

## Architektur

- **Native SwiftUI-App**, kein Cross-Platform-Framework — zwingend, weil der Zugriff auf
  Erinnerungen nur über EventKit (`EKEventStore`/`EKReminder`) möglich ist, und das ist
  ausschließlich aus Swift/Objective-C erreichbar.
- **Zielplattform: macOS 26 (Tahoe)+** — nutzt das systemweite Liquid-Glass-Material direkt,
  keine Rückwärtskompatibilität zu älteren macOS-Versionen nötig.
- **Fenstertyp:** normales Fenster, kein Always-on-Top. Der Nutzer lässt es selbst dauerhaft
  geöffnet (z. B. auf einem zweiten Bildschirm).
- **Sync:** bidirektional über `EKEventStoreChangedNotification` — kein Polling. Änderungen,
  die direkt in der nativen Reminders-App gemacht werden (z. B. Erinnerung abhaken), tauchen
  live im Kanban-Board auf.
- **Programmstart:** Login-Item (App startet automatisch beim Anmelden), merkt sich
  Fensterposition und -größe zwischen den Starts — passend zum Anspruch, dauerhaft geöffnet zu
  bleiben.
- **Keine eigene Cloud-Komponente:** kein Server, kein Backend, kein Konto, keine Analyse,
  keine Netzwerkaufrufe der App selbst — reiner lokaler EventKit-Client. Funktioniert auch mit
  rein lokalen ("Auf meinem Mac"-)Listen ohne iCloud. Einzige Ausnahme: Der
  Verantwortliche-Person-Filter benötigt zwingend eine über iCloud geteilte Liste, weil das
  Teilen von Listen bei Apple grundsätzlich an iCloud gekoppelt ist (keine Design-Entscheidung
  dieser App, sondern eine Systemgrenze von Reminders). Ohne geteilte Listen bleibt dieser
  Filter einfach leer/ausgeblendet, alles andere funktioniert unverändert.

## Datenmodell

### Spalten = Hashtag in den Notizen (kein Listenwechsel)

Wichtiger technischer Fakt, der die Lösung bestimmt: `EKReminder.calendar` ist ein
**einzelnes Objekt, keine Menge** — eine Erinnerung kann immer nur in genau **einer** Liste
gleichzeitig sein. "Liste = Spalte" würde also bedeuten, dass eine Erinnerung beim Verschieben
durchs Board ihre ursprüngliche, inhaltliche Liste (z. B. "Projekt X") verlässt — ein echter
Eingriff in die normale Reminders-Nutzung. Das ist mit dem Ziel "möglichst wenig Einfluss auf
die normale Nutzung" nicht vereinbar und wird deshalb verworfen.

Stattdessen wird der Status als **Hashtag im Notizen-Text** der Erinnerung abgelegt. Das ist
das einzige Feld in EventKit, das (a) nicht überall sichtbar ist wie der Titel (kein Einfluss
auf Siri, Widgets, Benachrichtigungen, Spotlight) und (b) die Listenzugehörigkeit nicht
anfasst.

**Spalten (final):**

| Spalte (intern/technisch) | Anzeige (Deutsch) | Hashtag in den Notizen |
|---|---|---|
| Backlog | Backlog | kein Tag (Standard/Fallback) |
| Next | Als Nächstes | `#alsnächstes` |
| In Progress | In Bearbeitung | `#inbearbeitung` |
| Done | Erledigt | — (`isCompleted = true`, kein Tag) |

Backlog bekommt bewusst **keinen** eigenen Hashtag (kein `#backlog`), sondern bedeutet immer
"kein Status-Tag vorhanden". Zwei verschiedene Darstellungen für denselben Zustand (mit Tag
und ohne Tag) würden sonst auseinanderlaufen können.

**Schreiben (beim Verschieben per Drag & Drop in der App):**

| Ziel-Spalte | Aktion in den Notizen |
|---|---|
| Backlog | vorhandene Status-Zeile entfernen |
| Als Nächstes | Status-Zeile entfernen, `#alsnächstes` als neue, eigene letzte Zeile anhängen |
| In Bearbeitung | Status-Zeile entfernen, `#inbearbeitung` als neue, eigene letzte Zeile anhängen |
| Erledigt | `isCompleted = true` setzen, Status-Zeile entfernen |

Der restliche Notiztext bleibt bei jeder Aktion unverändert; der Hashtag wird von der App
immer strikt als letzte, eigene Zeile geschrieben.

**Lesen/Erkennen (beim Einlesen aus EventKit):**

- Die App sucht den Hashtag an **beliebiger Stelle** im Notizen-Text, nicht nur in der letzten
  Zeile — falls z. B. am iPhone manuell noch Text darunter ergänzt wird, wird der Tag trotzdem
  zuverlässig erkannt.
- Erinnerungen ohne erkannten Hashtag und ohne `isCompleted` fallen automatisch in "Backlog"
  (kein Pflicht-Tagging nötig, bereits vorhandene Erinnerungen tauchen sofort im Board auf).

**Weitere Eigenschaften:**

- **Bonus:** Der Hashtag lässt sich auch manuell direkt in der nativen Reminders-App auf
  iPhone/iPad/Mac eintippen — eine Karte kann so verschoben werden, ohne Glass Kanban zu öffnen.
- Ursprüngliche Listenzugehörigkeit bleibt bei jedem Spaltenwechsel zu 100 % unverändert.
- **Datenhygiene:** Erkennt die App eine erledigte Erinnerung (`isCompleted = true`), die noch
  einen alten Status-Hashtag in den Notizen hat (z. B. weil direkt in Reminders abgehakt statt
  per Drag & Drop verschoben), entfernt sie die Status-Zeile automatisch beim nächsten Sync.

**Kompromiss, den das kostet:** Der Status ist in der nativen Reminders-Listenansicht nicht
auf den ersten Blick sichtbar, sondern erst beim Öffnen der Erinnerung (Notizen aufklappen).

### Listen-Filter

In den Einstellungen wählt der Nutzer, welche der eigenen, bereits vorhandenen Listen
überhaupt als Quelle fürs Kanban-Board einbezogen werden — z. B. um die Einkaufsliste
komplett auszuschließen. Erinnerungen aus den gewählten Listen werden gepoolt im Board
angezeigt; die Liste selbst bleibt unverändert Eigentum/Organisation des Nutzers und wird
zu keinem Zeitpunkt von der App gewechselt.

Für den MVP genügt eine einfache, flache Liste aller vorhandenen Listen zur Auswahl — unabhängig
davon, aus welchem Konto (iCloud, Exchange, lokal) sie stammen. Gruppierung nach Konto wäre
höchstens eine spätere, rein kosmetische Verbesserung, keine funktionale Notwendigkeit.

## Filter (im Board)

| Filter | Datenquelle | Einschränkung |
|---|---|---|
| **Suche** | `EKReminder.title` + `notes` (Volltext, lokal) | keine |
| **Dringlichkeit** | `EKReminder.priority` (0–9, gruppiert: Hoch/Mittel/Niedrig/Keine) | keine |
| **Fälligkeit** | `EKReminder.dueDateComponents` (z. B. Überfällig/Heute/Diese Woche/Ohne Datum) | keine |
| **Verantwortliche Person** | `EKCalendarItem.attendees` (`EKParticipant`) | **nur lesend.** Funktioniert nur bei über iCloud **geteilten** Listen. EventKit erlaubt kein programmatisches Zuweisen — das Zuweisen einer Person zu einer Erinnerung muss weiterhin in der nativen Reminders-App erfolgen. Glass Kanban kann nur anzeigen und danach filtern. |

### Finden: ein Bedienelement statt drei — Konzeptvorschlag

**Ausgangsproblem:** Suche, Dringkeit und Fälligkeit sind für den Nutzer *eine* Aufgabe
(„finde ein Ticket"), stehen im Chrome aber als getrennte Elemente. Heute sind das zwei
Filtermenüs; mit einer Suche wären es drei. Genau die falsche Richtung für ein Board, das
den ganzen Tag ruhig dastehen soll.

**Leitsatz, der die Lösung bestimmt:** Minimalismus heißt nicht, Bedienelemente zu
*verstecken*, sondern *weniger* davon zu haben. Verstecken kostet Auffindbarkeit und spart
nichts — die Funktion existiert ja weiter, sie ist nur schwerer zu finden. Zusammenlegen
spart wirklich.

**Empfehlung: ein einziges „Finden"-Element, das alle drei Funktionen enthält.**

| Zustand | Was im Chrome zu sehen ist |
|---|---|
| **Ruhe** (der Normalfall) | Ein Lupensymbol. Sonst nichts. Das ist *weniger* Chrome als heute, nicht mehr. |
| **Aktiv** (Klick oder ⌘F) | Das Feld wächst auf; Dringlichkeit und Fälligkeit liegen als Tokens/Scopes **im selben Feld** (`searchable(text:tokens:)` bzw. `.searchScopes`). Alles zum Finden an einem Ort. |
| **Gefiltert** | Das eingeklappte Symbol trägt den Zustand: eingefärbt, mit Anzahl aktiver Einschränkungen. |

Der dritte Zustand ist die **Sicherheitsbedingung, nicht Deko**: Ein Board darf niemals
gefiltert sein, ohne dass man das sieht. Sonst fehlen Karten und man sucht den Fehler in
den Daten statt im Filter. Verstecken ohne diese Rückmeldung wäre der eigentliche
Designfehler.

Damit sinkt das Dauer-Chrome auf **zwei Elemente**: Lupe (finden) und
Erinnerungen-Knopf (anlegen) — zwei klar getrennte Funktionen, keine Sammlung von Reglern.

**Verhalten der Suche selbst:**

- Sie ist ein Filter wie die anderen: wirkt gleichzeitig auf **alle vier Spalten** und
  verkleinert nur, was sichtbar ist. Keine Trefferliste, kein Sprung, keine eigene Ansicht —
  das Board bleibt das Board und schrumpft zusammen.
- **Durchsucht** werden Titel und Notizen, ohne Groß-/Kleinschreibung und ohne Diakritika
  (`localizedStandardContains`) — dieselbe Nachsicht wie die Reminders-App. Der
  Status-Hashtag wird vor dem Vergleich entfernt, sonst träfe „bearbeitung" schlagartig
  eine ganze Spalte.
- **Kein Suchverlauf, keine Vorschläge, kein Index** — wäre sonst der einzige Ort, an dem
  die App etwas über den Nutzer speichert, und widerspräche „lokal, speichert selbst
  nichts". Die Suche existiert nur, solange etwas im Feld steht.
- **Leeres Feld = kein Filter**, wie „Alle" bei den beiden anderen.

**Bewusst verworfen:**

- *Chrome bei Hover einblenden* — löst zwar „ich will die Knöpfe nicht sehen", aber
  Elemente, die beim Mausweg erscheinen und verschwinden, sind auf einem Board mit
  Drag & Drop unruhig, aus zwei Metern Entfernung unsichtbar und schlecht auffindbar. Ein
  ruhendes Symbol ist stiller als bewegliche Teile.
- *Nur Tastenkürzel, gar kein sichtbares Element* — maximal minimal, aber für Filter, die
  man selten braucht und deshalb vergisst, nicht auffindbar genug.
- *Eigene Filterleiste unter der Toolbar* — dauerhafte Fläche für eine gelegentliche
  Funktion; genau das Gegenteil des Ziels.

**Offener Punkt, den die Suche mit den bestehenden Filtern teilt:** Ist gefiltert, zeigen
die Spaltenzähler die *sichtbare*, nicht die tatsächliche Menge (mit WIP-Limit also z. B.
`1 / 3`, obwohl real vier Karten in Bearbeitung sind). Das ist heute schon so und fällt mit
einer Suche nur häufiger auf. Der eingefärbte Zustand am Finden-Symbol ist die minimale
Antwort darauf — eine Markierung an einer Stelle statt an jeder Spalte.

## MVP-Funktionsumfang

Die App ist im MVP bewusst **überwiegend read-only**. Das Anlegen und inhaltliche Bearbeiten
von Aufgaben (Titel, Notizen, Fälligkeit, Priorität, Person zuweisen) passiert ausschließlich
in der nativen Reminders-App. Glass Kanban visualisiert diese Daten live und schön, greift
aber nicht inhaltlich ein.

**Einzige Schreib-Interaktion in der App:** Drag & Drop einer Karte zwischen den vier Spalten
(= Hashtag in den Notizen wird im Hintergrund aktualisiert, siehe Datenmodell). Eine Karte
nach "Erledigt" ziehen setzt automatisch `isCompleted = true` und entfernt einen eventuell
vorhandenen Status-Hashtag — ein separater Erledigen-Button/Checkbox in der App ist damit
nicht nötig, das deckt der Spaltenwechsel bereits ab.

- 4 feste Spalten (siehe oben)
- Karten zeigen: Titel, Fälligkeitsdatum, Priorität, Notizen, zugewiesene Person (falls vorhanden) — nur Anzeige
- Drag & Drop zwischen Spalten
- Filterleiste: Dringlichkeit, Fälligkeit, Verantwortliche Person
- Glass-Design (Liquid Glass auf der Chrome-Ebene), siehe Design-Anspruch unten

## Motivation (leichtgewichtige Gamification)

**Psychologie, etablierte Produktivitätstechniken und Minimalismus werden bewusst und
positiv genutzt** — sowohl um die tatsächliche Produktivität beim Arbeiten mit dem Board zu
steigern, als auch um die Nutzung der App selbst angenehm und selbstverständlich zu machen.
Leitplanke dabei ist immer „belohnen, nie bestrafen": Mechanismen laden ein, sie schränken
nicht ein und beschämen nicht. Minimalismus ist in diesem Sinn nicht nur Ästhetik, sondern
selbst ein Produktivitäts-Hebel — weniger visuelles Rauschen senkt die Schwelle, die App
überhaupt regelmäßig zu öffnen, passend zum Anspruch, dauerhaft geöffnet zu bleiben.

Damit die App nicht nur ein reines Produktivitäts-Werkzeug ist, zwei bewusst kleine,
technisch günstige Zusätze — ausdrücklich **keine** Punkte/Levels/Badges/Bestenlisten, das
würde für ein Einzelnutzer-Ambient-Board zu viel Komplexität ohne echten Mehrwert bedeuten:

- **Streak-Zähler:** z. B. „🔥 5 Tage in Folge" im Fensterrahmen. Wird rein lesend aus dem
  bereits vorhandenen `completionDate` aller erledigten Erinnerungen berechnet (an wie vielen
  aufeinanderfolgenden Tagen wurde mindestens eine Karte erledigt) — keine neuen Felder, keine
  neuen Schreibzugriffe.
- **Täglich wechselnder, motivierender Satz:** kleine, lokal in der App hinterlegte Liste
  (~20 Sätze, u. a. an die Personal-Kanban-Philosophie angelehnt), Auswahl nach Kalendertag —
  ändert sich jeden Tag, bleibt am selben Tag stabil. Komplett offline, keine Analyse des
  Nutzerverhaltens, kein Server.

**Weitere, an anderer Stelle bereits ausgearbeitete Anwendungen desselben Grundsatzes:**

- **Sensorik & Belohnungsmomente** (Trackpad-Haptik, Settle-Moment beim Erledigen, sich
  füllende Streak-Flamme nach Goal-Gradient-Effekt, Tages-/Wochenfortschritt nach Endowed
  Progress/Progress Principle) — volle Herleitung in
  [design/iteration-2-concept.md](design/iteration-2-concept.md), Punkt 7.
- **Grenze, die sich daraus ergibt:** Bewegung gehört Dingen, die *gerade passiert sind* —
  nie einer stehenden Einladung. Eine Dauer-Animation wird binnen Tagen weggefiltert und
  entwertet dabei die Momente, die sich Aufmerksamkeit verdient haben. Deshalb wurde das
  pulsierende Pull-Signal nach dem Praxistest wieder entfernt: Kanbans Pull-Signal ist der
  freie Platz auf dem Board selbst, kein Effekt darüber.
- **WIP-Limits:** bewusste, aber vorsichtig eingehegte Anwendung von
  Selbstverpflichtungs-Psychologie (Reibung statt Verbot, Details in
  [design/wip-limit-concept.md](design/wip-limit-concept.md)) — dort auch offen benannt, wo
  das in Spannung zu „belohnen, nie bestrafen" gerät und wie das eingegrenzt wird.

## Design-Anspruch

Da die App dauerhaft geöffnet auf einem Bildschirm sichtbar ist, hat die Optik hohe Priorität —
sie soll wie eine hochwertige, native Apple-App wirken, nicht wie ein funktionales Werkzeug.

**Stimmungs-/Vibe-Referenz:** die "Minimal Desk Setup"-Szene (z. B. r/desksetup, minimalistische
Produktivitäts-Content-Creator) — reduzierte Flächen, ruhige/neutrale Farbgebung, wenige aber
bewusst platzierte Elemente, kein visuelles Rauschen. Die App soll sich anfühlen, als würde sie
selbstverständlich in ein so kuratiertes, aufgeräumtes Setup gehören: ein ruhiges, fast
gegenständliches Objekt auf dem Screen statt "Software", die auffällt. Produktivität wird dabei
nicht laut/motivierend inszeniert, sondern über Reduktion und Klarheit vermittelt. Das ist eine
Richtungsvorgabe/Orientierung für Optik und Ton, keine harte Spezifikation.

**Kanban als Gestaltungsmaßstab, nicht nur als Datenmodell:** Personal Kanban prägt nicht
nur, *was* die App speichert (Spalten, Status), sondern soll bei jeder Design-Entscheidung
mitgedacht werden — als eine der Fragen, an denen sich Gestaltung orientiert, neben Liquid
Glass und Minimalismus. Wo eine Kanban-Praxis (WIP-Limits, Pull-Prinzip, explizite
Prozessregeln, Sichtbarkeit von Arbeit) eine Gestaltungsfrage berührt, hat sie Gewicht bei der
Entscheidung — nicht nur dort, wo sie ohnehin schon Feature ist. Die Hover-Tipps weiter unten
sind ein konkretes Beispiel dieser Haltung, kein Sonderfall.

Konkrete Prinzipien, abgeleitet aus dieser Stimmung:

- Liquid Glass bleibt der Bedienoberfläche vorbehalten — Fensterrücken, Toolbar, Popover.
  Die Inhaltsebene ist bewusst kein Glas: Spalten sind eingelassene Mulden, Karten sind
  deckendes Papier. Tiefe entsteht durch Fläche, Kontur und Schatten, nicht durch
  gestapelte Unschärfe. Der Grund ist gemessen, nicht ästhetisch: durchscheinende Karten
  koppeln ihre Helligkeit an das Wallpaper und kehren dadurch die Tiefenordnung um
  (Karten wirken dunkler als die Mulde, in der sie liegen). Das ist zugleich Apples
  eigenes Liquid-Glass-Modell — Glas ist Chrome, nie Inhalt.
- Sauberes Typografie- und Abstandssystem nach Apple HIG (SF Pro, klare Hierarchie)
- Dezente Bewegung: sanfte Animationen beim Spaltenwechsel (Drag & Drop), beim
  Live-Update aus Reminders (z. B. Karte erscheint/verschwindet mit Fade/Slide)
- Automatische Unterstützung von Light/Dark Mode und System-Akzentfarbe
- Dringlichkeit/Fälligkeit dezent über Farbe/SF Symbols statt aufdringlicher Badges
- Da nichts inhaltlich in der App bearbeitet wird, darf die Fläche komplett auf ruhige,
  reduzierte Darstellung statt Formulare/Eingabefelder optimiert werden
- **Beispiel Pull-Signal am freien Platz:** Ist „In Bearbeitung" leer und liegt anderswo
  offene Arbeit, zeigt die Spalte einen kartengroßen, gestrichelten Platzhalter mit einer
  Zeile („Frei für die nächste Aufgabe"). Das Signal sitzt bewusst an der **leeren Stelle**,
  nicht an einer Karte: So wird kein Ticket zum Favoriten erklärt, und es entspricht dem
  Pull-Prinzip, bei dem am physischen Board immer der freie Platz ruft. Statisch, ohne Farbe,
  ohne Bewegung — es verschwindet in dem Moment, in dem gezogen wurde. Ersetzt das frühere
  pulsierende Leuchten an der obersten „Als Nächstes"-Karte, das eine Karte bevorzugte,
  dauerhaft animiert war und mit der Interaktionsfarbe kollidierte.
  **Regel dahinter: höchstens eine Einladung auf dem Board, und nur dort, wo Nichtstun
  etwas kostet.** Ein leeres „Als Nächstes" bekommt deshalb bewusst *keinen* Platzhalter —
  nicht vorgeplant zu haben ist unproblematisch, solange etwas in Arbeit ist. Zwei
  Platzhalter nebeneinander würden das Board wie ein auszufüllendes Formular wirken lassen
  (besonders beim ersten Start, wenn alles im Backlog liegt) und die Aufforderung mehrdeutig
  machen. Backlog und Erledigt schweigen leer ohnehin — „In Bearbeitung" ist die begründete
  Ausnahme, nicht „Als Nächstes" die vergessene.
- **Beispiel Hover-Tipps:** An Stellen, wo die App bereits eine stille Kanban-Regel *hat*,
  aber nirgends *erklärt* (z. B. ein WIP-Limit, das Pull-Prinzip im Backlog, der Unterschied
  zwischen Zusage-Warteschlange und Ablage), trägt das jeweilige UI-Element einen kurzen
  Hover-Tooltip — ein Fragment, kein ganzer Satz, keine separate Anleitung. Wissen entsteht
  im Moment der Berührung, nicht über Onboarding.

**Warum das zur bestehenden Philosophie passt, nicht nur zusätzlich dazu:** Ein
`.help(...)`-Tooltip ist ein Standard-SwiftUI-Mechanismus, kein Custom-UI — bleibt
unsichtbar bis zum Hover (Minimalismus: kein Dauertext, kein neues Element, keine
Onboarding-Fläche), ist rein statischer, in der App gebündelter Text wie die
täglichen Motivations-Sätze (lokal/offline: keine Server-Anfrage, keine Analyse,
welche Tipps gelesen werden), und fügt sich als natives Systemverhalten unauffällig
in bestehende Mac-Konventionen ein (native Apple-App statt Custom-Tooling). Konkret
angewendet z. B. im WIP-Limit-Konzept ([design/wip-limit-concept.md](design/wip-limit-concept.md)).

## Mac-/Apple-spezifische Vertiefung

Konsequent aus Sicht eines Mac-/Apple-Nutzers gedacht — was macht die App zu einer "echten"
nativen Mac-App statt eines austauschbaren Tools?

**Ins MVP aufgenommen:**

- **Native Toolbar statt selbstgebauter Titelleiste:** SwiftUI `.toolbar`/`NSToolbar` statt
  eigenem UI-Element für Titel + Filter-Chips. Dadurch übernimmt die App automatisch das
  System-Verhalten für Liquid Glass (Scroll-Edge-Effekt, Verhalten beim Resizen etc.) und bleibt
  über macOS-Updates hinweg konsistent, ohne eigene Wartung.
- **Volles natives Menü + Tastaturkürzel:** Standard-App-Menü, Fenster-Menü, sinnvolle
  Kurzbefehle (z. B. ⌘F für Filter-Fokus, Pfeiltasten zur Kartennavigation) statt einer App ohne
  Menüleisten-Funktionalität.
- **Barrierefreiheit/Systemeinstellungen respektieren:** "Transparenz reduzieren" und "Bewegung
  reduzieren" (macOS-Bedienungshilfen) werden beachtet — gerade bei einem Glass-lastigen Design
  wichtig, damit die App für alle Nutzer und auf älterer Hardware performant nutzbar bleibt.
- **Listenfarbe aus Reminders übernehmen:** `EKCalendar.color` (die Farbe, die eine Liste schon
  in der nativen Reminders-App hat) als kleiner Akzent/Punkt auf der Karte — verbindet das Board
  visuell mit der bestehenden, vertrauten Reminders-Farbcodierung, ganz ohne neue Konzepte.

**Interessante spätere Ausbaustufen (bewusst nicht MVP, aber notiert):**

- **Desktop-Widget (WidgetKit):** eine kompakte Ambient-Ansicht (z. B. Kartenanzahl pro Spalte,
  Streak) direkt auf dem Schreibtisch, ergänzend oder als Alternative zum dauerhaft offenen
  Fenster.
- **Shortcuts-App/App Intents:** z. B. "Wie viele Karten sind in Bearbeitung?" oder eine Karte
  per Kurzbefehl/Automation verschieben — externe Steuerung, die den "kein Editor in der App"-
  Grundsatz nicht verletzt, da Shortcuts von außen kommen.
- **Fokus-Modi-Integration (Focus Filters):** Board passt Filter automatisch an den aktiven
  macOS-Fokus an (z. B. "Arbeit" vs. "Privat") — passt inhaltlich gut zur Personal-Kanban-Idee
  von Kontexttrennung.
- **App-Icon im neuen Icon-Composer-Format:** Light/Dark/Tinted-Varianten mit
  Liquid-Glass-Spiegelungen, passend zum macOS-26-Icon-System.

**Bewusst ausgeschlossen:**

- **Eigene Push-Benachrichtigungen der App:** Reminders hat bereits eigene Benachrichtigungen;
  eigene Notifications würden sich damit doppeln und widersprechen dem ruhigen,
  Minimal-Desk-Setup-Vibe der App.

## Bewusst außerhalb des MVP

- Mehrere Boards
- Konfigurierbare Spaltenanzahl/-namen
- Manuelle Kartenreihenfolge innerhalb einer Spalte (MVP sortiert z. B. nach Fälligkeitsdatum)
- Menüleisten-Modus / Always-on-Top
- Aufgaben anlegen/inhaltlich bearbeiten in der App (bewusst nur über Reminders-App)
- Zuweisen von Personen aus Glass Kanban heraus (zusätzlich auch eine EventKit-Limitierung, s. o.)
- WIP-Limit für "In Bearbeitung" (spätere Ausbaustufe)
- Unteraufgaben (Subtasks): **nicht per öffentlicher EventKit-API auslesbar**, ähnlich wie Tags
  eine private, nicht zugängliche Funktion der Reminders-App — technisch im MVP nicht umsetzbar

## Bekannte Risiken / offene Punkte

- Nutzer muss beim ersten Start den Vollzugriff auf Erinnerungen im Systemdialog genehmigen.
- Enthält der eigene Notiztext zufällig bereits `#backlog`/`#alsnächstes`/`#inbearbeitung`, würde das als
  Status interpretiert — in der Praxis unwahrscheinlich, aber beim Hashtag-Parsing zu bedenken.
- Werden mehrere erkannte Hashtags gleichzeitig in den Notizen gefunden (z. B. durch manuelles
  Bearbeiten in Reminders), braucht es eine klare Regel (z. B. der zuletzt hinzugefügte/erste
  gefundene Tag gewinnt, App bereinigt beim nächsten Sync auf einen einzigen Tag).
- Verantwortliche-Person-Filter liefert nur Daten, wenn die zugrunde liegende Liste aktiv
  über iCloud geteilt ist.
