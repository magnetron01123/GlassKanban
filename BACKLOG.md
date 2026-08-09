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
  herausgefiltert wird, siehe SPEC.md). Vorschlag: eigene Hashtags erkennen und als kleine
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
  Hashtag-Mechanismus wie bei den Spalten, oder etwas anderes, das nicht mit dem
  Status-Hashtag kollidiert.
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
  bestehenden mittleren Spalten, und wie der Status-Hashtag-Mechanismus (SPEC.md) mit
  umbenannten Spalten zusammenspielt.
- **Manuelle Kartenreihenfolge innerhalb einer Spalte** — MVP sortiert automatisch nach
  Fälligkeitsdatum.

## Wiederkehrende Aufgaben (Reminders-Wiederholung)

- ~~**Verhalten wiederkehrender Erinnerungen beim Abhaken klären**~~ — am 08.08.2026 gegen
  echtes EventKit gemessen und beantwortet, ausgelöst von einem echten Fehler: ein
  wiederkehrendes Ticket stand nach dem Erledigen in „Als Nächstes". Antworten auf die drei
  offenen Fragen: (1) Der erledigte Durchgang wird als **eigene, abgelöste** Erinnerung
  abgelegt, die Serie läuft **unter derselben ID** mit dem nächsten Termin weiter — der
  „Erledigt"-Moment ist also sichtbar und dauerhaft, nur nicht an der ID, die das Board
  gezogen hat. (2) Der Status-Hashtag wird sauber entfernt; die zurückkehrende Serie landet
  korrekt im Backlog, auch nach 90 s Beobachtung ohne iCloud-Rückschreiber. (3) Die
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
- **Restlücke der Tag-Freigabe: Abhaken bei geschlossener App** (09.08.2026) — die
  Freigabe-Regel braucht den vorigen Refresh als Beweis, dass niemand frisch gezogen hat
  (Bedingung 2). Passiert das externe Abhaken, während die App zu ist, bleibt der Tag bis
  zum nächsten Abhaken oder einem Handgriff stehen. Bewusst offen gelassen: Beim Kaltstart
  aus Zeitstempeln zu raten hieße, ohne Beweis Karten zu verschieben — dieselbe Abwägung,
  an der schon das „Rückwärtsrechnen der Wiederholungsregel" oben gescheitert ist.
- ~~**Backlog-Sichtbarkeit wiederkehrender, noch nicht fälliger Karten**~~ — umgesetzt und am
  27.07.2026 grundlegend neu entschieden: solche Karten werden **nicht mehr ausgeblendet**,
  sondern sinken ans Ende des Backlogs, wo der Falz schneidet („N noch nicht fällig"). Grund:
  Ausblenden ist ein Push-Konzept und verhinderte genau das Vorziehen, für das ein Kanban-Board
  da ist. Filterzeile, Einstellung und Leer-Zustand dazu sind entfallen. Ein Schalter „Noch
  nicht Fälliges einklappen" (Einstellungen → Backlog, Standard an) wählt seit dem 27.07.2026
  zwischen zwei Falz-Schnitten — nicht mehr zwischen Sehen und Nicht-Sehen. Siehe SPEC.md,
  „Reifegrad statt Sichtbarkeit".

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
  (z. B. Spaltenbedeutung, Hashtag-Mechanismus, WIP-Limit, Drag & Drop) beim ersten Start.
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

## Plattform-Erweiterung: iOS-App

- **Begleitende iOS-App (iPhone + iPad)** — eigene Glass-Kanban-Ansicht auf iPhone/iPad statt
  nur über die native Reminders-App unterwegs Hashtags zu setzen (das funktioniert schon jetzt
  ohne eigene App, siehe Bonus-Hinweis in SPEC.md). Eigenes Xcode-Multiplatform-Target, eigene
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
Entwicklungssprache, Tag-Migration auf `#next`/`#inprogress`.

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
  und **Unteraufgaben, Anhänge, Reminders-Tags und -Flags kommen dabei nicht zurück**
  (FINDINGS-2026-07.md, A3). Ein Undo, das nicht alles zurückholt, kann eine Rückfrage
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
