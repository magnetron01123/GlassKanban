# Glass Kanban für macOS-Erinnerungen — Konzept & Begründung

> **Hinweis:** Was die App heute tatsächlich tut, steht in [SPEC.md](SPEC.md), verschobene
> und abgelehnte Ideen in [BACKLOG.md](BACKLOG.md). Dieses Dokument liefert die Herleitung
> und Begründung der Entscheidungen — bei Widersprüchen gilt SPEC.md.
>
> Teile dieses Dokuments beschreiben den Planungsstand vor der Umsetzung (erkennbar an
> Formulierungen wie „im MVP" oder „bewusst außerhalb des MVP"). Sie bleiben als Begründung
> stehen, auch wo die App inzwischen weiter ist — die Argumente gelten weiterhin, nur der
> Umfang hat sich verschoben. Maßgeblich für den Ist-Stand ist immer SPEC.md.

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

### Das Board ist einer von mehreren Schreibern (10.08.2026)

Aus dem Datenmodell folgt eine Eigenschaft, die lange unausgesprochen blieb: **Backlog ist
als *Abwesenheit* eines Tags definiert.** Eine Karte ins Backlog zu ziehen heißt also nicht
schreiben, sondern löschen — und Löschen ist die schwächste Operation, die es in einem
verteilten System gibt. Ein fremder Client mit altem Stand weiß nichts davon; er behauptet
seinen Stand, und der gewinnt. Im Modell gab es nichts, was eine getroffene Entscheidung
gegen einen überholten Zustand verteidigt.

Gemessen an einem echten Fall: Eine Brücke zwischen Reminders und einer Hausautomatisierung
schob alle 30–55 Minuten einen alten Stand zurück; ein ins Backlog gezogenes Ticket stand
danach wieder in „Als Nächstes", und die Tag-Hygiene schrieb dieselben vier Erinnerungen
dreimal in drei Stunden um, ohne dass ein einziger Schreibvorgang hielt.

**Geprüft und verworfen:** ein eigener `#backlog`-Tag. Er macht die Abwesenheit zwar zur
Aussage, aber ein Rückschieber überschreibt eine Aussage genauso wie eine Leere — ohne
Gedächtnis sieht die App danach nur den fremden Wert, mit Gedächtnis braucht sie den Tag
nicht. Er hätte nur sichtbaren Text in fremde Notizen geschrieben: Kosten ohne Nutzen.
Backlog bleibt „kein Tag".

**Die Antwort ist stattdessen eine Invariante** über jeden Schreibvorgang, den der Nutzer
nicht angefordert hat: Das Board stellt eine Entscheidung wieder her, wann immer jemand
sie rückgängig macht, nur nie schneller als ein Mensch es bemerken würde (Regel und
Messung in SPEC.md, „Eine Antwort je Zustand"). Sie ersetzt keinen der bestehenden
Mechanismen, sondern zieht eine Grenze um sie alle.

**Ausgeweitet am 10.08.2026 auf vier Felder** (Notizen, Titel, URL, Fälligkeit), nachdem
gemessen war, dass der fremde Schreiber ganze Datensätze zurücksetzt und dabei auch
einmalige, längst erledigte Aufgaben trifft — sichtbar wurde es nur an wiederkehrenden,
weil ein Tag auf einer erledigten Erinnerung nichts bewirkt.

Zwei Spannungen, die dabei bewusst entschieden wurden statt still zu bleiben:

- **„Die App speichert selbst nichts" (Datenmodell) gegen „sie muss neben anderer Software
  funktionieren".** Das Gedächtnis hält jetzt Inhalte von vier Feldern. Es bleibt Evidenz
  und keine Schattenkopie, weil ausschließlich board-eigene Verdrängungen hineinkommen, es
  nach 24 Stunden verfällt, auf 200 Karten gedeckelt ist und nie gerendert wird — die
  Grenze ist damit aber ausgereizt. Wer das nächste Feld aufnehmen will, muss diese
  Abwägung neu führen.
- **Nur eigene Schreibvorgänge, keine bloß beobachteten.** Naheliegend wäre, jede
  beobachtete Änderung zu verteidigen; erwogen, entworfen und verworfen. Auf einem Board,
  auf dem ein fremdes Programm häufiger schreibt als der Mensch, würde die App überwiegend
  dessen alte Werte adoptieren und sie anschließend mit eigener Autorität gegen den
  echten Nutzerwert durchsetzen. Einzige Ausnahme bleibt das Verschwinden eines
  Arbeits-Tags, weil daraus nur die Abwesenheit eines Tags folgen kann.

Der Restschaden, der bleibt und nicht wegzukonstruieren ist: Ein bewusster Widerruf auf
einem anderen Gerät erzeugt definitionsgemäß den Vorzustand und ist von einem Rückschieber
bitgleich. Er wird überschrieben. Eine *andere* Änderung zieht den Eintrag dagegen sofort
zurück.

**Koexistenz ist dabei die Grundannahme, nicht der Sonderfall.** Erinnerungen, Fantastical,
eine Automatisierungs-Brücke, Kurzbefehle: Alle dürfen dieselben Datensätze lesen und
schreiben. Eine App, die nur als alleiniger Schreiber funktioniert, wäre für ein System, in
dem Erinnerungen absichtlich allen Programmen offenstehen, kein Produkt. Das Board
verteidigt deshalb genau eine Sache — die Spaltenzuordnung, und die auch nur in Richtung
Backlog. Alles andere, was ein fremdes Programm schreibt, gilt.

**Warum der Nutzer davon nichts erfährt** (Entscheidung vom 10.08.2026): Erwogen war, nach
dem Nachgeben einmalig zu melden, dass eine Liste von außen zurückgeschrieben wird — im
Sinne von „make policies explicit". Verworfen: Das Board ist eine ruhige Dauerfläche, keine
Diagnoseoberfläche. Ein Hinweis über die Mechanik der Spaltenzuordnung wäre genau das
Dauerrauschen, das der Minimalismus ausschließt, und er beschriebe ein Problem, das der
Nutzer im Board ohnehin nicht lösen kann. Die Spaltenlogik bleibt unsichtbar; wo sie an
fremden Schreibern scheitert, zeigt das Board schlicht, was in den Daten steht.

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

### Finden: ein Bedienelement statt drei

> **Umgesetzt** (Lupe in der Toolbar, ⌘F). Was unten als Empfehlung formuliert ist, ist
> gebautes Verhalten — der verbindliche Stand steht in [SPEC.md](SPEC.md), Abschnitt
> „Finden". Der Text bleibt als Herleitung stehen. Eine Abweichung: Statt des
> Verantwortliche-Person-Filters aus der Tabelle oben enthält das Element heute einen
> **Listen-Filter** (die Personen-Zuordnung ist über EventKit kaum nutzbar, siehe
> BACKLOG.md).

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
technisch günstige Zusätze — ausdrücklich **keine** Punkte/Levels/Bestenlisten und kein
Abzeichen-Regal, das würde für ein Einzelnutzer-Ambient-Board zu viel Komplexität ohne echten
Mehrwert bedeuten (zur einen bewussten Ausnahme siehe „Statistik-Fenster" weiter unten):

- **Streak-Zähler:** z. B. „🔥 5 Tage in Folge" im Fensterrahmen. Wird rein lesend aus dem
  bereits vorhandenen `completionDate` aller erledigten Erinnerungen berechnet (an wie vielen
  aufeinanderfolgenden Tagen wurde mindestens eine Karte erledigt) — keine neuen Felder, keine
  neuen Schreibzugriffe.
- **Täglich wechselnder, motivierender Satz:** kleine, lokal in der App hinterlegte Liste
  (~20 Sätze, u. a. an die Personal-Kanban-Philosophie angelehnt), Auswahl nach Kalendertag —
  ändert sich jeden Tag, bleibt am selben Tag stabil. Komplett offline, keine Analyse des
  Nutzerverhaltens, kein Server.

- **Statistik-Fenster:** hinter der Flamme in der Toolbar, zwei Reiter („Jetzt" /
  „Rückblick"), rein lesend aus denselben `completionDate`-Werten plus dem Listennamen der
  erledigten Erinnerung. Enthält neben Streak und Tagesfortschritt die Personal-Kanban-Sicht
  auf das eigene System: aktuelle Auslastung („In Bearbeitung" gegen das eigene WIP-Limit)
  und eine „Bis fertig"-Schätzung nach Little's Law (Auslastung ÷ Tempo). Bewusst als
  *Schätzung* beschriftet — der Wert steigt, sobald mehr gleichzeitig begonnen wird, und
  genau das ist die Aussage eines WIP-Limits. Im Rückblick stehen seit Juli 2026 zusätzlich
  die beiden Flusskennzahlen, aus denen diese Schätzung besteht — **Durchsatz** („Pro
  Woche") und **Durchlaufzeit** (Median erfasst→erledigt, nur einmalige Aufgaben, nur die
  letzten 30 Tage: über die ganze Historie gemessen dominieren Backlog-Altlasten den Wert,
  und eine dauerhaft riesige Zahl wäre eine stehende Anklage; gefenstert beschreibt die
  Zahl das aktuelle Verhalten und verbessert sich mit ihm). Mit allen drei
  Little's-Law-Größen im Fenster ist die Schätzung nachrechenbar statt Orakel.
  **Die eine bewusste Ausnahme von der Abzeichen-Regel:** ein Meilenstein-Hinweis bei runden
  Zahlen (50/100/250/…) — aber nur, wenn die Schwelle in den letzten sieben Tagen
  überschritten wurde. Er wird jedes Mal neu aus der Historie abgeleitet, nichts wird
  gespeichert, und er verschwindet von selbst wieder. Ein Abzeichen, das monatelang steht,
  ist kein Moment mehr, sondern Mobiliar.

**Weitere, an anderer Stelle bereits ausgearbeitete Anwendungen desselben Grundsatzes:**

- **Sensorik & Belohnungsmomente:** Trackpad-Haptik bei jedem echten Spaltenwechsel
  (beim Erledigen eine Stufe kräftiger), Settle-Moment beim Erledigen (Karte legt sich ab,
  ein kurzer Atemzug, dann zieht sich der Durchstrich sichtbar über den Titel — der Stift,
  der abhakt; ersetzte im Juli 2026 einen grünen Schimmer samt Squish, die als Farbfläche
  über dem Papier bzw. Lärm vor der Geste der Kartenregel widersprachen) und ein kurzes,
  farbloses Wackeln mit Größen-Pop plus
  Haptik-Doppeltick beim Pull nach „In Bearbeitung" (die Karte „zappelt vor Tatendrang") —
  Anfangen ist spürbar, die Abschlussgeste bleibt dem Fertigwerden vorbehalten. Dazu ein
  leiser, eigener Erledigt-Klang (aufsteigende Quinte — Aufsteigen sagt „geschafft";
  bewusst kein Systemklang, die dienen in macOS als Warntöne; abschaltbar in den
  Einstellungen), ein kleines Nicken der
  Toolbar-Flamme bei jeder erledigten Aufgabe, die sich mit dem Tagesfortschritt füllende
  Streak-Flamme (Goal-Gradient-Effekt), Tages-/Wochenfortschritt im Statistik-Fenster
  (Endowed Progress/Progress Principle). Leitplanke: Belohnungen bleiben klein und sicher —
  keine Fanfare, keine Eskalation; eine große Belohnung ließe die hundertste Erledigung
  kleiner wirken als die erste.
- **Grenze, die sich daraus ergibt:** Bewegung gehört Dingen, die *gerade passiert sind* —
  nie einer stehenden Einladung. Eine Dauer-Animation wird binnen Tagen weggefiltert und
  entwertet dabei die Momente, die sich Aufmerksamkeit verdient haben. Deshalb wurde das
  pulsierende Pull-Signal nach dem Praxistest wieder entfernt: Kanbans Pull-Signal ist der
  freie Platz auf dem Board selbst, kein Effekt darüber.
- **WIP-Limits:** bewusste, aber vorsichtig eingehegte Anwendung von
  Selbstverpflichtungs-Psychologie — **Reibung statt Verbot**. Das Board blockt eine
  Überschreitung nie (das wäre Bestrafung und würde dem „belohnen, nie bestrafen"-Grundsatz
  widersprechen), sondern lässt die Karte landen und stellt *danach* genau eine Frage
  („Weniger gleichzeitig, mehr fertig. Erst etwas abschließen?"), deren bequemste Antworten
  — Return und Escape — das Limit respektieren. Überschreiten bleibt ein bewusster Klick,
  kein Kampf. Das Limit läuft sichtbar im Spaltenzähler mit („make policies explicit"),
  und nur „In Bearbeitung" fragt nach: Kanban begrenzt begonnene Arbeit, nicht Planung.

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
- **Immer-aktiv: das Board sieht fokussiert aus, auch ohne Fokus.** macOS lässt
  inaktive Fenster bewusst zurücktreten — vibrierendes Glas graut aus, Materialien
  flachen ab, `.secondary`-Text hellt auf. Dieses Verhalten ist für Fenster gedacht,
  in denen man *arbeitet* und die zurückweichen sollen, während man woanders hinsieht.
  Dieses Board ist das Gegenteil: Es steht dauerhaft offen auf einem Zweitschirm, ist
  also fast immer inaktiv, und soll trotzdem durchgehend gleich aussehen — dem
  Fensterzustand zu folgen würde das Glas, für das die App benannt ist, nur in den
  seltenen Fokus-Momenten zeigen. Deshalb wird die gesamte App an ihr aktives
  Erscheinungsbild gepinnt: Fensterrücken, Tooltip und Empty-Notice sind allesamt
  `HUDGlassMaterial` mit `state = .active` (siehe `ContentView.WindowGlass`,
  `HUDGlassMaterial`). Der „+"-Knopf zum Anlegen einer Karte lief zunächst über SwiftUIs
  natives `.glassEffect` (mehr Vibrancy, das „+" ins Glas komponiert) — aber genau dieses
  native Glas folgt dem Fensterzustand und lässt sich **nicht** pinnen (auch ein
  gesetztes `controlActiveState = .key` wirkt darauf nicht): beim Fokusverlust hellten
  Scheibe und Glyph auf und der Knopf war als einziges Element in den Hintergrund
  getreten, während ringsum nichts sich rührte. Deshalb nutzt auch er jetzt dasselbe
  gepinnte `HUDGlassMaterial` wie der Rest der App. **Regel dahinter: Kein Element tritt
  zurück, nur weil das Fenster den Fokus verliert.** Neue Glasflächen sind entsprechend
  über `HUDGlassMaterial` (`state = .active`) zu bauen, nicht über native
  `.glassEffect`-Controls, solange Apple dafür keinen Aktivzustand-Pin anbietet.
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
  **Wichtige Abgrenzung (Entscheidung Juli 2026):** Das gilt nur für das *Chrome*
  (Spaltenkopf, Bedienelemente), das Regeln erklärt — **nie für die Karten selbst**.
  Tooltips, die auf jedem berührten Ticket Zusatzinfos aufspringen lassen, wurden
  ausprobiert und als Dauerrauschen wieder entfernt, siehe BACKLOG.md („Explizit
  abgelehnt"). Dieselbe Entscheidung gilt für Tastaturfokus auf Karten.

**Warum das zur bestehenden Philosophie passt, nicht nur zusätzlich dazu:** Ein
`.help(...)`-Tooltip ist ein Standard-SwiftUI-Mechanismus, kein Custom-UI — bleibt
unsichtbar bis zum Hover (Minimalismus: kein Dauertext, kein neues Element, keine
Onboarding-Fläche), ist rein statischer, in der App gebündelter Text
(lokal/offline: keine Server-Anfrage, keine Analyse,
welche Tipps gelesen werden), und fügt sich als natives Systemverhalten unauffällig
in bestehende Mac-Konventionen ein (native Apple-App statt Custom-Tooling). Konkret
angewendet z. B. am Spaltenkopf, dessen Tooltip das WIP-Limit erklärt.

### Ton der Texte

Das Board spricht wie ein Werkzeug, nicht wie ein Begleiter: knapp und sachlich. Es coacht
nicht, tröstet nicht und feuert nicht an. Der Ton ist kein viertes Prinzip, sondern fällt
aus den drei bestehenden ab:

- **Minimalismus** → so kurz wie möglich. Ein Satz im Chrome wird hundertmal gelesen; über
  ihn entscheidet die zehnte Lesung, nicht die erste. Jedes Wort, das den Zustand nicht
  benennt, ist Rauschen.
- **Psychologische Wirksamkeit** → über *Zustände* redet die App klar, über die *Person*
  nur dort, wo es etwas beiträgt („Dein Schnitt an aktiven Tagen"). Nie Trost, nie Ansporn.
- **Kanban** → Regeln werden beim Namen genannt. Ein überschrittenes Limit zu benennen ist
  keine Rüge, sondern „make policies explicit".

**Sieben Fragen an jeden neuen oder geänderten Satz:**

1. Benennt er den Zustand — oder kommentiert er ihn?
2. Ist er kürzer als das, was er ersetzt? Wenn nicht: Was trägt die Mehrlänge?
3. Hält er die zehnte Lesung aus?
4. Steht Deutsch im selben Register wie Englisch? Wobei „idiomatisch in beiden Sprachen"
   das Ziel ist, nicht Wort-für-Wort-Gleichheit.
5. **Besitz benennen, wo der Zustand aus einer eigenen Einstellung folgt.** Stammt eine
   Zahl oder ein Zustand aus etwas, das der Nutzer selbst eingestellt oder entschieden hat,
   sagt die App das mit „dein" statt unpersönlich. Das ist kein Kommentar, sondern
   Genauigkeit darüber, wessen Regel gerade greift — und es passt zu „Reibung statt
   Verbot": Die App setzt nichts durch, sie zeigt die eigene Grenze. „Über deinem Limit"
   trägt zwei Tatsachen (überschritten *und* selbst gesetzt), wo „Limit überschritten" nur
   eine trägt und dabei klingt, als sei es die Regel der App.
   **Grenze:** Der Besitz gilt dem *Zustand*, nie dem *Verhalten* — „Über deinem Limit" ja,
   „Du hast zu viel angefangen" nein. Und nur, wo wirklich eine eigene Einstellung
   dahintersteht; „Keine Treffer" und „Nicht gespeichert" hat niemand eingestellt. Ein
   „dein" reicht: „dein eigenes" oder „dein selbst gesetztes" verdoppelt, was das Possessiv
   schon sagt.
6. **Die Frage stellen die Knöpfe.** Ein Dialogtext, der wiederholt, was auf den Knöpfen
   steht, sagt es zweimal. Die Meldung erklärt, *warum* gefragt wird, nicht *was*.
7. **Punkt nur, wo ein vollständiger Satz steht — oder mehr als einer.** Zahlenzeilen,
   Beschriftungen, Merksätze und Halbsätze bleiben ohne, auch lange mit Doppelpunkt und
   Gedankenstrich („Dein Durchsatz: erledigte Aufgaben pro Woche, Durchschnitt der letzten
   30 Tage — das Tempo in Little's Law"). Probe: Lässt sich die Zeile als Satz mit Verb
   lesen? Dann Punkt, sonst nicht. Ein Punkt hinter einem Fragment ist ein Wort, das nichts
   sagt. Dieselbe Grenze fällt im Deutschen und im Englischen an denselben Stellen, weil
   dort dieselben Fragmente stehen; sie deckt sich zudem mit Apples Regel für Hilfetexte.
   **Werden Bausteine zur Laufzeit zusammengesetzt** (Statistik-Zeilen, VoiceOver-Labels),
   gehört das Trennzeichen in die Zusammensetzung, nicht in den Baustein — `joined` mit
   `". "` statt eines Punktes im Text. Sonst hängt die Lesbarkeit der einen Stelle am
   Satzzeichen der anderen, und der letzte Baustein trägt am Ende doch wieder einen Punkt.

**Gültige Muster, alle aus der App:**

| Fall | So | Nicht so |
|---|---|---|
| Fehler | „Nicht gespeichert" | „Das hat leider nicht geklappt" |
| Leerer Zustand | „Keine Treffer" | „Kein Treffer, nichts verloren" (2026 entfernt) |
| Regel | „Über deinem Limit" | „Limit überschritten" / „Über deinem eigenen Limit" |
| Leeres Feld | „Keine Notizen" | „Notiz hinzufügen" |
| Reibung | „Weniger gleichzeitig, mehr fertig." | dieselbe Zeile plus „Erst etwas abschließen?" — das steht schon auf dem Knopf |
| Leistung | „Dein Schnitt an aktiven Tagen" | „Du warst an 4 Tagen untätig" |
| Zahlenzeile | „Dein Limit: 3" | „Dein Limit: 3." |
| Regel erklärt (10.08.2026) | „Ist eine Spalte voll, fragt das Board vor der nächsten Karte nach. 0 heißt: kein Limit." | „Finish before you stack" — eine Maxime, dazu nur beim Überfahren sichtbar |
| Verworfene Eingabe (10.08.2026) | „Wird nicht gesichert — eine Adresse hat keine Leerzeichen" | kommentarlos verschwinden lassen, oder „Ungültige URL" (benennt den Nutzer als im Unrecht, nicht die Folge) |

Für VoiceOver-Beschriftungen gilt dasselbe, nur schärfer: Sie werden bei jedem Anlaufen
erneut vorgelesen und vertragen kein Wort zu viel. Ein Motivationssatz als Beschriftung ist
derselbe Dauertext, den das Board an anderer Stelle bereits abgeschafft hat.

**Vorgeschichte, damit sie sich nicht wiederholt (09.08.2026):** Aus einer Marktrecherche
kam der Vorschlag, alle Texte einem Durchgang „anbieten statt mahnen" zu unterziehen,
hergeleitet aus Gentler Streak und CARROT Weather. Beides sind Apps mit einer *Stimme*;
dieses Board ist ein Werkzeug. Herausgekommen sind Ersetzungen, die länger,
umgangssprachlicher und indirekter waren als die Originale — „Statistiken. Eine Aufgabe
startet eine neue Folge" statt „Zurzeit keine Folge", „hat nicht geklappt" statt „nicht
möglich". Verworfen. Die Prüfung aller 164 Schlüssel ergab, dass das Register bereits
stimmt; geblieben sind allein die Regeln 5 und 6, die aus dieser Diskussion entstanden
sind. Lehre: Vorbilder für den Ton kommen aus Werkzeugen, nicht aus Apps mit Persönlichkeit
— und wer eine Textänderung vorschlägt, legt Vorher und Nachher nebeneinander und begründet
jede zusätzliche Silbe.

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

## Was hier bewusst *nicht* mehr steht

Dieses Dokument führte bis zum 03.08.2026 an dieser Stelle vier Listen: spätere
Ausbaustufen, bewusst Ausgeschlossenes, „außerhalb des MVP" und bekannte Risiken. Sie
waren reine Aufzählungen ohne Herleitung — also genau das, was **nicht** die Aufgabe
dieses Dokuments ist — und liefen der Wirklichkeit hinterher: Das WIP-Limit stand dort
noch als „spätere Ausbaustufe", das Bearbeiten in der App als ausgeschlossen, und die
Hashtag-Risiken waren längst gelöst und spezifiziert.

Gültig ist deshalb:

- **Was später oder nie kommt** → [BACKLOG.md](BACKLOG.md) (Ausbaustufen, „Explizit
  abgelehnt", Apple-Plattform-Grenzen)
- **Wie die App mit diesen Fällen heute umgeht** → [SPEC.md](SPEC.md) (Tag-Erkennung
  samt Wortgrenzen, Mehrfach-Tags, Datenhygiene, bekannte Einschränkungen)

Der Rest dieses Dokuments bleibt, was er sein soll: die Begründung hinter den
Entscheidungen, nicht ihre Liste.
