# Design-Iteration 2 — Konzept: „Sticky Notes im Fokus"

Status: Konzept, noch nicht umgesetzt.
Basis: Feedback nach Iteration 1 (Branch `feature/design-polish`).

## Leitidee

Die Aufgaben sind der Star, alles andere tritt zurück. Die Karten wandeln sich
von „breiten Listenzeilen auf Papier" zu **kompakten Haftnotizen**: fast
quadratisch, farblich dezent der Reminders-Liste zugeordnet, mit dem Titel als
Held. Das Board hört auf, sich über die volle Bildschirmbreite zu dehnen —
es wird ein **zentriertes, ruhiges Objekt** mit fester Idealbreite, wie ein
physisches Board an der Wand. Motivation entsteht nicht über Gamification-Lärm,
sondern über **sensorische Mikro-Belohnungen** (Trackpad-Haptik, Settle-Animation)
und **Personal-Kanban-Psychologie** (Pull-Signal, sanftes WIP-Limit, Streak-Schutz).

---

## 1. Board-Layout: zentriert statt gedehnt

**Problem:** Auf breiten Bildschirmen dehnen sich die vier Spalten auf volle
Fensterbreite → Karten werden 350–450 pt breit und wirken wie Tabellenzeilen.

**Lösung:**
- Spaltenbreite begrenzen: `min 230 pt, ideal 270 pt, max 300 pt`.
- Board horizontal **zentrieren** (`frame(maxWidth: 4 × 300 + 3 × Gap)`), auf
  Ultrawide-Monitoren bleibt links/rechts Fenster-Glas sichtbar — das Board
  „schwebt" als klar umrissenes Objekt in der Scheibe.
- Fenster-Mindestbreite kann dadurch von 960 auf ~1000 justiert werden,
  Standardgröße bleibt.

Damit sind Karten nie breiter als ~276 pt Innenbreite — Haftnotiz-Proportion.

## 2. Karten: Haftnotizen im Liquid-Glass-Konzept

- **Farbe trägt die Notiz:** sehr dezenter Tint der Listenfarbe (≈ 6 % Opacity)
  über der Papier-Füllung. Die Karte *ist* jetzt die farbige Haftnotiz der
  jeweiligen Liste; der 8-pt-Farbpunkt entfällt (Redundanz raus = minimaler).
  Der Listenname bleibt als Tooltip auf der ganzen Karte.
- **Titel als Held:** 14 pt semibold (statt 13 medium), weiterhin 2 Zeilen
  reserviert. Notiz-Vorschau bleibt 12 pt secondary.
- **Weniger Badge-Lärm:** Das Fälligkeits-Badge erscheint nur noch, wenn es
  etwas zu sagen hat (Datum vorhanden oder erledigt). „Kein Datum" wird nicht
  mehr angezeigt — weniger Text, Aufgabe im Fokus.
- **Proportion:** vertikales Padding 10 → 12; zusammen mit der schmaleren
  Spalte entsteht ein fast quadratisches Notiz-Format.
- Bewusst **verworfen:** zufällige Mini-Rotation der Karten (±0,5°, „echte
  Haftnotizen") — zu verspielt, bricht die Apple-Ruhe.

## 3. Drag & Drop: Größe bleibt stabil

**Problem:** Die Custom-Drag-Preview ist fix 240 pt breit → sichtbarer
Größensprung beim Aufnehmen.

**Lösung:** Die Preview übernimmt die **echte Kartenbreite** (per
`onGeometryChange` gemessen). Der 2°-Kipp und der große weiche Schatten
bleiben — die Karte wird „angehoben", ohne zu schrumpfen oder zu wachsen.

## 4. Prominenter Weg zu Erinnerungen

Neuer Toolbar-Button ganz rechts (`.primaryAction`), **prominent** als
Liquid-Glass-Button mit Akzentfarbe:

> `[ + Neues Ticket ]` (Symbol `plus`, Stil „glassProminent"/borderedProminent)

- Klick öffnet die Erinnerungen-App (Deep Link; dort werden Tickets angelegt —
  das Board bleibt bewusst read-only außer Drag & Drop).
- Tastenkürzel **⌘N**, zusätzlich Menüpunkt im „Board"-Menü.
- Damit gibt es genau *einen* farbigen, auffordernden Knopf im Chrome —
  klare Handlungsaufforderung, trotzdem minimal.

## 5. Zitatleiste entfällt

Die permanente Statement-Zeile unten wird ersatzlos gestrichen (nicht
minimalistisch genug). Die vorhandenen Sprüche (`Quotes.swift`) ziehen in das
Streak-Popover um (Punkt 6) — dort sind sie ein bewusster Moment statt
Dauerrauschen.

## 6. Streak-Popover (Klick auf die Flammen-Kapsel)

Klick auf die Streak-Kapsel öffnet ein kleines Popover:

```
┌──────────────────────────────┐
│  🔥 5 Tage in Folge          │
│                              │
│  M  D  M  D  F  S  S         │
│  ●  ●  ○  ●  ●  ●  ◐         │   ← letzte 7 Tage, gefüllt = ≥1 erledigt
│                              │
│  Heute erledigt: 3           │
│  Diese Woche: 12 erledigt    │   ← Progress Principle: kleine Fortschritte sichtbar
│  Bester Lauf: 12 Tage        │
│  ─────────────────────       │
│  „Sichtbare Arbeit ist       │
│   erledigte Arbeit."         │   ← Tageszitat, hierher umgezogen
└──────────────────────────────┘
```

- Braucht kleine Erweiterung des `StreakCalculator` (7-Tage-Verlauf, Tages-
  und Wochenzähler, Tagesschnitt, bester Lauf) — reine Lesedaten, keine
  neue Persistenz.
- Die Kapsel wird sichtbar auch bei Streak 0 (graue Flamme), sonst gäbe es
  nichts zu klicken.

## 7. Sensorik & Motivations-Psychologie

Prinzip: **belohnen, nie bestrafen** — und alles gated hinter „Bewegung
reduzieren". Keine Punkte, Badges, Levels (CONCEPT.md bleibt gültig).

| Mechanismus | Psychologie | Umsetzung |
|---|---|---|
| **Trackpad-Haptik** | Sensorische Kopplung: die Karte „rastet ein" | `NSHapticFeedbackManager`: leiser Tick (`.alignment`) beim Betreten einer Spalte, satter Tick (`.levelChange`) beim erfolgreichen Drop |
| **Settle-Moment beim Erledigen** | Belohnungs-Mikromoment (Dopamin bei Abschluss) | Karte landet in „Erledigt" mit kurzem Setzen (Scale 1.0 → 0.97 → 1.0, ~0,3 s Spring) + das Erledigt-Badge blitzt kurz grün auf |
| ~~**Pull-Signal**~~ | ~~Zeigarnik-Effekt / Handlungsaufforderung~~ | **Umgesetzt, dann wieder entfernt** (18.07.2026). Der pulsierende Schein auf der obersten Als-Nächstes-Karte war Dauer-Animation in einer App, die ausdrücklich „kein visuelles Rauschen" verspricht; er nutzte zudem `accentColor` und kollidierte damit mit dem Drop-Feedback. Ausschlaggebend war aber ein inhaltliches Argument: **Kanbans eigenes Pull-Signal ist der freie Platz auf dem Board.** Eine leere „In Bearbeitung"-Spalte zwischen gefüllten ist bereits unübersehbar — ein Effekt darüber wiederholt nur, was das Board ohnehin zeigt. Dazu Habituation: Ein Dauerreiz wird binnen Tagen weggefiltert und entwertet nebenbei die Animationen, die sich Aufmerksamkeit verdienen (Settle-Moment, Drop-Feedback). |
| **Sich füllende Flamme** | Loss Aversion + Goal-Gradient-Effekt (Hull): Nähe zum Ziel beschleunigt | Die Flamme füllt sich über den Tag in drei Stufen: grau/Outline (heute noch nichts erledigt — „Streak retten"), halb orange ab der ersten erledigten Aufgabe, satt orange mit Verlauf ab dem persönlichen Tagesschnitt (automatisch aus der Historie, keine Konfiguration). Kein Zähler mahnt — ein Blick auf die Farbe genügt |
| **Tagesfortschritt** | Endowed Progress | Zähler-Kapsel der Erledigt-Spalte zeigt „heute": z. B. `3 heute` statt Gesamtzahl (Gesamt im Tooltip) |
| **Wochenbilanz** | Progress Principle (Amabile): sichtbare kleine Fortschritte sind der stärkste Alltagsmotivator | Streak-Popover zeigt „Diese Woche: 12 erledigt" unter der 7-Tage-Punktreihe — eine Zeile, kein eigenes Report-UI |

Bewusst **verworfen:** Konfetti, Sounds standardmäßig an, Push-Erinnerungen,
rote Warnfarben bei Inaktivität — alles zu laut bzw. bestrafend.
**Verschoben:** das sanfte WIP-Limit für „In Bearbeitung" bleibt im
Projekt-Backlog (BACKLOG.md, „Board-Struktur") und ist nicht Teil dieser
Iteration.

## 8. Voller Backlog: „Ein Stapel, kein Turm"

**Problem:** Wer Reminders ernsthaft nutzt, hat schnell 50+ Einträge ohne
Status-Tag — alle landen in der Backlog-Spalte. Als endloser Turm gleich
großer Haftnotizen erdrückt das die drei Arbeits-Spalten und zerstört den Fokus.

**Leitidee — Aufmerksamkeits-Gefälle über das Board:** Nicht jede Spalte
verdient dieselbe visuelle Währung. Die Bühne gehört „Als Nächstes" und
„In Bearbeitung" — dort sind die Karten volle Haftnotizen. Backlog und
„Erledigt" sind Ablagen an den Rändern und dürfen dichter sein.

Drei Bausteine:

1. **Kompakte Karten in Backlog und Erledigt.** Einzeilige Titelzeile, keine
   Notizen-Vorschau, reduziertes Padding (Kartenhöhe ≈ 32 pt statt ≈ 90 pt) —
   Fälligkeits-Badge nur bei Überfällig/Heute. Listen-Tint bleibt, damit die
   Zuordnung erhalten ist. Psychologischer Nebeneffekt: Beim Pull nach
   „Als Nächstes" **wächst** die Karte zur vollen Haftnotiz — die Aufgabe wird
   physisch „größer", weil sie jetzt zählt. (Umgekehrt schrumpft sie beim
   Erledigen ins Archiv — das Settle-Moment aus Punkt 7 bleibt.)
2. **Sanfte Kappung mit „N weitere".** Der Backlog zeigt die obersten
   ~15 Karten (Sortierung nach Fälligkeit greift schon heute). Darunter eine
   ruhige Kapsel „42 weitere anzeigen", die die Liste inline aufklappt
   (Zustand pro Sitzung gemerkt). Kein Pagination-Gefühl, nur ein bewusster
   zweiter Blick.
3. **Scroll-Fade statt harter Kante.** Am unteren Spaltenrand laufen Karten
   in einen kurzen Transparenz-Verlauf (Maske, ~24 pt) — signalisiert „da ist
   mehr" eleganter als eine abgeschnittene Karte.

Bewusst **verworfen:** Gruppierung nach Liste/Datum mit Zwischenüberschriften
(zu viel Struktur-Lärm für eine Ablage-Spalte); eine eigene Backlog-Suche
(die bestehenden Filter Dringlichkeit/Fälligkeit wirken bereits auf alle
Spalten).

## 9. Freiraum auf breiten Displays: „Raum arbeitet für den Fokus"

**Problem:** Auf einem 27"+-Display bleibt neben dem zentrierten Board
Freifläche. Hart links gepackt wirkte sie tot, zentriert wirkt sie als
Rahmen — aber sie soll sich *verdient* anfühlen, nicht übrig.

**Baustein 1 — Asymmetrisch atmende Spalten (Kern-Empfehlung).**
Zusätzliche Breite geht zuerst dorthin, wo gearbeitet wird: Die
Arbeitsspalten („Als Nächstes", „In Bearbeitung") dürfen bis ~440 pt
wachsen, die Ablagen (Backlog, Erledigt) sind bei ~320 pt gedeckelt
(`layoutPriority` bzw. unterschiedliche maxWidth). Das Aufmerksamkeits-
Gefälle aus Punkt 8 bekommt damit auch eine horizontale Dimension: breite
Bühne in der Mitte, schmale Regale an den Rändern. Der Restfreiraum
schrumpft spürbar und das Board wirkt komponiert statt gleichförmig.

**Baustein 2 — Ambient-Bilanz im Freiraum (VOM PO ABGELEHNT, bleibt nur
als dokumentierte Idee).**
Ist das Fenster deutlich breiter als das Board (~200 pt Rest pro Seite),
erscheint unten links im Freiraum eine einzige stille Zeile in Tertiärfarbe:

    Heute 3 · Woche 12 · Bester Lauf 14 Tage

Keine Box, kein Icon — nur Typografie auf dem Fensterglas, wie eine
Gravur am Rand des Schreibtischs. Auf schmalen Fenstern existiert sie
nicht (kein Chrome-Comeback durch die Hintertür); die Details bleiben im
Streak-Popover.

**Bewusst verworfen:**
- *Inspector-/Detailspalte im Freiraum* (Klick auf Karte zeigt Details
  rechts) — dupliziert die Erinnerungen-App und weicht die Read-only-
  Philosophie auf.
- *Quick-Drop-Zonen beim Ziehen* („hier fallen lassen → Erledigt" am
  Rand) — Gimmick, zerstört die Ruhe.
- *Uhr/Datum/Widgets im Freiraum* — dupliziert Menüleiste bzw. gehört
  ins WidgetKit-Thema (BACKLOG.md).
- *Fensterglas im Freiraum durchsichtiger machen* — technisch nicht
  regional steuerbar, und der Desktop schimmert ohnehin schon durch.

## Umsetzungsreihenfolge (wenn freigegeben)

1. Layout + Karten inkl. kompakter Randspalten (Punkte 1–3, 8) — größter
   visueller Hebel
2. Chrome: Ticket-Button, Zitatleiste raus, Streak-Popover (4–6)
3. Sensorik/Motivation (7) — einzeln aktivierbar, jede Mechanik ein Commit

Offene Frage an den Product Owner:
- Soll der „Neues Ticket"-Button direkt eine bestimmte Liste in Erinnerungen
  öffnen (Standardliste aus den Einstellungen)?
