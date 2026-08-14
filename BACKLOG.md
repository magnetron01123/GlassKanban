# Glass Kanban — Backlog

Alles, was bewusst **nicht** in den MVP geht. Sortiert nach Kategorie, jeweils mit kurzer
Begründung, warum später (oder warum grundsätzlich nicht).

## Bewertungsraster für neue Ideen (09.08.2026)

Aus einer Marktrecherche entstanden (Design-prämierte Apps, Kanban-Markt, Mac-native Apps,
Produktivitäts-Psychologie) und für alles in diesem Dokument gedacht. Drei Größen mit je
einer eigenen Aufgabe — bewusst nicht mehr, damit das Raster demselben Maßstab genügt wie
die App:

- **Philosophie** entscheidet über die *Zulässigkeit*: erfüllt / mit Vorbehalt / verletzt.
  Ausschlusskriterium, kein Bewertungsfaktor — wird nie gegen Marktwert aufgerechnet. „Mit
  Vorbehalt" heißt, dass der Vorbehalt hier benannt und bewusst entschieden wird, statt
  weggemittelt zu werden (CLAUDE.md: Spannung benennen, nicht still entscheiden).
- **Wirkung** entscheidet über die *Reihenfolge*: Produktversprechen vor Kaufentscheidung
  vor Nutzungsalltag. Ein Versprechen, das die App nicht einlöst, kostet vor dem
  Verkaufsstart mehr, als jedes Zusatzfeature einbringt.
- **Umkehrbarkeit** entscheidet über die *Sorgfalt*: Umkehrbares darf erprobt werden.
  Gebundenes — was in fremde Daten schreibt, eine zweite Plattform öffnet oder in den
  Automatisierungen der Nutzer steckt — muss vor der Umsetzung stehen. Dieses Kriterium
  stammt aus der eigenen Historie: Ein erheblicher Teil der Gestaltungsideen dieses
  Projekts wurde nach dem Praxistest wieder entfernt (pulsierendes Pull-Signal,
  Karten-Tooltips, Tastaturfokus, grüner Blitz, Motivationssatz).

**Marktbefund, damit die Bewertungen nachvollziehbar bleiben:** Es gibt inzwischen ein
halbes Dutzend Kanban-Aufsätze auf Reminders, dazu Apples eigene Spaltenansicht seit
Sonoma — durchweg ohne Methode, ohne Design-Anspruch, ohne Pflege. Die Idee ist damit
validiert, die Ausführung überall Prototyp; der Pitch muss „die ernsthafte Umsetzung"
sein, nicht „die Idee". „Lokal, kein Konto, Einmalkauf" ist im Indie-Segment inzwischen
Standard-Pitch und damit Eintrittskarte, kein Alleinstellungsmerkmal. Unbesetzt sind
dagegen drei Dinge, die dieses Projekt hat oder leicht bekommt: Flusskennzahlen für
Einzelpersonen, WIP als Reibung statt Verbot, und die Positionierung als ruhige Dauerfläche
im Schreibtisch-Setup. Gegen ein mögliches Sherlocking schützt nicht das Layout, sondern
das, was Apple aus Massentauglichkeit nie bauen wird: Meinungsstärke.

| Idee | Philosophie | Wirkung | Umkehrbarkeit | Aufwand |
|---|---|---|---|---|
| Bildschirmzuordnung (neu, unten) | erfüllt | Produktversprechen | umkehrbar | S–M |
| Darstellungsgröße (neu, unten) | erfüllt | Produktversprechen | umkehrbar | S–M |
| Ablegen aus anderen Apps (neu, unten) | erfüllt | Kaufentscheidung | gebunden | S–M |
| Widget „eine Karte" (s. Spätere Apple-/Mac-Ausbaustufen) | erfüllt | Kaufentscheidung | gebunden | L |
| Natürlichsprachige Erfassung (neu, unten) | erfüllt | Kaufentscheidung | gebunden | M |
| StandBy (s. Plattform-Erweiterung: iOS-App) | erfüllt | Kaufentscheidung | gebunden | XL |
| Tageszeit-Palette (neu, unten) | mit Vorbehalt | Nutzungsalltag | umkehrbar | M |
| Serie mit Ruhetag (neu, unten) | mit Vorbehalt | Nutzungsalltag | umkehrbar | S |
| Ruhezustand (s. Ambient-Screensaver-Modus) | mit Vorbehalt | Nutzungsalltag | umkehrbar | M–L |
| Fokus-Filter (s. Fokus-Modi-Integration) | erfüllt | Nutzungsalltag | umkehrbar | M |
| Tagesrückblick (neu, unten) | erfüllt | Nutzungsalltag | umkehrbar | S |
| Trennung im Backlog (s. Board-Struktur) | erfüllt | Nutzungsalltag | umkehrbar | S |
| Vordergrund-Option (s. Fensterverhalten) | erfüllt | Nutzungsalltag | umkehrbar | S |
| App Intents (s. Spätere Apple-/Mac-Ausbaustufen) | erfüllt | Nutzungsalltag | gebunden | M |

### Die ruhige Fläche im Schreibtisch-Setup (09.08.2026)

Die Prämisse „das Board steht dauerhaft offen und wird kaum bedient" hat bisher genau eine
Konsequenz in der App: die Immer-aktiv-Regel (CONCEPT.md, Design-Anspruch). Das ist die
schwierigste — die übrigen sind billiger und im Alltag deutlicher. Der gemeinsame Nenner
ist nicht die Hardware, sondern die Rolle: eine Fläche, die dasteht. Im
Minimal-Desk-Setup ist das ebenso oft ein iPhone am Ladeständer wie ein zweiter Monitor,
weshalb der StandBy-Punkt unten (Abschnitt „Plattform-Erweiterung: iOS-App") inhaltlich
hierher gehört.

- **Bildschirmzuordnung** — das Fenster kehrt nach dem Andocken auf seinen Monitor zurück,
  statt auf dem eingebauten Display zu bleiben. Dafür die Identität des Displays merken,
  nicht nur den Fensterrahmen wie heute. Genau genommen kein Feature, sondern ein
  Fehlerbild: Bei einer App, deren ganze Idee „steht immer da" ist, ist ein Board am
  falschen Platz der teuerste Alltagsmoment.
- **Darstellungsgröße** — Skalierung des ganzen Boards für Leseabstände bis etwa zwei
  Meter. Der Aufwand steckt nicht im Bedienelement, sondern darin, die Tokens in
  `DesignSystem.swift` skalierbar zu machen; wer daran vorbei baut, zerlegt das
  Abstandssystem. Heute löst das ein einziger fester Wert (Kartentitel 15pt statt 14,
  siehe SPEC.md, „Design") — eine Entscheidung, die eigentlich der Nutzer treffen sollte.

### Erfassung und Eingang (09.08.2026)

- **Ablegen aus anderen Apps** — eine Mail, ein Safari-Link oder eine Datei wird per
  Drag & Drop auf eine Spalte zur Karte. `ColumnView.dropDestination` nimmt heute nur
  `String` (Karten-IDs) an und müsste zusätzlich `URL` und Text annehmen; das URL-Feld des
  Karten-Editors existiert samt Schreibpfad, der Link landet also in genau dem Feld, das
  Reminders ohnehin an jeder Aufgabe zeigt. Drag & Drop ist bereits die Kerngeste des
  Boards — es entsteht kein neues Chrome. Wohin die Karte fällt, entscheidet die Geste;
  überschreitet sie dabei „In Bearbeitung", greift der bestehende WIP-Dialog ohne
  Sonderlogik. **Gebunden:** neuer Schreibzugriff auf fremde Daten, daher Testpflicht als
  reine Regel vor dem Bau (Muster `StatusTagger`, `RecurringTagRelease`).
- **Natürlichsprachige Erfassung** — eine Eingabezeile statt eines Formulars; Termin und
  Priorität werden aus dem Text erkannt und **vor** dem Speichern als Token sichtbar
  gemacht. Das ist dieselbe Sicherheitsbedingung wie beim eingefärbten Finden-Symbol: nie
  still etwas anderes tun, als man sieht. Folgt dem Leitsatz „weniger Bedienelemente statt
  versteckter" (CONCEPT.md, „Finden: ein Bedienelement statt drei"). **Trotz hoher Wirkung
  bewusst niedrig priorisiert:** Ein falsch erkanntes Datum landet in einer echten
  Erinnerung, und an eine Eingabeart gewöhnt man sich — hohes Risiko und hohe Bindung
  zugleich.

### Motivation und Darstellung (09.08.2026)

- **Tageszeit-Palette** — die Farbtemperatur von Fensterglas und Spaltenmulden folgt
  langsam der Tageszeit, mit Übergängen über Minuten; „Bewegung reduzieren" schaltet auf
  harte Wechsel. Es ist die einzige Form von Lebendigkeit, die eine Dauerfläche haben darf,
  ohne Aufmerksamkeit zu kosten, und bei den Apple Design Awards 2026 gleich zweimal
  prämiert (Tide Guide, Lumy). **Vorbehalt:** Das Kartenpapier darf nicht mitwandern — die
  Entkopplung von Karte und Umgebung war eine gemessene Entscheidung, keine ästhetische
  (CONCEPT.md, Design-Anspruch). Und die Vibe-Referenz verlangt eine ruhige, neutrale
  Farbgebung; der Wandel gehört ausschließlich ins Chrome.
- **Serie mit Ruhetag** — ein freier Tag je Woche beendet die Serie nicht. Die Änderung
  liegt vollständig in `StreakCalculator.swift`, ohne UI und ohne EventKit-Berührung.
  Empfohlen wird „ein Ruhetag je sieben Tage" statt „Wochenenden zählen nicht" — Letzteres
  unterstellt, wann jemand frei hat. **Vorbehalt:** Die Flamme ist heute wörtlich und rein
  abgeleitet; eine vergebende Regel macht sie freundlicher, aber weniger buchstäblich.
  Dafür spricht, dass eine nach einem freien Wochenende gerissene Serie genau das bestraft,
  was sie nicht bestrafen soll — und dass der Markt diese Bewegung gerade macht
  (Streak-Backlash; Gentler Streak hat für die vergebende Variante einen Apple Design Award
  bekommen).
- **Tagesrückblick** — beim ersten Öffnen des Statistik-Fensters an einem neuen Tag eine
  abgeleitete Belohnungszeile zum Vortag, an derselben Stelle und nach denselben Regeln wie
  der bestehende Meilenstein-Hinweis: nichts gespeichert, verschwindet von selbst.
  Ausdrücklich **kein Banner auf dem Board** — das wäre der abgelehnte Motivationssatz
  durch die Hintertür. Vorbild ist Sunsamas Shutdown-Ritual, die einzige konzeptionelle
  Lücke, die die Recherche im eigenen Konzept gefunden hat; als Moment zulässig, als
  Pflichtritual nicht.

## Karten-Anzeige (später ergänzen)

- **Prioritäts-Icon auf der Karte** — MVP zeigt nur Titel, Notizen-Vorschau und Fälligkeit, um
  die Karte bewusst reduziert zu halten. Dringlichkeit bleibt trotzdem als Filter nutzbar, nur
  nicht als Dauer-Badge auf jeder Karte.
- **Verantwortliche-Person-Avatar auf der Karte** — hängt am Verantwortliche-Person-Filter
  (s. u.), daher zusammen verschoben.
- **Eigene Hashtags aus den Notizen als Tag auf der Karte anzeigen** — wer Erinnerungen schon
  mit eigenen Hashtags kategorisiert (z. B. `#projektx`), sieht die aktuell nur als rohen Text
  in der Notizen-Vorschau. **Seit 13.08.2026 einfacher geworden:** Die App filtert keine
  Hashtags mehr heraus und reserviert auch keinen für sich — das damalige Hindernis
  (Kollision mit dem Status-Tag) ist mit dem Formwechsel weggefallen. Vorschlag: eigene Hashtags erkennen und als kleine
  Tag-Chips auf der Karte anzeigen statt/zusätzlich zur reinen Notizen-Vorschau. Bewusst nicht
  im MVP: Karte soll reduziert bleiben. Die frühere Begründung (Kollision mit dem internen
  Status-Tag) gilt seit dem Formwechsel nicht mehr; offen bleibt nur die Darstellung bei
  mehreren Tags.

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
  ein zweites Feld im eigenen Spaltenspeicher (`columns.json`) wäre heute der naheliegende
  Weg — die Spalten selbst benutzen seit 13.08.2026 keinen Hashtag mehr.
- **Mehrere Boards** — MVP ist bewusst ein einzelnes Board.
- **Board-/Workflow-Designer (Name noch offen)** — Idee (26.07.2026): Nutzer:innen können ihr
  Board individualisieren, statt nur den MVP-Standard mit vier festen Spalten zu bekommen.
  Vorstellung: die mittleren Spalten (aktuell "Ansteuern"/"In Bearbeitung" o. ä.) lassen sich
  umbenennen, und pro Spalte lässt sich ein eigenes WIP-Limit setzen statt nur des fest
  eingebauten Limits für "In Bearbeitung". **Backlog und Erledigt bleiben davon ausgenommen**
  — beide haben Sonderrollen im System (Backlog ist die Zulaufspalte ohne Limit, Erledigt hat
  den 7-Tage-Ruhezustand/Streak-Mechanismus, siehe SPEC.md), die sich nicht einfach umbenennen
  oder umkonfigurieren lassen, ohne diese Mechanik zu brechen. Erweitert/ersetzt die bisherige
  knappe Notiz "Konfigurierbare Spaltenanzahl/-namen". Noch zu klären: passender Name für das
  Feature, ob sich die Spaltenanzahl selbst auch ändern lässt oder nur Name+Limit der
  bestehenden mittleren Spalten. Die früher offene Frage nach dem Hashtag-Mechanismus hat
  sich erledigt: `ColumnState.Lane` speichert Rohwerte (`next`/`inProgress`), die von jedem
  Anzeigenamen unabhängig sind.
- **Manuelle Kartenreihenfolge innerhalb einer Spalte** — MVP sortiert automatisch nach
  Fälligkeitsdatum.

## Wiederkehrende Aufgaben (Reminders-Wiederholung)

- ~~**Verhalten wiederkehrender Erinnerungen beim Abhaken klären**~~ — am 08.08.2026 gegen
  echtes EventKit gemessen und beantwortet, ausgelöst von einem echten Fehler: ein
  wiederkehrendes Ticket stand nach dem Erledigen in „Als Nächstes". Antworten auf die drei
  offenen Fragen: (1) Der erledigte Durchgang wird als **eigene, abgelöste** Erinnerung
  abgelegt, die Serie läuft **unter derselben ID** mit dem nächsten Termin weiter — der
  „Erledigt"-Moment ist also sichtbar und dauerhaft, nur nicht an der ID, die das Board
  gezogen hat. (2) Der Status-Hashtag wurde sauber entfernt; die zurückkehrende Serie
  landet korrekt im Backlog, auch nach 90 s Beobachtung ohne iCloud-Rückschreiber (seit
  13.08.2026 über den eigenen Speicher statt über den Tag — Ergebnis unverändert). (3) Die
  Erledigung zählt zum Streak (echtes `completionDate`), fließt aber bewusst nicht in die
  Durchlaufzeit ein — siehe SPEC.md, „Durchlaufzeit bewusst gefenstert".
  Der eigentliche Fehler lag anderswo: Weil die ID nach dem Erledigen den *nächsten*
  Durchgang meint, schrieben wiedergespielte Undo-Schritte Status-Tags auf ungezogene
  Arbeit. Regel und Behebung stehen in SPEC.md, „Wiederkehrende Aufgaben beim Erledigen".
  **Verworfen wurde dabei**, das Erledigen einer Wiederholung „echt" rückgängig zu machen
  (erledigten Durchgang löschen, Fälligkeit der Serie zurückdrehen, Tag wiederherstellen):
  Das setzt voraus, dass die App die Wiederholungsregel korrekt rückwärts rechnet („jeden
  3. Dienstag") und einen Datensatz löscht, den sie nie angelegt hat — ein Rateschritt mit
  Datenverlust als Fehlerfall, für einen Sonderfall, den ein Satz Text ehrlich erklärt.
  **Nachtrag 09.08.2026:** Antwort (2) galt nur fürs Erledigen *in der App*. Extern
  abgehakt (iPhone, geteilte Liste) bleibt der Tag auf der weiterlaufenden Serie stehen —
  gemessen und behoben, siehe SPEC.md „Extern abgehakt" (`RecurringTagRelease`).
- ~~**Restlücke der Tag-Freigabe: Abhaken bei geschlossener App**~~ (09.08.2026, noch am
  selben Tag geschlossen) — die Freigabe-Regel braucht den vorigen Refresh als Beweis,
  dass niemand frisch gezogen hat (Bedingung 2). Statt beim Kaltstart aus Zeitstempeln zu
  raten (das hieße, ohne Beweis Karten zu verschieben — dieselbe Abwägung, an der schon
  das „Rückwärtsrechnen der Wiederholungsregel" oben gescheitert ist), **überlebt der
  Beweis jetzt den Neustart**: `RecurringTagRelease.Memory` persistiert am Ende jedes
  Refreshs die geladenen IDs und die getaggten Karten und seedet damit den ersten Refresh
  nach dem Start. Positiv- und Negativfall live gemessen: getaggte Serie extern abgehakt bei
  geschlossener App → Tag im ersten Refresh nach dem Neustart freigegeben; Tag erst bei
  geschlossener App gesetzt, dann extern abgehakt → Tag bleibt stehen (kein Beweis). Verbleibende,
  kleinere Restlücke (Hand-getippter Tag auf anderem Gerät nach externem Abhaken) steht in
  SPEC.md, „Extern abgehakt".
- ~~**Backlog-Sichtbarkeit wiederkehrender, noch nicht fälliger Karten**~~ — umgesetzt und am
  27.07.2026 grundlegend neu entschieden: solche Karten werden **nicht mehr ausgeblendet**,
  sondern sinken ans Ende des Backlogs, wo der Falz schneidet („N noch nicht fällig"). Grund:
  Ausblenden ist ein Push-Konzept und verhinderte genau das Vorziehen, für das ein Kanban-Board
  da ist. Filterzeile, Einstellung und Leer-Zustand dazu sind entfallen. Ein Schalter „Noch
  nicht Fälliges einklappen" (Einstellungen → Backlog, Standard an) wählt seit dem 27.07.2026
  zwischen zwei Falz-Schnitten — nicht mehr zwischen Sehen und Nicht-Sehen. Siehe SPEC.md,
  „Reifegrad statt Sichtbarkeit".

## Fremde Schreiber auf denselben Daten (10.08.2026)

Entstanden aus einem echten Fehlerbild: Ein Kalender-Client mit eigener Datenbank schob alle
19 bis 55 Minuten einen alten Datenstand zurück (erste Vermutung war eine selbstgebaute
Hausautomatisierungs-Brücke — per TCC geprüft und verworfen, siehe CONCEPT.md). Regel und
Messung stehen in SPEC.md („Eine Antwort je Zustand"), die Herleitung in CONCEPT.md. Was
dabei **geprüft und verworfen** wurde — nicht erneut vorschlagen, ohne dass der Nutzer das
Thema selbst öffnet:

- **Hinweis an den Nutzer, wenn das Board nachgibt** — verworfen am 10.08.2026 auf
  ausdrückliche Nutzerentscheidung. Der Nutzer soll von der Spaltenlogik nichts mitbekommen;
  ein Hinweis auf Datenmechanik zerstört die UX der ruhigen Dauerfläche. Begründung in
  CONCEPT.md.
- **Rückzug mit wachsendem Backoff und „Aufgeben"-Zustand** — verworfen: Das Phänomen wird
  in Perioden des fremden Schreibers gemessen (Dutzende Minuten), nicht in Sekunden; eine
  Wiederholungsleiter verbraucht sich, bevor der erste Rückschieber überhaupt eintrifft.
  Die Invariante „eine Antwort je Zustand" leistet dasselbe ohne Zeitkonstanten.
- **Verfallenen Pull über einen Fälligkeitssprung erkennen** (statt über die abgelöste
  erledigte Kopie) — verworfen: Ein Mensch verschiebt Fälligkeiten routinemäßig. Die Regel
  hätte eine Karte, deren Termin jemand von Hand aufschiebt, still aus der Arbeitsspalte
  geholt — ein Pull-Entzug ohne Beleg, also genau die verbotene Richtung. (Der damals
  verteidigte Auslöser — der frisch abgelöste erledigte Durchgang — ist am 13.08.2026
  selbst durch eine stehende Bedingung ersetzt worden; die Ablehnung dieser Idee gilt
  unverändert.)
- **Eigener `#backlog`-Tag** — verworfen, siehe CONCEPT.md: verteidigt die Entscheidung
  nicht, kostet aber sichtbaren Text in fremden Notizen. (Seit 13.08.2026 ohnehin
  gegenstandslos — es gibt keine Tags mehr.)
- **Eine Obergrenze für Antworten je Karte und Stunde** — geprüft, **bewusst offen
  gelassen** (10.08.2026, nach einer Messung am laufenden Board). Der dokumentierte
  Zehn-Minuten-Takt greift für den Status-Tag nicht: Sechs Rückschieber im
  Fünf-Sekunden-Takt wurden alle sechs binnen drei Sekunden beantwortet, weil das Board
  seine eigene Korrektur als neue Verdrängung bucht. Erwogen wurde, den feinen Takt durch
  ein grobes Budget zu ersetzen („höchstens N Antworten je Karte und Stunde") — im
  Normalfall unsichtbar (ein Kalender-Client schreibt 1–3× pro Stunde), aber eine Bremse
  für ein Programm, das im Sekundentakt schreibt. Nicht gebaut, weil das gemessene
  Verhalten die bessere Hälfte des Handels ist: Das Board eskaliert nicht von sich aus
  (es schreibt nur, wenn der Gegner schreibt, und ruht nachweislich, sobald der aufhört),
  und die Karte steht binnen Sekunden statt binnen Minuten richtig. Der pathologische Fall
  ist bislang hypothetisch. **Wieder aufgreifen, sobald ein Rückschieber im Sekundentakt
  tatsächlich auftritt** — dann ist das Budget der Weg, nicht ein längerer Takt.
- **`eventStore.reset()` bei jeder `EKEventStoreChangedNotification`** — verworfen: Ein
  Reset würde die gerade gehaltenen `openRecurringReminders` mitten im Flug ungültig
  machen; alle Messungen mit frischen Prozessen blieben ohnehin konsistent, ein
  veralteter EventKit-Cache war nie die Ursache.
- **Status-Tags optional in der Systemsprache schreiben** — verworfen am 10.08.2026. Ein
  Hashtag ist ein Datenformat, kein Oberflächentext: In geteilten Listen träfen zwei
  Sprachen aufeinander, Umlaute sind über fremde Systeme ein Kodierungsrisiko (die
  `ae`-Ersatzformen der Legacy-Tags sind der gelebte Beweis), und jede Umstellung löste
  einen Migrationslauf über fremde Daten aus. (Überholt am 13.08.2026: Die App schreibt
  überhaupt keine Tags mehr, und gelesen werden sie nur noch von der einmaligen Migration.
  Die Ablehnung bleibt als Begründung stehen, warum ein sichtbares Datenformat nie
  lokalisiert werden sollte.)

## Formwechsel: Status verlässt die Notizen (13.08.2026 — umgesetzt)

**Umgesetzt am 13.08.2026.** Gebautes Verhalten in SPEC.md („Spalten = eigener Speicher
der App", „Einmalige Migration der alten Hashtags"), Herleitung in CONCEPT.md. Der
Abschnitt bleibt als Begründungsspeicher stehen — vor allem die verworfenen Varianten
unten, die gegen einen Rückbau schützen.

Zwei Dinge kamen beim Bauen dazu, die hier nicht standen: Der Speicher gehört *einem*
Mac (zwei Rechner führen getrennte Spalten — dieselbe Eigenschaft, die fremde Programme
aussperrt), und im Editor musste die Tag-Filterung raus, weil sie sonst beim Speichern
fremden Notiztext auf schreibgeschützten Listen gelöscht hätte.

**Ursprüngliche Planungsnotiz (13.08.2026):** Entstanden aus dem
Geisterkarten-Komplex (PR #46): Solange der Spaltenstatus als Hashtag in den Notizen wohnt,
kann jedes Programm mit Schreibrecht auf Reminders eine Karte bewegen. Die seit 13.08.
stehende Abwehr (Zustandsregel, Ledger-Kette) deckt alle gemessenen Pfade ab — aber nur ein
Status, den kein fremdes Programm erreichen kann, macht Spaltensprünge **strukturell
unmöglich**. Herleitung und Prinzipien-Abwägung in CONCEPT.md („Geplanter Formwechsel").

**Zielbild:**

- Status (`next`/`inProgress`) liegt in einem app-eigenen, lokalen Speicher je
  Erinnerungs-ID (Application Support, gebundelt und tolerant gelesen wie
  `tagReleaseMemory`). Backlog bleibt „kein Eintrag", Erledigt bleibt `isCompleted` —
  gespeichert ist also nur, welche ein bis drei Karten gerade gezogen sind (das WIP-Limit
  begrenzt genau diese Menge). Unbekannte oder verwaiste IDs fallen nach Backlog — die
  sichere Richtung, die die App überall wählt.
- Die Notizen werden reiner Nutzerinhalt. Die App schreibt nie wieder in ein Feld, das
  auch anderen gehört (einzige Ausnahme bleibt `isCompleted` beim Erledigen).
- Die **stehende Freigaberegel bleibt**, nur lokal: Ein externes Abhaken lässt den lokalen
  Status der Serie zurück wie heute den Tag — jüngste Completion nach letztem Pull ⇒
  lokaler Status wird gelöscht. Ohne Reminders-Schreibung, ohne Zaun-Frage, ohne fremde
  Interferenz.
- Der `CorrectionLedger` bleibt unverändert für Titel, Notiztext, URL und Fälligkeit —
  der Formwechsel löst den Spaltensprung, **nicht den Notizverlust** (der Notiztext bleibt
  in Reminders und damit im Zugriff jedes Schreibers; das löst nur das Abstellen der
  Quelle, siehe „Fremde Schreiber").

**Was ersatzlos stirbt:** das Schreiben von Status-Tags, die Tag-Hygiene, die
Wortgrenzen-Erkennung als sicherheitskritische Stelle, die Notes-Richtungsregel des
Ledgers für Tags — ein erheblicher Teil der kompliziertesten Logik der App existiert nur,
weil der Status in fremdem Territorium wohnt.

**Was der Nutzer verliert (der Preis, ausdrücklich):** der mobile Pull — unterwegs
`#next` in die Reminders-Notizen tippen zieht dann nichts mehr. **Vorbedingung vor dem
Bau: der Nutzer bestätigt, dass er diesen Weg real nicht nutzt.** Die spätere iOS-App
(unten) bräuchte eigene Status-Synchronisation (CloudKit/iCloud-KV) statt sie über
Reminders geschenkt zu bekommen.

**Messungen vor dem Bau** (Projektregel: erst messen, dann bauen):

1. Stabilität von `calendarItemIdentifier` über iCloud-Resync, Geräteneustart,
   Listen-Umbenennung und **Listenwechsel** einer Erinnerung (bekannt riskant — Apple
   dokumentiert Wechsel als möglichen ID-Bruch). Fallrichtung bei Bruch ist Backlog,
   kostet einen Zug; gemessen werden muss, *wie oft* das praktisch eintritt.
2. Verhalten beim Weiterrollen einer Serie (ID bleibt laut Messung vom 08.08. erhalten —
   gegenprüfen, dass das auch über einen Resync gilt).

**Migrationsplan (einmalig, beim ersten Start des neuen Builds):**

1. Bestehende Tags lesen (kanonische und Legacy-Formen) und in den lokalen Speicher
   importieren.
2. Danach ein einmaliger, getakteter Aufräumlauf, der die Tags aus den Notizen entfernt
   (nur beschreibbare Listen; dieselbe Rücksicht wie jede Korrektur heute). Ab dann werden
   Tags weder geschrieben noch gelesen.
3. Kein Rollback-Pfad nötig: Der alte Build liest Notizen ohne Tags schlicht als Backlog.

**Geprüft und verworfen (13.08.2026) — nicht erneut vorschlagen:**

- **Inhaltsbasierte Kartenidentität** (Titel + Anlegedatum statt `calendarItemIdentifier`),
  um einen ID-Bruch zu „heilen" — verworfen: Eine inhaltsbasierte Identität kann eine
  Spalte an die *falsche* Karte hängen und damit genau die Bewegung erzeugen, die dieser
  Umbau unmöglich machen soll. Eine gebrochene ID kostet einen Zug, eine falsch geheilte
  kostet Vertrauen.
- **Den Speicher gegen den aktuellen Fetch aufräumen** (Einträge löschen, deren ID gerade
  nicht geladen ist) — verworfen aus demselben Grund wie beim `CorrectionLedger`: Eine in
  den Einstellungen abgewählte Liste, ein kurz offline gegangenes Konto oder ein
  Sync-Schluckauf nähme dem Board damit Arbeit weg, die der Nutzer selbst platziert hat.
  Verwaiste Einträge sind inert und fallen nur über die Mengengrenze heraus.
- **Tag-Text dauerhaft aus der Anzeige filtern** (damit auf schreibgeschützten Listen kein
  `#next` sichtbar wird) — verworfen: Die App versteckt keine Wörter mehr, die sie nicht
  selbst geschrieben hat. Der Text gehört der Person, der die Liste gehört.
- **Hybrid: lokal führend, aber neu auftauchende Notizen-Tags einmalig als Pull
  importieren** (hätte den mobilen Pull erhalten) — verworfen: Genau darüber könnte ein
  fremder Schreiber mit altem Notizen-Stand wieder Pulls injizieren; das Loch, das der
  Formwechsel schließen soll, wäre als „Import-Kanal" zurück. Der Wert des Formwechsels
  ist die harte Kante, nicht ein weiterer Filter.
- **Backup/Export des Pull-Zustands** — verworfen als unnötig: Der maximale Verlust ist
  der Inhalt zweier Arbeitsspalten unter WIP-Limit, wiederhergestellt in zwei Zügen.

## Undo bei Wiederholungen (10.08.2026)

Verworfen beim Umbau des Replay-Zauns auf eine Reihenfolge (Regel in SPEC.md,
„Wiederkehrende Aufgaben beim Erledigen"):

- **Undo-Einträge mit einem `Date` statt einer Ordnung stempeln** — verworfen: Eine Dauer
  müsste gegen Sync-Latenz und Arbeitstempo kalibriert werden und liegt auf beiden Seiten
  des gewählten Werts falsch; Zeitumstellung, Uhrabweichung und ein zurückgespieltes
  Einstellungsfile brechen sie zusätzlich. Vor allem ist die Fehlerrichtung falsch: Ein
  Zeitfenster läuft still ab und lässt den Schreibvorgang landen, eine Ordnung lehnt im
  Zweifel ab.
- **Den Undo-Stapel nach einer Wiederholungs-Erledigung abschalten** — verworfen (stand
  bisher nur im Code-Kommentar): Der Eintrag muss auf dem Stapel bleiben und von der
  Erklärung verbraucht werden, sonst greift das *nächste* ⌘Z in eine Änderung, die der
  Nutzer behalten wollte.
- **Den Zaun an den Aufrufstellen prüfen statt an der Registrierung** — verworfen: Genau so
  war es, und vier von sechs Schreibpfaden prüften nicht. Eine Invariante, die jeder neue
  Pfad erneut befolgen muss, ist keine.

## Zuordnung von Durchgang und Serie (10.08.2026)

Verworfen beim Umstieg von Titel auf Anlegedatum (Messung und Herleitung in CONCEPT.md, Regel in
SPEC.md):

- **Ein Toleranzfenster auf das Anlegedatum** („innerhalb von N Sekunden") — verworfen: Das
  machte aus einer Identität eine Ähnlichkeit. Gemessen trennen zwei in einem Rutsch
  angelegte Aufgaben nur Mikrosekunden; sie würden einander zu Durchgängen erklären.
  Gleichheit oder nichts, Mehrdeutigkeit fällt zu „kein Beweis".
- **Den Titel als zusätzliche UND-Bedingung behalten** — verworfen: Das ließe den
  Umbenennen-Fall offen (Serie nach dem Erledigen umbenannt → Schutz weg) und wäre damit
  strikt schlechter als das Anlegedatum allein.
- **`calendarItemExternalIdentifier` als Identität** — verworfen, gemessen: Die abgelöste
  Kopie bekommt eine eigene, und auf lokalen Listen fehlt das Feld ganz.
- **Für die Tag-Freigabe nur unter den getaggten Serien auf Eindeutigkeit prüfen** —
  verworfen: Diese eine Regel bewegt eine Karte, ohne dass jemand hinsieht. Sie prüft
  deshalb unter *allen* lebenden Serien der Liste; ein zusätzlicher Zweifel kostet dort
  einen Zug, ein übersehener eine gezogene Karte.

Akzeptierte Restlücke: Trügen zwei Serien einer Liste bitgenau dasselbe Anlegedatum, wäre
kein Durchgang zuzuordnen. Gemessen tritt das nicht ein — selbst fünf in einem Commit
geschriebene Erinnerungen kamen mit verschiedenen Anlegedaten heraus —, und der Ausgang
wäre ohnehin die sichere Richtung: kein Beweis, also keine Freigabe und kein verweigerter
Zug, sondern nur ein Tag, der einen Zug länger stehen bleibt.

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
- ~~**Return/Escape im Karten-Editor**~~ — **umgesetzt** (23.07.2026). Der Editor hatte
  keine Cancel-Geste: Escape wurde vom fokussierten Textfeld für sein eigenes „Bearbeitung
  abbrechen" geschluckt, und geschlossen wurde nur per Klick aufs Board — was speichert. Wer
  eine Karte versehentlich öffnete und hineintippte, kam nicht mehr heraus, ohne den Tippfehler
  zu speichern. Jetzt gilt im Editor dieselbe Regel wie beim Umbenennen: **Return übernimmt,
  Escape verwirft**, bei einer Neuanlage bricht Escape die Anlage ganz ab. Umgesetzt über
  einen lokalen Key-Monitor (`EditorKeyCommands`), der die Taste sieht, bevor die
  Responder-Kette sie bekommt; die Entscheidung selbst liegt testbar in `EditorKeyCommand`.
  Bewusst *nicht* gewählt: eine Rückfrage „Änderungen verwerfen?" — sie wäre der einzige
  modale Dialog des Boards, für einen Verlust, der bis zum Schließen ohnehin nur lokaler
  Formularzustand ist.
- **Wiederholungsregeln bearbeiten** — bleibt draußen: eigene, komplexe UI
  (täglich/wöchentlich/benutzerdefiniert…), die Reminders bereits gut löst. Der ↗-Knopf im
  Editor führt genau dafür in die native App.

## Onboarding / Ersteinstieg

- **Einführung in die App-Nutzung** — Idee (27.07.2026): eine Einführung für neue Nutzer:innen
  (z. B. Spaltenbedeutung, WIP-Limit, Drag & Drop) beim ersten Start. Ein Erklärgrund
  weniger seit 13.08.2026: Der Hashtag-Mechanismus, den man hätte erklären müssen, ist weg.
  **Offene Spannung, vor einer Umsetzung zu klären:** CONCEPT.md legt beim Chrome-Hover-Tipp-
  Konzept bewusst den Grundsatz „Wissen entsteht im Moment der Berührung, nicht über
  Onboarding" fest (Design-Anspruch, Abschnitt Hover-Tipps) — ein klassischer
  Onboarding-Flow (Klick-durch-Screens beim ersten Start) widerspräche dem direkt und wäre
  zudem der erste modale Ablauf der App. Käme also nur infrage, wenn er sich an diese Haltung
  anpasst statt sie zu ersetzen — z. B. eine einmalige, zurückhaltende Übersicht statt einer
  mehrschrittigen Tour, oder Wissen weiterhin punktuell am Ort des Bedarfs statt vorab
  gebündelt. Nicht umsetzen, ohne diesen Grundsatz bewusst gegeneinander abzuwägen.

## Spätere Apple-/Mac-Ausbaustufen

- **Widget (WidgetKit, Mac + iPhone)** — kompakte Ambient-Ansicht des aktuellen Kanbanboards
  auf dem Schreibtisch (Mac) bzw. Homescreen/Sperrbildschirm (iPhone), ergänzend oder
  alternativ zum offenen Fenster. Idee (27.07.2026): Muss die stark eingeschränkte
  Widget-Größe von vornherein mitdenken statt einer verkleinerten Kopie des Boards — eher
  eine eigene, radikal reduzierte Darstellung (z. B. nur Zahlen/Kompaktkarten statt echter
  Spalten). Die iPhone-Variante setzt die begleitende iOS-App voraus, siehe unten
  „Plattform-Erweiterung: iOS-App". **Ergänzung (03.08.2026), inspiriert von MonoNote
  (digitalminimalist.com/tools/mononote):** Die radikalste Reduktion wäre nicht „Board im
  Kleinformat", sondern MonoNotes Prinzip „one note at a time" — das Widget zeigt genau
  **eine** Karte: die oberste dringliche bzw. die oberste aus „Als Nächstes". Das wäre
  konsequenter als Zahlen/Kompaktkarten (eine Zahl beantwortet „wie viel?", eine einzelne
  Karte beantwortet „was jetzt?") und deckt sich mit der eigenen Haltung, dass Fokus aus dem
  Karteninhalt kommt. Beide Darstellungen (eine Karte vs. Kennzahlen) gegeneinander abwägen,
  wenn das Widget konkret wird. **Prinzipien-Check (03.08.2026):** Minimalismus und
  Psychologie sprechen für die Eine-Karte-Variante („was jetzt?" senkt Entscheidungslast,
  ohne Push). Das Kanban-Prinzip „keine Karte wird zum Favoriten erklärt" (CONCEPT.md,
  Pull-Signal) setzt aber eine Bedingung: Die eine Karte muss aus der bestehenden
  Board-Ordnung folgen (oberste nach automatischer Sortierung), nie aus einer neuen
  Auszeichnungs-Logik. Kanban-rein wäre alternativ, dass das Widget bei freiem
  „In Bearbeitung"-Platz genau die bestehende Einladung zeigt („Frei für die nächste
  Aufgabe") — dieselbe Regel „höchstens eine Einladung, nur wo Nichtstun etwas kostet",
  nur an einem zweiten Ort.
  **Gewicht gestiegen (09.08.2026):** Das Widget ist nicht nur eine Mac-Nebenansicht,
  sondern das einzige technische Mittel, mit dem die App außerhalb ihres Fensters überhaupt
  präsent sein kann — auf dem Mac-Schreibtisch ebenso wie später im StandBy des iPhones
  (siehe die Korrektur dort). Es trägt damit die Positionierung „ruhige Fläche im
  Schreibtisch-Setup". Bauvorgabe daraus: von vornherein als Widget-Familie denken, die
  auch in einem StandBy-Stack im Querformat funktioniert — nicht als verkleinertes Board.
- **Interaktives Widget (App Intents)** — Idee (27.07.2026), baut auf dem Widget-Punkt oben
  auf: Seit iOS 17/macOS Sonoma können Widgets Buttons enthalten, die ohne App-Start etwas
  auslösen. Für ein bewusst überwiegend read-only Board wäre die einzig stimmige Aktion die,
  die es auch in der App bereits gibt — eine Karte direkt aus dem Widget nach „Erledigt"
  abhaken. Kein neues Bedienkonzept, nur derselbe eine erlaubte Schreibzugriff an einem
  zweiten Ort.
- **Apple-Watch-Komplikation** — Idee (27.07.2026): Streak-Flamme oder WIP-Auslastung als
  Zifferblatt-Komplikation. Reine Anzeige aus bereits vorhandenen, rein lesend berechneten
  Werten (`completionDate`-Auswertung, siehe Statistik-Fenster) — keine neuen Daten, keine
  neue Schreiblogik, dieselbe Zurückhaltung wie der bestehende Streak-Zähler im Fensterrahmen.
- **Ambient-Screensaver-Modus (Mac)** — Idee (27.07.2026): Bei längerer Inaktivität geht das
  Board in eine noch ruhigere, rein dekorative Ansicht über, passend zum
  „Minimal-Desk-Setup"-Vibe für einen Bildschirm, der sonst idle wäre. Eher ein stilistischer
  Zusatz als ein Produktivitäts-Feature — Nice-to-have, kein Blocker für irgendetwas anderes.
- **Shortcuts-App/App Intents** — z. B. Karte per Kurzbefehl/Automation verschieben oder
  Kennzahlen abfragen.
- **Fokus-Modi-Integration (Focus Filters)** — Board passt Filter automatisch an aktiven
  macOS-Fokus an (z. B. Arbeit vs. Privat).
- **App-Icon: Tinted-Variante ergänzen** — Light und Dark sind umgesetzt
  (`GlassKanban/AppIcon.icon`, Icon-Composer-Dokument); die Tinted-Darstellung für
  eingefärbte Docks fehlt noch als dritte Appearance.

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

## Gerätesynchronisation über iCloud (14.08.2026 — in Arbeit)

Auf Nutzerentscheidung beschlossen, nachdem eine erste Prüfung zur Zurückstellung geraten
hatte. Die Gegenargumente stehen unten unter „Bewusst in Kauf genommen"; sie sind entkräftet
oder bezahlt, nicht vergessen.

**Was es löst.** Bis 13.08.2026 war die Spalte geräteübergreifend, weil sie als Hashtag in
den Notizen stand und Notizen über iCloud synchronisieren (CONCEPT.md nennt das unter den
Argumenten *gegen* den Formwechsel). Der Formwechsel hat diese Eigenschaft bezahlt. Die
Synchronisation holt sie zurück, ohne den alten Preis erneut zu zahlen: kein sichtbares
Datenformat in fremden Notizen, keine Angriffsfläche für fremde Schreiber.

Der methodisch wichtigste Punkt ist nicht der Komfort: **Ein WIP-Limit, das pro Gerät
zählt, ist keines.** Zwei Macs mit Limit 3 erlauben real sechs begonnene Aufgaben, und der
WIP-Dialog — das dokumentierte Reibungs-Muster — greift nie. Dazu kommt die Verweildauer,
die heute nur der ziehende Mac exakt kennt; der zweite fällt auf die
`lastModifiedDate`-Näherung zurück und zeigt damit eine andere Zahl für dieselbe Karte.

### Messung vom 14.08.2026 (Projektregel: erst messen, dann bauen)

Swift-CLI gegen die echten Listen dieses Macs, 2509 Erinnerungen in 4 Listen, alle iCloud
(calDAV). Ausgewertet wurden nur Aggregate, keine Titel.

| Frage | Ergebnis |
|---|---|
| Hat jede Erinnerung einen `calendarItemExternalIdentifier`? | **ja, 2509 von 2509** |
| Ist er eindeutig? | **ja** — 2509 verschiedene Werte, keine Kollision, auch nicht bei den 9 wiederkehrenden |
| Welche Form? | **nackte UUID** — nicht die von `ReminderDeepLink` als typisch beschriebene Form `x-apple-reminder://<UUID>`. Der Code deckt beide ab, die Beschreibung dort ist also unvollständig, nicht falsch |
| `calendarItemIdentifier` vs. `calendarItemExternalIdentifier` | **bei allen 2509 zeichengleich** |

**Die letzte Zeile ist der Befund, der den Plan verkleinert:** Die Schlüssel in
`columns.json` *sind* bereits die externen Bezeichner. Die geplante Umschlüsselung
(ursprünglich Phase B, mit Migration über alle Listen und dem Risiko, die Spalten
abgewählter Listen zu verlieren) entfällt ersatzlos. Sie erklärt nebenbei die Messung vom
13.08.: Der Bezeichner überlebt Listenwechsel und kalten Cache, weil er die
synchronisierte Record-UUID ist.

**Was das über M1 sagt — und was nicht.** Ist der lokale Bezeichner zeichengleich mit dem
externen, und ist der externe die synchronisierte Identität, dann ist er auf einem zweiten
Mac derselbe. Das ist ein starkes Indiz, **kein Messergebnis**: Es braucht weiterhin zwei
Macs. Bis dahin gilt der Vorbehalt.

**Offen, weil auf einem Mac nicht messbar:**

1. **M1** — ist `calendarItemExternalIdentifier` auf zwei Macs für dieselbe Erinnerung
   identisch? Fällt das negativ aus, trägt der ganze Weg nicht.
2. **M4** — ist `EKCalendar.calendarIdentifier` über zwei Macs identisch? Entscheidet, ob
   `excludedCalendarIDs` synchronisierbar ist. `EKCalendar` hat kein Gegenstück zum
   externen Bezeichner; fällt M4 negativ aus, bliebe nur Titel + Quelle — oder die
   Einstellung bleibt bewusst lokal (die derzeit bevorzugte Antwort: welche Listen auf
   welchem Rechner sichtbar sind, ist plausibel eine Gerätefrage).
3. **M5** — Latenz und Konfliktverhalten des KV-Speichers in der Praxis.

Die Messwerkzeuge liegen im Scratchpad der Sitzung und sind bei Bedarf neu zu erzeugen;
sie geben nur Aggregate aus und lesen nie Titel.

### Was wohin gehört

Die Klassifikation ist der eigentliche Ertrag — der Übertragungscode ist danach klein.
**Vor jedem neuen persistierten Wert ist diese Tabelle zu ergänzen**, statt die Frage je
Feature neu zu stellen.

| Zustand | Ort heute | Klasse |
|---|---|---|
| `pulls` (Spalten) | columns.json | geräteweit |
| `released` (Ablage-Vermerke) | columns.json | geräteweit |
| `importedLists` | columns.json | geräteweit — die Migration ist Eigenschaft der *Daten* |
| `wipLimits` | UserDefaults | geräteweit |
| `foldNotYetDue` | UserDefaults | geräteweit |
| `excludedCalendarIDs` | UserDefaults | offen, hängt an M4 |
| `appAppearance` | UserDefaults | lokal — Bildschirm im Büro ≠ zu Hause |
| `completionSoundEnabled` | UserDefaults | lokal — Kopfhörer am Laptop |
| `correctionLedger` | UserDefaults | **strikt lokal** |
| `tagReleaseMemory` | UserDefaults | strikt lokal |
| `pendingTagCleanup` | columns.json | lokal — Arbeitsliste dieses Prozesses |
| Fenstergeometrie | AppKit | lokal |
| künftige Ansichts-Einstellungen (Bildschirmzuordnung, Darstellungsgröße, Fokus-Filter, Tageszeit-Palette) | — | lokal |

**Warum der `CorrectionLedger` niemals synchronisiert werden darf.** Er merkt sich, welche
Werte *dieses* Board verdrängt hat. Synchronisiert schriebe Mac A einen Wert zurück, den
Mac B gerade absichtlich geändert hat — zwei Boards, die einander als fremden Schreiber
behandeln und auf echten Nutzerdaten in eine Schreibschleife laufen. SPEC.md führt „einen
zweiten Mac mit derselben App" ausdrücklich als zweiten Schreiber; diese Rolle bleibt.

Dazu die gute Nachricht: Seit dem Formwechsel schreibt ein Spaltenzug überhaupt nicht mehr
in EventKit. Zwei Macs können beliebig ziehen, ohne sich über Reminders je zu begegnen —
der Formwechsel hat die Synchronisation nicht erschwert, sondern erst sauber möglich
gemacht.

### Speicher und Zusammenführung

**`NSUbiquitousKeyValueStore`, nicht CloudKit.** Nutzlast rund 12 KB gegen 1 MB Budget;
kein Schema, keine Zonen, keine Subscriptions, minimale Review-Fläche. Ohne
iCloud-Anmeldung liefert der Speicher leer und alles läuft lokal weiter — „funktioniert
vollständig ohne iCloud" bleibt wahr. Die genauen Grenzen vor dem Bau gegen die aktuelle
Apple-Doku prüfen.

**Einstellungen:** UserDefaults bleibt der Lesepfad (schnell, offline), KV ist nur der
Transport. Schreiben in beide; bei `didChangeExternallyNotification` die geänderten
geräteweiten Schlüssel nach UserDefaults spiegeln und publishen. Konflikt: last-writer-wins
ohne Zeitstempel — bei Präferenzen, die man selten anfasst, angemessen.

**Spalten:** je Karte gewinnt der jüngere Zeitstempel. Umgesetzt als reine Funktion
`ColumnState.merged(_:_:now:)`, Regeln und Grenzen dort dokumentiert und durch
`ColumnStateTests` festgenagelt. Drei Punkte, die nicht offensichtlich sind:

- **Abwesenheit ist keine Antwort.** Ein Gerät, das eine Karte nie gesehen hat, sagt nichts
  über sie — sonst löschte jeder zweite Mac beim ersten Sync alle Pulls.
- **Deshalb `released`.** Ein zurückgenommener Pull war bisher die *Abwesenheit* eines
  Eintrags und trug kein Datum; ein alter fremder Pull hätte ihn wiederbelebt — genau die
  verbotene Richtung. Der Vermerk liegt bewusst **neben** `pulls`, nicht darin, damit die
  Zusicherung „das Format kann Backlog nicht ausdrücken" wörtlich gilt. Er verfällt nach
  30 Tagen, danach spricht die Abwesenheit wieder für sich.
- **Gleichstand geht nach Backlog**, und die Regel ist symmetrisch — sonst einigten sich
  zwei Macs auf verschiedene Boards und überschrieben einander endlos.

**Die Falle bei der Tag-Migration:** Läuft sie auf dem zweiten Mac, erzeugt sie Einträge
mit `at = jetzt` und gewinnt damit gegen ältere, legitime Züge. Ihr Zeitstempel muss aus
`lastModifiedDate` der Erinnerung kommen. Noch offen (Phase D).

### Wie viel der Nutzer davon sieht (14.08.2026 entschieden)

**Haltung: nichts.** Der Präzedenzfall steht in diesem Dokument unter „Fremde Schreiber" —
der Hinweis, wenn das Board nachgibt, wurde am 10.08.2026 verworfen, weil der Nutzer von
der Spaltenlogik nichts mitbekommen soll und ein Hinweis auf Datenmechanik die ruhige
Dauerfläche zerstört. Synchronisation ist derselbe Fall: Mechanik, die ihre Arbeit tut.

**Einblick hat er an drei Stellen, die alle nicht der App gehören** — und das ist die
richtige Verteilung: Systemeinstellungen → Apple-ID → iCloud → iCloud Drive → Apps (dort
liegt auch der Ausschalter), die Datenschutzangaben im App Store, und der zweite Mac
selbst. Der beste Einblick sieht aus wie ein Ergebnis, nicht wie ein Mechanismus.

**Wird nicht gebaut:**

- **Kein eigener Ein/Aus-Schalter.** Es gibt ihn systemweit bereits; zwei Schalter für
  dieselbe Sache können sich widersprechen, und der zweite erklärt sich nur über Mechanik.
  Notizen, Erinnerungen und Freeform halten es genauso.
- **Keine Statuszeile** („Zuletzt synchronisiert 14:32") — Dauer-Chrome für einen
  Dauerzustand, gegen „Aufmerksamkeit gehört Ereignissen".
- **Kein Einrichtungsdialog** beim ersten Start. Es gibt nichts einzurichten.
- **Keine Fehlermeldung** bei gescheiterter Übertragung. Dieselbe Doktrin wie beim
  Speicher: kein Dialog, eine Zeile in der Konsole, ein Zug repariert es.
- **Kein Hinweis**, wenn iCloud aus ist. Es fehlt nichts, was der Nutzer angefordert hätte.

**Die vier Momente, in denen die Technik doch durchschlägt:**

| Moment | Unbehandelt | Maßnahme |
|---|---|---|
| Karte wechselt die Spur, weil der andere Mac gezogen hat | wirkt wie ein Geist oder ein Fehler | dieselbe Settle-Animation wie bei einem eigenen Zug |
| Erststart auf dem zweiten Mac | Board steht kurz falsch, dann springen Karten | kurz auf den Speicher warten, bevor gezeichnet wird — wie bei großen Datenbanken schon üblich |
| Konflikt oder schiefe Uhr | Karte liegt woanders als erwartet | nichts sagen, ein Zug repariert es |
| iCloud abgemeldet | — | nichts sagen |

Daraus die Regel, die bei der Umsetzung gilt:

> **Fremde Bewegung wird gezeigt, nicht gemeldet.** Sie bekommt die Animation, damit sie
> als Vorgang lesbar ist statt als Sprung — aber **nicht** Klang und Haptik aus
> `MoveFeedback`. Die gehören der eigenen Hand; ein Ton für eine Bewegung, die woanders
> passiert ist, wäre eine Benachrichtigung, und eigene Benachrichtigungen sind ausdrücklich
> abgelehnt. Belohnung bleibt an das eigene Tun gekoppelt.

**Die eine Stelle, an der Schweigen unehrlich wäre.** Datenhoheit ist ein Kernversprechen;
der Nutzer muss *wissen können*, dass die Spalten seine iCloud benutzen, auch wenn er es nie
sehen muss. Ein Satz in den Einstellungen, kein Schalter, keine Statuszeile:

| Naheliegend (technisch) | Beschlossen |
|---|---|
| „iCloud-Synchronisation aktiviert · Zuletzt synchronisiert: 14:32" | *(entfällt)* |
| „Spalten werden über iCloud mit deinen anderen Macs synchronisiert." | **„Deine Spalten stehen auf allen deinen Macs — über deine iCloud."** |
| „Synchronisierung fehlgeschlagen. Bitte iCloud-Einstellungen prüfen." | *(entfällt)* |
| „iCloud ist nicht verfügbar." | *(entfällt)* |

Quelltext (Entwicklungssprache Englisch): „Your columns are on all your Macs, through your
iCloud." Geprüft gegen „Ton der Texte" in CONCEPT.md: benennt statt zu kommentieren, nennt
den Besitz, verspricht nichts, verteidigt nichts, Punkt hinter vollständigem Satz. Das Wort
„iCloud" bleibt bewusst stehen — es ist die eine Mechanik, die man kennen muss, um sie
abschalten zu können; sie zu verschweigen wäre teurer als ein technisches Wort.

**Offen:** Der Satz sagt „Macs", nicht „Geräte". Sobald die iOS-App existiert, ist er
umzuformulieren — bis dahin wäre „Geräte" ein Versprechen, das die App nicht einlöst.

### Phasen

| Phase | Inhalt | Braucht Developer Program? | Stand |
|---|---|---|---|
| M | Messungen | nein | teilweise erledigt 14.08.2026, M1/M4/M5 offen |
| ~~B~~ | ~~Umschlüsselung auf externen Bezeichner~~ | — | **entfällt** — Schlüssel sind bereits identisch |
| C | `released` + `merged(_:_:now:)` als reine Funktion samt Tests | nein | **erledigt 14.08.2026** |
| A | Speicher in App-Group-Container | **ja, wegen Xcode** | Lese-/Kopiermechanik gebaut 14.08.2026; Entitlement wartet auf Phase 0 |
| D | KV-Anbindung, Entitlement, Migrations-Zeitstempel, fremde Bewegung animiert (s. o.) | **ja** | offen |
| E | `SettingsSync` nach obiger Tabelle | ja | offen |
| F | CONCEPT/SPEC/README/PrivacyInfo/RELEASE nachziehen | nein | teilweise |

**Warum A vor D und nicht später:** `columns.json` liegt im Sandbox-Container der App.
Widget, Live Activity und App Intents laufen in eigenen Prozessen und erreichen diesen Pfad
**nicht** — alle drei stehen in diesem Dokument. Der Umzug ist jetzt billig; später
bedeutet er eine Migration von Nutzerdaten im Feld.

**Gemessen am 14.08.2026: App Groups funktionieren mit der selbstsignierten
Entwicklungsidentität.** Ein minimales, sandboxed `.app`-Bundle, signiert mit „Glass Kanban
Development" (`TeamIdentifier=not set`), bekam für alle drei getesteten Formen einen
Container samt Schreib-Lese-Rundlauf — `group.com.davidtrogemann.GlassKanban`,
`com.davidtrogemann.GlassKanban.group` und `group.GlassKanban`, jeweils unter
`~/Library/Group Containers/`. Ein Team-Präfix ist lokal **nicht** nötig, Phase 0 also keine
Voraussetzung für Phase A. (Nebenbefund: Ein nacktes Mach-O mit `app-sandbox` stirbt beim
Start an SIGTRAP — der Test braucht ein echtes Bundle. Die Testcontainer wurden nach der
Messung entfernt.)

**Was das nicht beantwortet, und was daraus folgt:** Ob der Mac App Store dieselbe Form
akzeptiert oder das Team-Präfix (`<TeamID>.group.…`) verlangt, ist damit **nicht** geklärt —
das entscheidet sich erst mit Phase 0 und ist vor dem Einreichen gegen die dann aktuelle
Apple-Dokumentation zu prüfen. Ein späterer Wechsel der Group-ID wäre ein zweiter Umzug,
also genau das, was Phase A vermeiden soll. Der Umzug ist deshalb so zu bauen, dass er das
aushält:

- Die Group-ID steht an **einer** Stelle als Konstante, nicht verstreut.
- Der Lesepfad probiert der Reihe nach: aktueller Group-Container, dann jeder früher
  benutzte Ort (heutiges Application Support). Gefunden wird der erste, der etwas hergibt.
- Geschrieben wird nur an den aktuellen Ort; der alte bleibt zunächst liegen, statt gelöscht
  zu werden. Ein Rollback kostet dann nichts, und ein ID-Wechsel ist ein Einzeiler plus ein
  weiterer Lesepfad statt einer Datenmigration.

Empfohlene Form: `group.com.davidtrogemann.GlassKanban` — die iOS-Konvention, damit die
spätere iOS-App denselben Bezeichner benutzen kann.

**Zweiter Befund vom 14.08.2026, der Phase A halbiert: Xcode blockiert, wo macOS erlaubt.**
Trägt das Ziel `com.apple.security.application-groups`, bricht der Build mit „requires a
provisioning profile" ab — auch mit leerem `PROVISIONING_PROFILE_SPECIFIER` und leerem
`DEVELOPMENT_TEAM`. Ein Profil setzt das Developer Program voraus. **Phase A ist damit
doch an Phase 0 gebunden**, nicht wegen macOS, sondern wegen der Toolchain.

*Geprüft und verworfen:* das Entitlement aus dem Xcode-Build herauszuhalten und das Bundle
in `scripts/build-app.sh` nachzusignieren (technisch belegt — genau so lief die Messung).
Es entstünden zwei Signierpfade, und Builds des einen Wegs schrieben das Board an einen
anderen Ort als Builds des anderen. Das ist ein realer Weg, Züge zu verlieren, eingetauscht
gegen einen Nutzen, den es noch gar nicht gibt: Es existiert kein Widget.

**Gebaut wurde deshalb nur die Hälfte, die nichts kostet** (14.08.2026): Der Bezeichner
steht als eine Konstante, `ColumnState.knownFileURLs` liest der Reihe nach vom
Group-Container und vom heutigen Ort, `defaultFileURL` fällt auf den heutigen Ort zurück,
wenn kein Group-Container verfügbar ist, und `copyColumnsToCurrentLocationIfNeeded` kopiert
beim Start, sobald sich der Zielort ändert. Am Verhalten der App ändert das heute nichts —
ohne Entitlement liefert der Group-Container nichts und alles läuft wie bisher. Sobald
Phase 0 steht, ist das Hinzufügen der Entitlement-Zeile in `project.yml` die **ganze**
Änderung.

**Bekannte Grenze dieser Zwischenform:** „Erster gefundener Ort gewinnt" ist nur richtig,
solange alle Builds an denselben Ort schreiben. Wechselten Builds mit und ohne Entitlement
einander ab, könnte der ältere Stand gewinnen. Das ist ein Entwicklungs-, kein
Nutzerszenario; tritt es je auf, ist die Antwort „jüngste Datei gewinnt" statt
„erste in der Liste".

### Aufräumen der alten Speicherorte

Der Umzug lässt bewusst Kopien liegen — ein Rollback soll nichts kosten. Diese Kopien sind
aber genau das, was am Ende niemand haben will, deshalb steht hier von Anfang an, was wann
verschwindet. Ohne diesen Abschnitt zeigen zwei Code-Kommentare ins Leere
(`ColumnState.knownFileURLs`, `RemindersStore.copyColumnsToCurrentLocationIfNeeded`).

**Was am Ende herumliegt:**

| Rest | Ort | Entsteht durch |
|---|---|---|
| `columns.json` (alt) | `…/Containers/com.davidtrogemann.GlassKanban/Data/Library/Application Support/GlassKanban/` | Phase A, sobald der Group-Container aktiv ist |
| `columns.json` (erste Group-Form) | `~/Library/Group Containers/group.com.…/` | nur falls der Store ein `<TeamID>.group.…`-Präfix erzwingt |
| Lesepfad-Einträge für tote Orte | `ColumnState.knownFileURLs` | jede Ortsänderung |
| `copyColumnsToCurrentLocationIfNeeded` | `RemindersStore` | Phase A |

**Bedingung, unter der gelöscht werden darf** — alle drei müssen erfüllt sein:

1. Der neue Ort ist mindestens **eine veröffentlichte Version** in Betrieb.
2. Es existiert kein unterstützter Build mehr, der an den alten Ort schreibt.
3. Der Löschlauf hat unmittelbar zuvor **erfolgreich vom neuen Ort gelesen**. Ohne diese
   Bedingung löscht ein Fehlstart die letzte gute Kopie — dieselbe Vorsicht, mit der die
   Tag-Migration nur schneidet, was sie zuvor namentlich vermerkt hat.

**Wie gelöscht wird:** einmalig, still, ohne Dialog, ohne Fortschrittsanzeige — es ist
Datenmechanik, und dafür gilt die Haltung aus „Wie viel der Nutzer davon sieht". Scheitert
das Löschen, bleibt die Datei liegen und es wird beim nächsten Start erneut versucht; eine
Datei zu viel hat noch nie jemandem geschadet, eine zu wenig schon.

**Was ausdrücklich nicht aufgeräumt wird:** verwaiste Einträge *innerhalb* des Speichers
(Karten, deren Bezeichner gerade nicht auflöst). Die Begründung steht oben unter „Geprüft
und verworfen (13.08.2026)" und gilt unverändert — eine abgewählte Liste oder ein
Sync-Schluckauf nähme dem Board sonst Arbeit weg, die der Nutzer selbst platziert hat. Die
Mengengrenze von 200 Einträgen ist die einzige Bereinigung, die es gibt.

**Verwandter, schon vorgemerkter Fall:** `StatusTagger.swift` entfällt mit der Aufräumung
der Tag-Migration, frühestens eine Version nach 1.0 (CLAUDE.md). Beide Aufräumungen haben
dieselbe Bedingung — „eine Version lang stabil" — und sollten in einem Zug erledigt werden,
statt zweimal dieselbe Vorsicht zu buchstabieren.

### Bewusst in Kauf genommen

- **Das Versprechen ändert sich.** CONCEPT.md, README und der künftige Store-Text sagen
  heute „keine Netzwerkaufrufe". Präzise bleibt: kein eigener Server, kein Konto in der App,
  keine Analyse, voll funktionsfähig ohne iCloud. Vor 1.0 zu überarbeiten (Phase F).
- **Eine Karte kann sich bewegen, ohne dass hier jemand sie gezogen hat.** Abwägung in
  CONCEPT.md, „Korrektur dieser Begründung (14.08.2026)".
- **Uhrenschiefe entscheidet Gleichstände.** Bei normal synchronisierten Rechnern Sekunden,
  Züge liegen Minuten auseinander. Eine grob falsche Uhr kostet einen Zug.
- **Karten in „Auf meinem Mac"-Listen bleiben ausgeschlossen.** Sie haben keinen externen
  Bezeichner und existieren auf dem zweiten Gerät ohnehin nicht — die Grenze, an der
  EventKit den Bezeichner verweigert, ist genau die, an der Synchronisation gegenstandslos
  wird. Dieser Mac hat derzeit keine solche Liste; die App muss den Fall trotzdem behandeln
  (Karten ohne externen Bezeichner gehören in den lokalen Schlüsselraum).

### Nicht gelöst, ausdrücklich

Mehrgeräte heißt hier **mehrere Macs**. iPhone und iPad brauchen die App aus dem nächsten
Abschnitt; diese Arbeit ist deren Voraussetzung, nicht ihr Ersatz. Der mobile Pull bleibt
bis dahin aus.

## Plattform-Erweiterung: iOS-App

- **Begleitende iOS-App (iPhone + iPad)** — eigene Glass-Kanban-Ansicht auf iPhone/iPad.
  Seit dem Formwechsel vom 13.08.2026 **die einzige Möglichkeit, unterwegs zu ziehen**: Der
  Weg über Hashtags in der Reminders-App ist entfallen. Braucht deshalb eine eigene
  Status-Synchronisation (CloudKit/iCloud-KV), die es vorher geschenkt gab. Eigenes Xcode-Multiplatform-Target, eigene
  UI-Anpassung für kleinere Bildschirme/Touch-Bedienung, eigene App-Store-Überlegungen — klare
  Plattformerweiterung nach dem Mac-MVP, nicht Teil davon.
- **Ausrichtungsabhängige Ansicht (iPhone)** — Idee (27.07.2026) für die begleitende iOS-App
  oben: Querformat zeigt das gewohnte Kanbanboard, Hochkant zeigt etwas anderes. Kandidaten
  fürs Hochkant-Format: Statistiken/Winning-Streak, nur die aktuell fälligen Aufgaben, oder
  eine Kombination aus beidem — noch zu evaluieren, welche Hochkant-Ansicht am meisten Sinn
  ergibt. Setzt die App oben voraus, ist also selbst kein eigenständiges Feature.
- **StandBy-Modus (iPhone quer + Laden)** — Idee (27.07.2026), praktisch die offizielle
  Apple-Antwort auf den Punkt oben: Apple hat mit StandBy bereits ein System dafür, dass ein
  liegendes/ladendes iPhone im Querformat eine große, glanceable Ansicht zeigt. Board als
  StandBy-taugliche Ansicht bauen, statt eine eigene Querformat-Logik von Grund auf zu
  entwerfen. Setzt ebenfalls die begleitende iOS-App voraus. **Präzisierung (27.07.2026):**
  StandBy soll optisch genau die normale Querformat-Ansicht des Boards zeigen (die aus dem
  Punkt oben), nur ohne jegliche Bedienelemente — reine Anzeige, kein Chrome, kein Drag & Drop.
  Passt zur bestehenden Haltung „Glas ist Chrome, nie Inhalt": StandBy ist der Moment, in dem
  nur noch der Inhalt bleibt.
  **Korrektur (09.08.2026) — die Präzisierung vom 27.07.2026 ist technisch nicht umsetzbar:**
  StandBy erlaubt Drittanbietern keine eigene Vollbild-Ansicht. Apps sind dort ausschließlich
  über WidgetKit-Widgets und Live Activities präsent (so lösen es Structured, TickTick und
  Flighty). „Das Board im Querformat ohne Bedienelemente" gibt es also nicht; was es gibt,
  ist **eine Karte** — und damit genau die Variante, die oben beim Widget und bei der Live
  Activity bereits prinzipiengeprüft ist (MonoNote-Ergänzungen vom 03.08.2026). Die
  Plattform-Grenze bestätigt die eigene Haltung, statt sie zu behindern. Vor einer Umsetzung
  gegen die dann aktuelle Apple-Dokumentation gegenprüfen; Grundlage dieser Korrektur ist
  eine Recherche, kein eigener Test.
- **Live Activity** — Idee (27.07.2026): z. B. „In Bearbeitung: 2/3" als Dauerpräsenz auf dem
  Sperrbildschirm/in der Dynamic Island während einer aktiven Arbeitssession. **Offene
  Spannung, vor einer Umsetzung zu klären:** Eine Live Activity ist keine Benachrichtigung,
  grenzt aber an den bestehenden Ausschluss „Eigene Push-Benachrichtigungen der App" (s. u.,
  „Explizit abgelehnt") und an den Grundsatz „Bewegung/Aufmerksamkeit gehört Ereignissen,
  nicht Dauerzuständen" (CONCEPT.md, Motivation). Käme also nur infrage, klar auf einen
  begrenzten Moment beschränkt (z. B. nur während aktiv an „In Bearbeitung" gearbeitet wird),
  nicht als dauerhaftes Banner — sonst widerspricht sie der eigenen Philosophie.
  **Ergänzung (03.08.2026), inspiriert von MonoNote (digitalminimalist.com/tools/mononote):**
  MonoNote nutzt Live Activity/Dynamic Island, um genau **eine** dringende Notiz auf dem
  Sperrbildschirm präsent zu halten — nicht als Benachrichtigung, sondern als stille
  Dauerpräsenz eines selbst gewählten Inhalts. Übertragen auf Glass Kanban wäre der stimmigste
  Zuschnitt daher nicht die Kennzahl „In Bearbeitung: 2/3", sondern **die eine Karte, an der
  gerade gearbeitet wird** — bewusst vom Nutzer gestartet (z. B. „diese Karte anheften",
  Fokus-Session) und mit dem Erledigen oder manuell wieder beendet. Das löst die oben
  beschriebene Spannung sauberer: Der begrenzte Moment ist dann nicht ein Zeitfenster, das die
  App erraten muss, sondern eine explizite Nutzerentscheidung mit klarem Anfang und Ende —
  psychologisch dieselbe Selbstverpflichtungs-Linie wie das WIP-Limit (Reibung statt Verbot,
  CONCEPT.md), und kanban-seitig ein Pull im Wortsinn: Die Nutzerin zieht sich eine Karte in
  den Fokus, das Erledigen beendet die Präsenz von selbst (Ende als Belohnungsmoment, kein
  Mahnen).
  Passt zusammen mit der „Eine Karte"-Variante des Widgets (s. o., „Spätere
  Apple-/Mac-Ausbaustufen") zu einem gemeinsamen Muster „ein Fokus-Inhalt außerhalb der App".

## Veröffentlichung (Mac App Store)

Seit dem 26.07.2026 ein aktives Vorhaben mit eigenem Arbeitsdokument:
**[RELEASE.md](RELEASE.md)** führt Phasen, Status, Entscheidungslog und Verifikation —
und ist die einzige Wahrheit zum Release (dieser Abschnitt hier bleibt bewusst nur ein
Verweis, damit nichts doppelt gepflegt wird). Beschlossen dort u. a.: Einmalkauf
9,99–14,99 €, nur Mac App Store, Deutsch + Englisch mit Englisch als
Entwicklungssprache, Tag-Migration auf `#next`/`#inprogress` (letzteres am 13.08.2026
selbst überholt — die Spalte steht seither nicht mehr in den Notizen).

Der ältere Branch `feature/backlog-release-readiness` (21.07.) ist damit obsolet;
sein Inhalt ist in RELEASE.md aufgegangen bzw. inzwischen umgesetzt (private API
entfernt in `4f83347`).

## Explizit abgelehnt (kein "später", sondern bewusst ausgeschlossen)

- **Eigene Push-Benachrichtigungen der App** — Reminders hat bereits eigene
  Benachrichtigungen; eigene Notifications würden sich doppeln und widersprechen dem ruhigen
  Minimal-Desk-Setup-Vibe der App.
- **Spalten enden mit dem Inhalt („Board endet, wo die Arbeit endet")** — gebaut, angeschaut
  und am 23.07.2026 vom Nutzer abgelehnt (PR #14, ungemergt geschlossen). Der Vorschlag: alle
  vier Spalten so hoch wie die vollste, darunter Fensterglas. Entscheidung: **Die Spalten
  behalten die volle Fensterhöhe.** Die durchgehenden Mulden sind das Board — auch halb leer
  sollen sie als stehende Struktur lesbar sein, nicht als Block, der mit dem Inhalt atmet.
  Wer weniger Leerfläche will, macht das Fenster kleiner; genau dafür ist es frei skalierbar.
  Nicht wieder vorschlagen, ohne dass der Nutzer das Thema selbst öffnet.
- **Schmalere Ablage-Spalten (Backlog/Erledigt)** — im selben Zug vorgeschlagen und nicht
  weiterverfolgt: Alle vier Spalten bleiben gleich breit, der Grundsatz „Fokus kommt aus dem
  Karteninhalt, nicht aus der Spalten-Geometrie" bleibt stehen.
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
- ~~**Bestätigungsdialog vor dem Löschen**~~ — **diese Ablehnung ist am 26.07.2026
  revidiert worden; die App fragt heute nach (SPEC.md, „Löschen fragt nach").** Die
  ursprüngliche Begründung lautete: abgelöst durch Undo (⌘Z) — eine Rückfrage besteuert
  jede Löschung, um die seltene falsche abzufangen, während ein Undo nur die Person etwas
  kostet, die sich tatsächlich vertan hat. Das Argument trug nicht, weil das Netz ein Loch
  hat: EventKit kennt kein echtes Wiederherstellen, ⌘Z legt eine **neue** Erinnerung an,
  und **Unteraufgaben, Anhänge, Reminders-Tags und -Flags kommen dabei nicht zurück**. Ein
  Undo, das nicht alles zurückholt, kann eine Rückfrage
  nicht ersetzen. Der Eintrag bleibt als Vorgeschichte stehen, damit die Rückfrage nicht
  eines Tages unter Berufung auf diese Zeile wieder ausgebaut wird.
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
- **Archiv für erledigte Tickets in der App** — abgelehnt (Juli 2026, im Zug der
  Verkürzung des Erledigt-Fensters von 14 auf 7 Tage). Geprüft und verworfen wurden:
  ein eigenes Archivfenster bzw. eine Archiv-Ansicht (neues Chrome, macht die App zum
  Verwaltungswerkzeug), Ticketlisten im „Rückblick"-Tab (der ist bewusst Aggregat, kein
  Scrollen durch Einzeltickets), unbegrenztes Aufklappen aller geladenen Completions
  (eine Liste über Monate braucht Struktur — Datums-Überschriften, Gruppen, Suche — und
  genau dieses Chrome soll die Spalte nicht tragen) sowie Datums-Gruppierung in der
  Spalte. Gültige Lösung (SPEC.md): 7 Tage Ruhezustand, „N ältere anzeigen" holt die
  letzten 30 Tage für die Sitzung, alles Ältere zeigt die Reminders-App — sie ist der
  Speicher und hat Suche und Erledigt-Ansicht bereits. Leitsatz der Abwägung: Der
  Ruhezustand gehört dem Minimalismus, der Blick zurück ist ein Moment (ein Klick, eine
  Sitzung), Übersicht entsteht durch Begrenzung statt durch Struktur, Tiefe wird an
  Reminders delegiert.
  **Darstellung, im selben Zug verworfen:** die Fußzeile als `.glass`-Button (eine
  Glasplatte in der Mulde verletzt „Glas ist Chrome, nie Inhalt" — gültig ist die blanke
  Textzeile mit Hover) und der System-Scrollbalken in den Spalten (läge als einziges
  Element über den Karten und bräche die Tiefenordnung der Mulde — das „mehr"-Signal ist
  der Fade am Spaltenrand).
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

## Kleiner Rest aus dem Nutzer-Review (10.08.2026)

Verworfen beim Schließen der fünf verbliebenen Befunde:

- **Prosa aus dem URL-Feld automatisch in die Notizen verschieben** — verworfen: Das rät,
  was gemeint war, und verschiebt Text hinter dem Rücken des Nutzers. Die Folge benennen
  und ihn selbst entscheiden lassen ist ehrlicher und billiger.
- **Den Editor nicht schließen lassen, solange das URL-Feld ungültig ist** — verworfen:
  Das ist ein Verbot, wo das Board Reibung vorsieht (Muster WIP-Dialog). Der Hinweis
  erscheint während des Tippens, also vor der Folge — mehr braucht es nicht.
- **Die Anschläge zwischen ⌘N und dem fertigen Editor puffern und nachreichen** —
  verworfen: gemessen unnötig. Die Lücke lag nach dem Fix bei etwa 16 ms (16 Zeichen in
  65 ms getippt, davon kam anfangs keines, danach alle an); ein Mensch braucht für ein
  Zeichen rund 100 ms. Ein Puffer wäre eine zweite Wahrheit über den Titel, für ein
  Problem, das nicht mehr auftritt.
- **Die Felder einer schreibgeschützten Liste bearbeitbar lassen und beim Speichern
  scheitern** — verworfen: Das war der Zustand, und er kostete die ganze Eingabe für eine
  Tatsache, die beim Öffnen feststand.
- **Die WIP-Erklärung auf dem Board statt in den Einstellungen zeigen** — verworfen: Das
  Board bleibt wortlos (Minimalismus, „kein Dauertext"). Die Einstellungen sind der Ort,
  an dem eine Regel stehen darf, ohne Rauschen zu werden.

Nicht mehr offen: **Escape schließt den Karten-Editor** — der Befund aus dem Review war ein
Artefakt der synthetischen Tastendrücke (die Taste ging an eine andere App). Am 10.08.2026
live nachgeprüft: Escape schließt, und eine gerade angelegte Karte wird dabei verworfen.
