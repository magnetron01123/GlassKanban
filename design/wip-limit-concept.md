# Design-Konzept: WIP-Limits für die Arbeitsspalten

Status: Konzept, noch nicht umgesetzt.
Basis: BACKLOG.md („WIP-Limit für ‚In Bearbeitung‘", Abschnitt „Board-Struktur"),
Personal-Kanban-Philosophie (CONCEPT.md), Farb-Disziplin-Befund aus dem laufenden
Design-Review (Orange exklusiv für Dringlichkeit — Memory `glasskanban-design-review-findings`,
Befund 1).

## Leitidee

Ein WIP-Limit ist eine Aussage über **Kapazität**, keine über **Dringlichkeit**. Es
verdient deshalb keine der bereits verplanten warmen Farben (Orange = Dringlichkeit/
„Heute", Rot = überfällig), sondern eine eigene, kühle Farbfamilie — das hält die
Farbsemantik sauber, statt Amber (der Backlog-Vorschlag) knapp neben Orange zu
quetschen.

Zwei Mechanismen, zwei Zwecke, bewusst getrennt — und bewusst **unterschiedlich
weit gefasst**, nicht symmetrisch auf beide Spalten:

- **Ambientes Signal (dauerhaft, beide Spalten):** Der bereits vorhandene Zähler in
  der Spaltenkopfzeile (`ColumnView.swift:127–145`) zeigt das Limit direkt als Teil
  der Zahl (`3 / 5`) und wechselt die Farbe, sobald die Spalte darüber liegt — macht
  Personal Kanbans Kernversprechen „Arbeit sichtbar machen" für die Kapazität konkret,
  ohne neues Element (Kanban-Prinzip „Make Policies Explicit": die Regel steht direkt
  auf der Tafel, nicht nur in den Einstellungen). Gilt für „Als Nächstes" genauso wie
  für „In Bearbeitung": Sichtbarkeit einer wachsenden Warteschlange schadet nirgends.
- **Reibungsmoment (punktuell, nur „In Bearbeitung"):** Genau in dem Augenblick, in
  dem eine Karte **die Arbeitsspalte** über ihr Limit schiebt, unterbricht ein kurzer
  Bestätigungs-Dialog den Fluss. Bewusst **nicht** bei „Als Nächstes" — Personal
  Kanban limitiert im Kern nur *laufende* Arbeit („work in **progress**"), eine volle
  Zusage-Warteschlange ist normales Planen, kein Überkommitment. Die kleine
  Unterbrechung selbst ist die Bremse, nicht ein Verbot — sie kostet einen Klick mehr,
  verhindert aber nichts endgültig, und sie bleibt auf die eine Spalte begrenzt, in
  der Überladen tatsächlich der teure Fehler ist.

Die App funktioniert mit sinnvollen Standardwerten ohne einen einzigen
Einstellungs-Klick; wer will, justiert in den bestehenden Einstellungen nach
demselben Muster wie die Listenauswahl.

---

## 1. Geltungsbereich: nur die beiden Arbeitsspalten — mit einer Nuance

Die **Limit-Einstellung und das ambiente Farbsignal** betreffen beide Arbeitsspalten:
**Als Nächstes** (`.next`) und **In Bearbeitung** (`.inProgress`) — genau die beiden
Spalten, die `KanbanStatus.cardDensity` (`Models.swift:38–41`) bereits heute als
`.full` gruppiert. Backlog und Erledigt sind laut Iterations-2-Konzept (Punkt 8/9)
bewusst Ablagen, keine Arbeitsflächen — ein Limit dort wäre sinnlos (Erledigt wächst
naturgemäß, Backlog ist der Steh-Stapel).

Der **Bestätigungs-Dialog** (Abschnitt 5) ist enger gefasst und gilt **nur für „In
Bearbeitung"** — Begründung dort. „Als Nächstes" bekommt Zahl, Einstellung und Farbe,
aber keine Unterbrechung.

Der Code-Präzedenzfall für „diese beiden Spalten sind eine Gruppe" existiert also
schon (`cardDensity`); eine WIP-Limit-Zugehörigkeit würde denselben Switch-Idiom auf
`KanbanStatus` ergänzen statt eine neue Abstraktion einzuführen.

## 2. Datenmodell & Persistenz

Zwei ganzzahlige Einstellungen, eine je Spalte — **keine gemeinsame Zahl für beide**,
weil sie unterschiedliche Funktionen haben: „In Bearbeitung" ist die klassische
Fokus-Spalte (klein halten), „Als Nächstes" ist eine Zusage-Warteschlange (darf etwas
großzügiger sein, sonst wird sie zum zweiten Backlog).

- **Defaults:** In Bearbeitung = **3**, Als Nächstes = **5** — Personal-Kanban-
  Faustregel für Einzelpersonen (2–3 parallele Aufgaben in Bearbeitung, um
  Kontextwechsel klein zu halten); die Zusage-Warteschlange „Als Nächstes" darf etwas
  großzügiger sein, ohne selbst zum zweiten Backlog zu werden.
- **„Kein Limit" = 0**, nicht ein separater Ein/Aus-Schalter. Das spiegelt ein Muster,
  das die App an anderer Stelle schon nutzt (Backlog = „kein Tag" statt eigenem
  Sonderzustand) und spart eine zusätzliche Toggle-Zeile in den Einstellungen.
- **Persistenz:** zwei neue `@Published`-Properties auf `RemindersStore`, `didSet` →
  `UserDefaults`, exakt nach dem bestehenden Muster von `excludedCalendarIDs`
  (`RemindersStore.swift:38–45`) — kein neues Settings-Objekt, keine neue
  Abstraktionsebene.

## 3. Visuelles Signal: das Limit steht direkt in der Kapsel

**Korrektur gegenüber der ersten Fassung:** Ein WIP-Limit ist eine *Regel*, und
„Make Policies Explicit" ist ein Kanban-Grundprinzip (auch bei Personal Kanban) —
Regeln gehören sichtbar auf die Tafel, nicht in ein Einstellungsfenster versteckt.
Nur die Farbe zu ändern und die Zahl selbst hinter einem Hover-Tooltip zu verstecken
(erste Fassung dieses Abschnitts) widerspricht dem. Die Zähler-Kapsel zeigt das Limit
deshalb **immer sichtbar als Teil der Zahl**, sobald eines gesetzt ist — nicht nur
über Farbe und nicht nur auf Nachfrage.

Die Kapsel in `ColumnView.swift` bleibt geometrisch unverändert (`Capsule()`,
`.quaternary.opacity(0.8)`-Füllung, Schriftgröße 11 semibold). Zwei Unterschiede,
beide reine Text-/Farbänderungen am bestehenden Element:

1. **Format wechselt von „3" zu „3 / 5"**, sobald für die Spalte ein Limit > 0
   gesetzt ist. Ohne Limit (0, Standard bei „Als Nächstes") bleibt es beim
   heutigen, bloßen `"\(cards.count)"` — keine Änderung für alle, die kein Limit
   setzen.
2. **Bei Überschreitung füllt sich die Kapsel** mit `.teal`, die Zahl wird weiß —
   bewusst kühl statt Amber/Orange, weil ein WIP-Limit „Kapazität/Fluss" bedeutet,
   nicht „Dringlichkeit/Warnung" (Details zur Farbwahl unten). `.teal` ist zudem ein
   fester Farbwert, kollidiert also nicht mit der System-Akzentfarbe des Nutzers.

   **Zwei Korrekturen nach Sichtprüfung am laufenden Build:**
   - Zuerst war nur der *Text* teal auf der neutralen `.quaternary`-Kapsel — bei
     11 pt gegen das Spaltenglas zu schwach zu lesen.
   - Dann eine **solide** Füllung mit weißer Schrift. Gut lesbar, aber
     designtechnisch falsch: Die App hat eine dreistufige Badge-Skala (leise grau →
     getönt → solid), und die solide Stufe ist bewusst dem Überfällig-Badge
     vorbehalten (Commit b000f85). Ein Kapazitätssignal darf sich nicht dasselbe
     Gewicht nehmen wie der einzige echte Notfall der App.
   - Endstand: **getönte Stufe** (`teal.opacity(0.32)` hinter teal Schrift). Sie
     bleibt transluzent und damit im Liquid-Glass-Schichtmodell — anders als eine
     opake Fläche, die auf dem Glas „aufgeklebt" wirkt —, ist aber kräftig genug für
     11 pt auf der Spaltenoberfläche. Die 0,32 statt der 0,14 des Karten-Badges sind
     Absicht: Kartenbadges sitzen auf opakem Papier, die Kopfzeilen-Kapsel auf
     transluzentem Glas und braucht mehr Deckung für dieselbe Wirkung.

```
Kein Limit gesetzt: ⟨ 3 ⟩          — wie heute, unverändert
Limit 5, im Rahmen: ⟨ 3 / 5 ⟩      — Text .secondary, Kapsel .quaternary
Limit 5, überschritten: ⟨ 6 / 5 ⟩  — Kapsel .teal gefüllt, Text weiß
```

Kein Rahmen, kein Icon, keine zweite Farbstufe für „knapp drüber" vs. „weit drüber" —
das wäre schon wieder zusätzliches Element in einem Feld, das bewusst nur ein Zähler
bleiben soll (vgl. Befund 5 im Design-Review: Detail-Polish soll nicht zu
Kleinteiligkeit eskalieren). Die Regel selbst sichtbar zu machen (Punkt 1) ist der
Kanban-Grundsatz; wie stark sie überschritten ist, bleibt bewusst grob (nur ja/nein
per Farbe).

**Tooltip bleibt als Ergänzung, nicht als einziger Träger der Information:** Der
bestehende `.help(...)`-Tooltip (`ColumnView.swift:139`) liefert weiterhin den
ausformulierten Satz — `"3 von 5 Karten"` bzw. am Limit `"6 von 5 Karten — WIP-Limit
überschritten"` — als zusätzlicher Kontext beim Hover, jetzt aber nicht mehr die
einzige Stelle, an der die Regel überhaupt zu finden ist.

**Kanban-Tipp im selben Tooltip, nur bei aktivem Limit, ein Fragment statt Prosa:**

```
Im Rahmen:      3 von 5 Karten · lieber abschließen als stapeln
Überschritten:  6 von 5 Karten — WIP-Limit überschritten
```

Kein ganzer Satz, keine Erklärung „was ist ein WIP-Limit" — nur die Kurzformel, die
den Grund hinter der Zahl mitliefert, für alle, die zum ersten Mal draufhovern.
Bleibt bewusst knapp, damit der Tooltip ein Tooltip bleibt und keine Doku wird.
Dieselbe Formel taucht am Einstellungsort wieder auf (Abschnitt 6) — Wiedererkennung
statt zweiter Erklärung.

**Barrierefreiheit:** Da das Über-Limit-Signal sonst reine Farbe wäre (für VoiceOver
und Farbfehlsichtigkeit unsichtbar), bekommt die Kapsel zusätzlich denselben Text als
`.accessibilityValue` wie den Tooltip — kein sichtbares Extra-Element, aber ein
vorlesbares.

**Übergang:** ein leiser `.animation(.easeInOut, value: isOverLimit)` auf die
Farbänderung, passend zur „dezente Bewegung"-Vorgabe aus CONCEPT.md — kein Sprung,
kein Blitz.

## 4. Schwellenwert-Logik

- **Zählbasis (bestätigt):** die Anzahl der Tickets, die tatsächlich in der Spalte
  stehen — derselbe bereits gefilterte Wert, den die Kapsel heute anzeigt
  (`store.cards(for: status).count`, inkl. aktiver Dringlichkeits-/Fälligkeitsfilter).
  Bewusst **kein** zweiter, unsichtbarer Rohwert „eigentlich sind es mehr" — das
  würde eine Zahl im UI zeigen und eine andere meinen. Konsequenz: Bei aktivem Filter
  kann das Limit optimistisch wirken (weniger sichtbar als real vorhanden) — akzeptabel,
  weil es ein weiches Signal ist, kein Constraint-Check.
- **Auslöser:** Farbwechsel erst bei **Überschreitung** (`count > limit`), nicht schon
  beim Erreichen. Genau das Limit zu treffen ist der Zielzustand („voll ausgelastet"),
  keine Übertretung — die Farbe soll „zu viel", nicht „genug" signalisieren.

## 5. Bestätigungs-Dialog beim Überschreiten — nur bei „In Bearbeitung"

Zusätzlich zum ambienten Farbsignal: In dem Moment, in dem ein Drop **„In
Bearbeitung"** über ihr Limit hebt, erscheint ein kurzer, nativer
Bestätigungs-Dialog. Bewusst **kein hartes Blocken** (die Karte lässt sich immer
ablegen), sondern ein gezielter Reibungsmoment — die Verzögerung ist die Bremse,
nicht ein Verbot. Genau das war der ausdrückliche Wunsch: lieber einmal kurz nervig
als das WIP-Limit stillschweigend zu ignorieren.

**Warum nur diese eine Spalte:** Personal Kanban limitiert im Kern nur *laufende*
Arbeit — „WIP" heißt wörtlich „work in **progress**", nicht „Dinge, die geplant
sind". Eine volle Zusage-Warteschlange „Als Nächstes" ist normales Vorausplanen,
kein Überkommitment; zu viele Dinge gleichzeitig *angefangen* zu haben ist der
eigentliche, teure Fehler, den die Philosophie meint. Die Beschränkung hält außerdem
die einzige bewusst „nervige", modale Stelle der ganzen App auf ein einziges,
klar begründetes Vorkommen begrenzt (siehe Abschnitt 5a) — sie wird dadurch nicht
schwächer, nur gezielter.

**Technischer Haken, der die Dialog-Form bestimmt:** `.dropDestination(for:)`
(`ColumnView.swift:112`) muss synchron einen `Bool` zurückgeben, um die
Drop-Animation zu steuern — man kann darin nicht auf eine Dialog-Antwort warten,
ohne die Drag-Geste einzufrieren. Der Dialog kann also nicht *vor* dem Move
blockieren, sondern nur *danach* nachfassen:

1. Drop passiert wie gewohnt, `store.move(cardID:to:)` (`RemindersStore.swift:233`)
   läuft sofort durch, die Karte landet mit normaler Animation in der Zielspalte.
2. Übersteigt die Spalte danach ihr Limit, erscheint unmittelbar ein `.alert` — die
   Frage zielt bewusst nicht auf „Regel gebrochen, ja/nein?", sondern auf die
   eigentliche Personal-Kanban-Entscheidung: mehr anfangen oder erst was fertig
   machen?

   > **In Bearbeitung: 4 von 3 Karten.**
   > Wirklich so viel gleichzeitig — oder lieber erst etwas abschließen?
   >
   > [ Erst abschließen ]  [ Trotzdem so lassen ]

   „Erst abschließen" verschiebt die Karte zurück in ihre Ursprungsspalte — vor dem
   Drop gemerkt, analog zu `cards[index].status` in `move()`.
3. **„Erst abschließen" ist die Standardaktion** — blauer, optisch betonter Knopf,
   an die Return-Taste gebunden. Technisch trägt er beides: `role: .cancel` plus
   `.keyboardShortcut(.defaultAction)`. „Trotzdem so lassen" bleibt schlicht und
   erfordert einen gezielten Klick.

   **Am laufenden Build verifiziert** (zwei Iterationen nötig):
   - Erste Fassung gab „Erst abschließen" nur `role: .cancel` — macOS rendert das
     als *sekundären* Knopf, womit ausgerechnet „Trotzdem so lassen" blau und
     Return-gebunden war. Die psychologische Absicht war exakt umgedreht. In Tests
     wäre das nie aufgefallen.
   - Zweite Fassung (nur `.defaultAction`) korrigierte die Betonung, gab aber
     Escape an „Trotzdem so lassen".
   - Endstand: Beide Modifier auf demselben Knopf. Ergebnis am realen Dialog
     gemessen — **Return** löst „Erst abschließen" aus, **Escape** schließt den
     Dialog gar nicht. Damit gibt es *keinen* versehentlichen Weg zum Überladen
     mehr: Wer die Spalte überfüllen will, muss den sekundären Knopf bewusst
     anklicken. Das erfüllt die Absicht sogar strenger als ursprünglich formuliert.

Der Dialog erscheint bei **jedem** Drop, der „In Bearbeitung" über das Limit hält
oder weiter darüber schiebt — nicht nur beim ersten Überschreiten. Das ist Absicht:
Der Reibungswert soll mit jedem weiteren Überladen-Versuch gleich hoch bleiben, sonst
verpufft er nach der ersten Karte. Kein „Nicht mehr fragen"-Schalter — der würde den
Zweck unterlaufen. Er erscheint dagegen **nie** bei „Als Nächstes", egal wie voll die
Warteschlange wird — dort bleibt es bei der Farbe.

## 5a. Ehrliche Spannung mit „belohnen, nie bestrafen"

Muss offen benannt werden, nicht nur stillschweigend übernommen: Das
Iterations-2-Konzept legt als Grundprinzip für alle Motivations-Mechanik fest
„belohnen, nie bestrafen" und lehnt explizit „rote Warnfarben bei Inaktivität" als
„zu bestrafend" ab. Ein Dialog, der absichtlich so gebaut ist, dass er nervt, damit
man ihn vermeidet, ist der Definition nach eine Bestrafungs-Mechanik — die erste in
der ganzen App. Ebenso ist der native `.alert` die erste **modale** Unterbrechung
überhaupt; alles andere (Filter, Streak-Popover, Tooltips) ist heute bewusst
nicht-modal und ambient.

Das ist kein Grund, den Dialog zu verwerfen — es war ein expliziter, informierter
Wunsch, keine versehentliche Fehlgriff-Empfehlung von mir. Statt die Spannung
wegzudiskutieren oder den Dialog wohlklingend umzudeuten, wird sie hier bewusst als
**eine einzige, klar begründete Ausnahme** eingehegt, nicht aufgelöst:

1. **Beschränkung auf „In Bearbeitung"** (Abschnitt 1/5): hält die einzige
   bestrafende, modale Stelle der ganzen App auf genau eine Spalte begrenzt, statt sie
   zu verdoppeln. Kein zweites Vorkommen, kein Muster, das sich später „natürlich"
   auf weitere Spalten ausdehnen ließe.
2. **Reibung nur im Moment der neuen Entscheidung, nie danach:** Wer „Trotzdem so
   lassen" wählt, bekommt keinen fortlaufenden Tadel für den bestehenden Zustand —
   die Kapsel bleibt zwar eingefärbt (Sichtbarkeit, keine Wertung), aber der Dialog
   kommt erst bei der *nächsten* Karte wieder, nicht als Dauer-Nörgeln über die
   Entscheidung von eben.
3. Das bestehende Erfolgs-Feedback beim Drop (`Haptics.drop()`,
   `ColumnView.swift:116`) feuert unverändert bei **jedem** gelungenen Move, auch
   einem, der gleich den Dialog auslöst — der haptische Tick bestätigt nur, dass die
   Karte physisch gelandet ist (das stimmt so oder so), die Dialog-Frage danach ist
   eine separate, spätere Überlegung. Ihn zu unterdrücken würde denselben physischen
   Vorgang inkonsistent mal spürbar, mal stumm machen.

## 6. Einstellungen-UI

Kein neuer Tab. `GeneralSettingsView` (`SettingsView.swift:58–79`) bekommt eine
zweite `Section` im bestehenden `Form`/`.formStyle(.grouped)`, mit zwei `Stepper`-Zeilen
(Bereich 0–20, „0" wird als „Kein Limit" statt „0" gerendert):

```
Allgemein
├─ Beim Anmelden starten                    [Toggle] (bestehend)
└─ WIP-Limits                          (i)
   ├─ Als Nächstes         Kein Limit ⟨ ›   [Stepper]
   └─ In Bearbeitung       3            ⟨ › [Stepper]
```

Die Section-Überschrift „WIP-Limits" bekommt denselben `.help(...)`-Tooltip wie die
Board-Kapsel (kein sichtbares `(i)`-Icon nötig, `Text` mit `.help()` reicht) — „lieber
abschließen als stapeln". Wer zum ersten Mal am Regler sitzt, versteht so sofort das
Warum, nicht nur, welche Zahl er eintippt — dieselbe Kurzformel an zwei Stellen statt
zweier verschiedener Erklärtexte.

Zwei Zeilen rechtfertigen keinen dritten Tab neben „Listen"/„Allgemein" — ein neuer
Tab für zwei Stepper wäre mehr Chrome als Inhalt.

**Bewusste Entscheidung: Das Limit ist ausschließlich hier änderbar, nicht am Board
selbst** (keine editierbare Zahl, kein Stepper, kein Popover an der Kapsel). Ein
WIP-Limit funktioniert als Selbstverpflichtung nur, wenn es minimal schwerer zu
ändern ist als einzuhalten — sonst wird im genau dem Moment, in dem es unbequem
wird (eine Karte zieht gerade drüber), aus „Limit einhalten" ein Reflex von „Limit
kurz hochsetzen". Ein Klick direkt an der Kapsel, in genau dem Augenblick, in dem
der Bestätigungs-Dialog aufploppt, wäre exakt diese Einladung zum Selbstbetrug — die
Regel bliebe technisch bestehen, aber wirkungslos.

Der Umweg über ⌘,/„Allgemein" ist bewusst die einzige Route: kurz genug, dass eine
echte, überlegte Anpassung (z. B. „diese Woche habe ich wirklich mehr Kapazität")
nicht bürokratisch wirkt, aber lang genug, dass sie eine bewusste, spätere
Entscheidung bleibt statt ein Reflex mitten im Drag. Für den eigentlichen
Alltagsfall — „nur diese eine Karte noch, ohne die Regel selbst zu ändern" — gibt es
bereits einen sauberen, dafür vorgesehenen Ausweg: „Trotzdem so lassen" im
Bestätigungs-Dialog (Abschnitt 5). Der deckt genau das „einmal reicht"-Bedürfnis ab,
ohne dass dafür je die Grenze selbst verschoben werden müsste — wer die Grenze
wirklich dauerhaft ändern will, tut das an einem ruhigen Punkt, nicht im Reflex.

## 7. Bewusst verworfen

- **Limit direkt an der Kapsel änderbar** (Stepper, Popover oder editierbare Zahl am
  Board) — würde die Selbstverpflichtung entwerten: genau im Moment des
  Überschreitens wäre „Limit hochsetzen" nur einen Klick von „Limit einhalten"
  entfernt (Abschnitt 6). Die Regel muss außerhalb der Drag-Situation geändert
  werden, sonst ist sie keine.
- **Hartes Blocken** (Drop technisch verhindern, kein Weg vorbei) — widerspricht der
  „Personal Kanban ist Sichtbarkeit, keine Bürokratie"-Grundhaltung. Der
  Bestätigungs-Dialog aus Abschnitt 5 ist die gewollte Alternative: Reibung statt
  Verbot, die Karte lässt sich immer beibehalten, wenn man es wirklich will.
- **Warntext/Badge/Ausrufezeichen an der Kapsel selbst** — jede zusätzliche
  Wortmeldung direkt am Zähler wäre Rauschen; die Farbe der ohnehin vorhandenen Zahl
  reicht als Dauersignal, der Dialog übernimmt den Moment der Entscheidung.
- **Amber/Orange als Limit-Farbe** — kollidiert semantisch mit der bereits verplanten
  „Orange = Dringlichkeit"-Regel und wäre visuell kaum von der „Heute"-Badge zu
  unterscheiden.
- **Zwei-Stufen-Farbverlauf** (leicht über Limit vs. weit über Limit) — mehr optische
  Zustände als eine ruhige Zähler-Kapsel tragen sollte.
- **Push-artiger Hinweis/Systembenachrichtigung beim Überschreiten** — widerspricht
  explizit BACKLOG.md („Explizit abgelehnt: eigene Push-Benachrichtigungen").
- **Ein/Aus-Schalter zusätzlich zu den Steppern** — überflüssig, weil „0 = kein Limit"
  denselben Zustand ohne zweites Steuerelement abdeckt.

## Geklärt (Rückmeldung des Product Owners)

- **Defaults:** sinnvolle Werte statt exakter Vorgabe gewünscht → 3 / 5 (Abschnitt 2).
- **Zählbasis:** Limit bezieht sich auf die tatsächliche Kartenzahl in der Spalte →
  gefilterter, sichtbarer Wert (Abschnitt 4), bestätigt.
- **Reaktion beim Überschreiten:** nicht nur das stille Farbsignal — zusätzlich ein
  bewusst „nerviger" Bestätigungs-Dialog, weil genau diese Reibung Überladen in der
  Praxis verhindert (Abschnitt 5).
- **Ambientes Signal bleibt zusätzlich bestehen:** WIP ist psychologisch wichtig genug,
  dass die dauerhafte, dezente Kapsel-Farbe (Abschnitt 3) unabhängig vom Dialog Pflicht
  ist, nicht nur ein Nice-to-have.
- **Dialog-Frage:** nicht „Regel gebrochen, ja/nein?", sondern die eigentliche
  Personal-Kanban-Entscheidung — mehr anfangen oder erst etwas abschließen? Kurzer,
  prägnanter Wortlaut in Abschnitt 5 festgehalten.
- **Limit-Farbe:** `.teal` (Abschnitt 3), Entscheidung siehe unten.
- **„Erst abschließen"-Ziel:** immer die tatsächliche Ursprungsspalte, keine
  Sonderfall-Logik. Begründung siehe unten.
- **Dialog-Geltungsbereich:** nur „In Bearbeitung", nicht „Als Nächstes" (Abschnitt
  1/5) — hält die einzige bestrafende, modale Stelle der App auf ein einziges,
  theoretisch sauber begründetes Vorkommen begrenzt, entschärft damit einen Teil der
  Spannung mit dem „belohnen, nie bestrafen"-Prinzip aus Abschnitt 5a.

## Entscheidung: Limit-Farbe = `.teal`

Bleibt bei `.teal`, nicht `.indigo`/`.cyan` — ausschlaggebend ist Lesbarkeit bei
11 pt auf der halbtransparenten `.quaternary`-Kapsel in Hell **und** Dunkel: `.cyan`
und `.mint` sind zu hell/kontrastarm für so kleinen Text (bes. auf hellem Glas),
`.indigo` liegt näher an „besonders/kreativ" (Apples eigene Verwendung z. B. bei
Notizen-Ordnern) als an einem neutralen Kapazitätssignal. `.teal` ist von den
verfügbaren kühlen Farben die kontraststärkste bei kleiner Schrift und trägt am
wenigsten Eigenbedeutung — genau das will ein Signal, das nur „Kapazität", nichts
Emotionales, ausdrücken soll.

## Entscheidung: „Erst abschließen" geht immer in die echte Ursprungsspalte zurück

Keine Backlog-Sonderregel. Zwei Gründe:

1. **Es macht nichts schlimmer, als es schon war.** Die Zielspalte kann durch diesen
   Move gar nicht neu überladen werden — sie hat durch das Zurücklegen exakt wieder
   den Stand von einen Moment zuvor. Über ihr eigenes Limit kann eine Spalte
   überhaupt nur durch eine nachträglich **gesenkte** Limit-Einstellung geraten
   (nicht durch Drag & Drop, das ja selbst den Dialog auslösen würde) — und dieser
   Zustand wird bereits passiv durch die Kapsel-Farbe (Abschnitt 3) sichtbar gemacht,
   ganz ohne Zutun dieses Dialogs.
2. **„Zurücklegen" muss wörtlich zurücklegen bedeuten.** Eine versteckte
   Sonderfall-Logik, die je nach Zustand der Nachbarspalte mal dorthin, mal nach
   Backlog schickt, wäre genau die Art von leiser Überraschung, die eine App ohne
   inhaltliche Eingriffe vermeiden sollte — „Rückgängig" soll immer exakt das
   Gegenteil der letzten Aktion sein, nichts Klügeres.

## Ausblick: Kanban-Tipps als Hover-Muster, über WIP hinaus

Die Kurzformel-im-Tooltip aus Abschnitt 3/6 ist kein WIP-spezifischer Kniff, sondern
ein Muster, das sich auf das ganze Board übertragen ließe: an Stellen, wo die App
schon eine stille Regel *hat*, aber nirgends *erklärt*, ein kurzes Fragment statt
Prosa mitgeben — kein neues Element, immer nur am bereits vorhandenen Hover-Ziel.
Nicht Teil dieses Konzepts, aber naheliegende Kandidaten für später, falls das Muster
gefällt:

- **Backlog-Spaltentitel:** Tooltip-Fragment zum Pull-Prinzip (Backlog ist bewusst
  unbegrenzt — nur was aktiv gezogen wird, zählt).
- **„N weitere anzeigen"-Kapsel:** Fragment dazu, warum nicht alles auf einmal
  sichtbar sein muss.
- **„Als Nächstes"-Spaltentitel:** Fragment zum Unterschied Zusage-Warteschlange vs.
  Backlog (Abschnitt 2).

Jeweils derselbe Maßstab wie hier: ein Fragment, kein Satz, nur beim Hover, nie als
Dauertext auf der Fläche selbst.
