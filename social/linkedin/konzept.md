# LinkedIn-Post „Glass Kanban" — kurzes Video, zwei Ideen (05.09.2026)

Zweck: ein **kurzes Video** (bzw. GIF-artiger Loop) für einen Beitrag auf Davids LinkedIn-Profil,
das das Board in Bewegung zeigt und als Aufhänger für einen Text über **KI beim App-Bau** und/oder **Personal Kanban** dient.
Anspruch laut Auftrag: professionell, realistisch, aktueller Projektstand, stylisch —
beeindrucken durch Understatement.

Dieses Dokument ist kein Bauplan im Sinne von `plans/README.md` (es betrifft kein
App-Verhalten), sondern die Produktionsgrundlage für den Beitrag — und die Vorlage für
den nächsten Clip. Es lebt in `social/`, weil es Projektwissen braucht (Demo-Datensatz,
Animationszeiten, Texte) und weil der Demo-Datensatz zugleich Phase 3 aus RELEASE.md
bedient. **Wie der Clip neu erzeugt wird, steht in `README.md` in diesem Ordner** —
Schritt für Schritt mit Nachweisen, am 05.09.2026 so durchlaufen. Dieses Dokument ist das
Warum und die Texte.

---

## Ergebnis (05.09.2026, nach der Umsetzung) — gilt vor allem Folgenden

Das Video, das gebaut wurde, weicht in vier Punkten von den Abschnitten 2.3–2.5 und Anhang A ab.
Wo unten etwas anderes steht, gilt dieser Block; die Herleitung stand im Messprotokoll des
Umsetzungsplans (gelöscht am 05.09.2026 mit dem Umzug nach `social/`, in der Git-Historie
unter `plans/linkedin/umsetzungsplan.md`).

| | Konzept (ursprünglich) | Gebaut |
|---|---|---|
| Bildausschnitt | rechte Boardhälfte, 692 pt breit | **ganzes Fenster** — Davids Vorgabe: die App steht im Vordergrund, nicht der Hintergrund |
| Format | 4:5 Hauptdatei, 1:1 zweitrangig | **1:1, 1080 × 1080** — 4:5 ist auf diesem Bildschirm physisch unmöglich (Board in voller Breite bräuchte 1575 pt Höhe, der Schirm hat 1440) |
| Fenster | 1300 × 612 pt (Mindesthöhe) | **1220 × 1000 pt** — Board-Mindestbreite ist 1220, nicht 1240; das Fenster wird hoch gezogen, damit es das Quadrat füllt (97 % Breite, 79 % Höhe, Desktop-Anteil 23 %); Rand 20 pt seitlich, 130 pt oben/unten, **echt mitaufgenommen**, nie nachträglich gefüllt |
| Datensatz | 22 Tickets, zwei Listen | **18 Tickets, eine sichtbare Liste**, alle Titel ≤ 28 Zeichen (keine Ellipse bei 1220 pt), eine wiederkehrende Karte als Falz — `seed-demo-reminders.swift` v2 |
| Länge / Loop | ≈ 7 s, Überblendung zurück zum Start | **≈ 4 s, harter Schnitt** — die Überblendung erzeugte Geistertext und einen BT.601-Farbsprung; Clip beginnt mit dem Zeiger auf der Karte (keine Anfahrt), 0,5 s Ruhe, Zug, Settle, Durchstrich, Flamme 6 → 7 |
| Aufnahme | `screencapture -v` | **ffmpeg/AVFoundation** (`record.sh`) — `screencapture` lieferte ein eingefrorenes Standbild. Display auf 2560 × 1440 HiDPI (`displayplacer` mode 43), Aufnahme 2× |
| Zug | Davids Hand | **synthetisch per computer-use auf HID-Ebene** — der Hintergrund-Drag scheitert, der HID-Drag läuft durch (CLAUDE.md-Notiz vom 14.08. präzisiert) |

Das grüne Kopier-Plus, das während des Ziehens am Zeiger hing, war App-Verhalten
(`.draggable` + `.dropDestination` melden macOS keine Operation → Standard *copy*). Auf
Davids Entscheidung am selben Tag behoben: beide Drop-Ziele (Spalte und Board-Rückhalt)
melden jetzt `DropProposal(operation: .move)` — Branch `feature/drag-move-operation`,
Nachweis per Zeiger-Frames über Spalte und Spaltenlücke. Die Endfassung (Take 14) zeigt
den Zeiger als schlichten Pfeil.

Ergebnisdateien: MP4, GIF und Thumbnail liegen hier im Ordner (`glass-kanban-one-move-1x1.*`,
`glass-kanban-thumbnail-1x1.png`). Kontrollframes, Nachweise, Rohtake (`take14.mov`) und die
verworfenen Fassungen (`alt-*`) bleiben außerhalb des Repos in
`~/Movies/GlassKanban-LinkedIn/final/`. Idee A („Drei Züge") wurde nicht gedreht — sie passt nicht in den Ausschnitt.

---

## 0. Befunde vor dem Konzept

Am 05.09.2026 gemessen, nicht geschätzt:

| Befund | Folge für die Produktion |
|---|---|
| Der Mac ist ein **Mac mini (Mac14,12) an zwei QHD-Displays ohne Retina** (2560×1440, „UI looks like 2560×1440", also 1×). Ein Fenster-Screenshot lieferte 1500×950 px. | Eine 1×-Aufnahme ist für ein Video, das Qualität transportieren soll, zu weich (Text 15 px). Es braucht **2×-Pixel**: HiDPI-Modus oder virtuelles Display (Abschnitt 2.4). |
| Das Board zeigt aktuell **echte private Karten** (Handyvertrag, Versicherung, Einkaufsliste, Namen). | Nichts davon darf ins Video. Demo-Listen anlegen und in den Einstellungen **nur diese** auswählen — die echten Daten bleiben unberührt (Abschnitt 2.1). |
| Bei 870 pt Fensterhöhe sind die Spalten zu **zwei Dritteln leer**. Eine 1:1-Beschneidung des Screenshots zeigt hauptsächlich graue Mulde. | Fensterhöhe auf ~640 pt drücken, Backlog mit 10 Karten füllen. Dann ist die Spalte ein gefülltes Objekt, kein Container. |
| „In Bearbeitung" zeigt leer den Platzhalter **„Fertigwerden beginnt hier"**, „Als Nächstes" leer **„Wählen statt sammeln"**. | Kommt im Video nicht vor (In Bearbeitung startet mit einer Karte, damit das Limit früh greift), bleibt aber für Thumbnail oder Store-Screenshot die stärkste Ruhe-Einstellung. |
| WIP-Dialog: Titel **„Über deinem Limit"**, Text **„Weniger gleichzeitig, mehr fertig"**, Standardknopf **„Erst abschließen"** (Return). | Der Dialog ist die stärkste Szene für den Kanban-Text. Return im Video zeigt: die bequemste Antwort respektiert das Limit. |
| Bewegung in der App: Kartenzug `spring(0.22 s, bounce 0.18)`, Settle-Pause 240 ms, dann Durchstrich; Flamme nickt; eigener Erledigt-Klang `CompletionChime.wav` (aufsteigende Quinte). | **Nichts davon im Schnitt beschleunigen.** Die Belohnungsmomente sind das Design. Nur Leerlauf zwischen den Zügen kürzen. |
| Erledigt zeigt die **letzten 7 Tage**, die Flamme zählt aufeinanderfolgende Tage mit Erledigung. | Demo-Erledigungen auf sechs aufeinanderfolgende Tage rückdatieren → Flamme „6". Die Erledigung im Video macht daraus **„7"** — ein sichtbarer, kleiner Tick. Keine „47": das wäre Prahlerei. |
| `ffmpeg` und ImageMagick sind **nicht installiert**. | `brew install ffmpeg` vor dem Schnitt (Abschnitt 3.6). |

---

## 1. Haltung: Wie Understatement hier aussieht

Die App spricht wie ein Werkzeug (CONCEPT.md, „Ton der Texte"). Der Beitrag muss dasselbe
tun, sonst widerspricht die Verpackung dem Inhalt. Daraus folgen feste Regeln für beide Ideen:

1. **Zeigen statt behaupten.** Kein Text *auf* dem Board, kein Badge, kein „built with AI",
   keine Pfeile, keine Callouts. Glas ist Chrome, nie Inhalt — das gilt auch für das Video.
2. **Die echte App, echte Daten-Form, echter Cursor.** Keine Nachbau-Animation in After Effects
   oder HTML. Der Cursor bleibt sichtbar: Eine Karte, die sich „von selbst" bewegt, sieht nach
   Mockup aus; eine Hand, die zieht, nach Werkzeug.
3. **Keine Musik.** LinkedIn spielt stumm an; wer Ton einschaltet, hört nur, was die App selbst
   macht: den Erledigt-Klang. Das ist ein Detail, das nur Aufmerksame bekommen — genau richtig.
4. **Die Meta-Ebene ist der einzige Witz:** Das Board zeigt **den eigenen Release-Backlog der
   App** (aus RELEASE.md Phase 3 und den echten Commits der letzten Tage). Die letzte Karte,
   die auf „Erledigt" landet, heißt **„LinkedIn-Video aufnehmen"**. Wer's merkt, lächelt; wer
   nicht, sieht ein glaubwürdiges Projekt-Board. Kein Erklärtext dazu — höchstens ein Halbsatz
   im Post.
5. **Der Text trägt die Botschaft, das Video trägt den Beweis.** Alles über KI, Kanban,
   Arbeitsweise steht im Beitragstext. Das Video wäre auch ohne Text verständlich.
6. **Klein bleiben.** Sechs bis zwölf Sekunden, ein fester Bildausschnitt, keine Kamerafahrt,
   kein Intro, kein Outro, kein Logo. Das Video hat den Rhythmus der App: ein Zug, ein Atem,
   Ruhe. Was in zwölf Sekunden nicht gesagt ist, gehört in den Text.

---

## 2. Gemeinsame Grundlage beider Ideen

### 2.1 Demo-Datensatz (zugleich RELEASE.md Phase 3, „Demo-Datensatz")

Angelegt per `seed-demo-reminders.swift` (Fassung v2 vom 05.09.2026, gegen den echten Store
gelaufen; `--remove` räumt auf). Dasselbe Skript schreibt die Spalten (`next`/`inProgress`)
direkt in die `columns.json` der App — deshalb muss die App dabei **geschlossen** sein; das
Skript verweigert sonst. Alle Daten sind relativ zu heute, der Seed ist vor jeder Aufnahme
neu zu setzen (README.md, Schritt 1).

**18 Tickets in einer sichtbaren Liste „Glass Kanban"** (ein Akzent statt Blau/Grün-Mischung;
„Privat" wird leer angelegt). Jeder Titel hat höchstens 28 Zeichen, damit bei 1220 pt keine
Ellipse entsteht:

| Spalte | Karten | Merkmale |
|---|---|---|
| Backlog (7) | Datenschutzerklärung `!!`, App-Store-Screenshots, TestFlight-Beta starten, Produktseite bauen, Listing-Texte schreiben, Einführungspreis festlegen, Wochenrückblick | Wochenrückblick ist wöchentlich, fällig in 3 Tagen → Falz „1 noch nicht fällig" |
| Als Nächstes (3 / 5) | Demo-Liste anlegen, Deep-Link entfernen, Onboarding kürzen | je eine kurze Notiz |
| In Bearbeitung (2 / 2) | Doku-Konsistenz prüfen, **LinkedIn-Video aufnehmen** | die LinkedIn-Karte ist die, die zieht: `!!`, fällig heute (Chip „Heute") |
| Erledigt (6) | iCloud-Sync-Grundlage, Bildschirm-Zuordnung, Spalte in eigene Datei, Deutsche Lokalisierung, Durchlaufzeit im Rückblick, WIP-Dialog gebaut | je eine pro Tag, sechs Tage in Folge → Flamme **6**, nach dem Zug **7** |

Warum so: Alle Titel sind wahr (das Projekt hat diese Aufgaben wirklich), keiner ist privat
im Sinn von „gehört nicht auf LinkedIn", keiner enthält Namen, Beträge oder Firmen. Der
Falz mit „1 noch nicht fällig" und der Chip „Heute" sind zwei stille Details, die Kenner der
App-Philosophie wiedererkennen — ohne dass etwas erklärt wird.

**Bewusst weggelassen:** eine überfällige Karte (rotes „Überfällig"-Badge). Realistisch wäre
sie, aber sie ist das einzige laute Element der Oberfläche und würde im Standbild dominieren.

### 2.2 Einstellungen der App für die Aufnahme

| Einstellung | Wert | Grund |
|---|---|---|
| Listen-Auswahl | nur „Glass Kanban" und „Privat" | private Daten bleiben draußen, ohne sie anzufassen |
| WIP-Limit „In Bearbeitung" | **2** | eine Karte liegt schon, die zweite füllt, die dritte fragt — der Dialog kommt in Idee A beim zweiten Zug |
| WIP-Limit „Als Nächstes" | 5 (Standard) | Kapsel zeigt „3 / 5" bzw. „2 / 5", wirkt geplant, nicht knapp |
| Erledigt-Klang | an | wird als Tonspur unter die Erledigt-Szene gelegt |
| Erscheinungsbild | **Hell** | siehe 2.3 |
| Systemsprache | Deutsch | Beitrag ist deutsch; englische Variante später aus derselben Aufnahme unmöglich, also entscheiden: Deutsch |
| „Noch nicht Fälliges einklappen" | an (Standard) | erzeugt die Falz-Zeile |

### 2.3 Look: Fenster, Hintergrund, Modus

- **Hellmodus.** Der LinkedIn-Feed ist weiß; ein dunkles Fenster wäre der laute Kontrast, ein
  helles Fenster auf warmem Hintergrund ist die Minimal-Desk-Setup-Referenz aus CONCEPT.md.
  Dunkel bleibt eine mögliche zweite Variante für später (und ein App-Store-Screenshot).
- **Hintergrund:** Das Toolbar-Glas braucht *Struktur* dahinter, sonst liest es sich als
  flaches Grau (der Screenshot vom 05.09. zeigt genau das). Zwei Kandidaten, am Testframe
  entscheiden: (a) das macOS-Standard-Wallpaper in der hellen Variante, (b) ein weicher,
  warm-grauer bis sandfarbener Verlauf mit leichter Vignette. Kein Foto mit Motiv, kein
  Schreibtisch-Stockbild.
- **Fenstergröße:** 1300 × 612 pt (Board-Mindestbreite 1220 pt — gemessen 05.09., nicht 1240 — plus Luft; 612 ist die
  Mindesthöhe, gemessen 05.09.). Fenster mittig, rundum 60–80 pt Wallpaper sichtbar, Dock ausgeblendet,
  Menüleiste außerhalb des Aufnahmebereichs, Schreibtisch-Symbole aus.
- **Cursor:** macOS-Standard, normale Größe.

### 2.4 Auflösung: 2×-Pixel auf einem 1×-Mac

Der Mac mini hat kein Retina-Display. Drei Wege, in dieser Reihenfolge probieren:

1. **Systemeinstellungen → Displays → mit ⌥ auf „Skaliert"**: prüfen, ob das Dell einen
   „1280 × 720 (HiDPI)"-Modus anbietet. Dann rendert alles 2× auf 2560 × 1440 physische
   Pixel. Nachteil: Nur 1280 pt Breite, das Board (min. 1240 pt) passt gerade so, kaum Rand.
2. **BetterDisplay** (Freemium): virtuelles Display 1440 × 900 HiDPI → 2880 × 1800 px. Das ist
   **exakt das Mac-App-Store-Screenshot-Format** aus RELEASE.md — ein Setup für beides. Fenster
   auf das virtuelle Display schieben, dort aufnehmen. Empfohlen.
3. Ein MacBook mit Retina-Display leihen und die App dort starten (Build liegt als
   `Glass Kanban.app` im Projektordner, `columns.json` ist gerätelokal — Demo-Spalten dort
   erneut setzen).

Ohne einen dieser Schritte **nicht aufnehmen**. Das ist der eine Punkt, an dem Qualität
hängt und den kein Schnitt rettet.

### 2.5 LinkedIn-Formatfakten (Stand der Plattformregeln, vor dem Upload gegenprüfen)

| | Wert | Folge |
|---|---|---|
| **GIF** | LinkedIn spielt hochgeladene GIFs im Beitrag **nicht** ab — sie landen als Standbild. Bewegung im Feed gibt es nur als Video. | „GIF" heißt hier: **kurzer MP4-Loop**. Eine echte `.gif`-Datei entsteht zusätzlich aus demselben Schnitt für README, Slack, Messenger. |
| Seitenverhältnis | 4:5 (1080 × 1350) gilt 2026 als Optimum für den mobilen Feed (füllt fast die ganze Höhe, ohne in den Vollbildmodus zu kippen); 1:1 ist die sichere Universalwahl; 9:16 wird im Video-Tab gepusht, passt aber nicht zu einem querformatigen Board und zu 40–50 % Desktop-Nutzern; 16:9 wirkt klein | **4:5 als Hauptdatei, 1:1 als Zweitdatei** — derselbe Ausschnitt in der Breite, 4:5 hat nur mehr Wallpaper oben und unten. Recherche 05.09.2026, Quellen im Messprotokoll |
| Länge | 3 s bis 10 min erlaubt; kurze Videos werden zu Ende gesehen und wiederholt; die ersten 2 s entscheiden, ob gescrollt wird | Idee A ≈ 12 s, Idee B ≈ 7 s |
| Codec | MP4, H.264, 30 fps, AAC-Tonspur (auch wenn still), ≤ 10 Mbit/s | Export in 3.6 |
| Ton | Autoplay stumm; ~80 % sehen ohne Ton | Video muss stumm funktionieren; der Erledigt-Klang ist Bonus |
| Loop | Feed-Videos starten automatisch und wiederholen sich in der Regel; nicht garantiert | Idee B wird so geschnitten, dass Ende und Anfang aneinanderpassen |
| Thumbnail | eigenes Vorschaubild möglich | Frame mit angehobener Karte (3.7) |

*(Überholt — siehe „Ergebnis" oben: gebaut wurde das ganze Fenster in 1:1.)* Der Ausschnitt zeigt die rechte Hälfte des Boards (In Bearbeitung und Erledigt, links
angeschnitten Als Nächstes) in Lesegröße, oben die Toolbar (ohne die Flamme, siehe 4.2), rechts
und oben Wallpaper. Die **Breite** des Ausschnitts entscheidet über die Textgröße auf dem
Telefon, deshalb sind 1:1 und 4:5 gleich lesbar: 4:5 legt nur oben und unten Wallpaper dazu,
das Fenster liegt dann wie ein Objekt mittig im Hochformat. Beide Ideen nutzen denselben
festen Ausschnitt — eine Kamerafahrt wäre Bewegung, die nicht aus der App kommt. `cut.sh`
liefert jede Datei in beiden Formaten (`-4x5`, `-1x1`), aufgenommen wird mit 130 pt Rand
oben und unten (`record.sh`).

---

## 3. Idee A — „Drei Züge" (12 Sekunden)

### 3.1 Die Idee in drei Sätzen

Fester Bildausschnitt, drei Züge, zwölf Sekunden: Eine Karte kommt nach „In Bearbeitung" und
zappelt kurz; eine dritte will nachrücken, und das Board fragt — „Weniger gleichzeitig, mehr
fertig" — Return, sie gleitet zurück; dann wird die erste erledigt: Settle, Atem, Durchstrich,
Flamme. Drei Züge, die zusammen die ganze Regel erzählen: anfangen, begrenzen, fertig werden.
Nichts wird erklärt, nichts bewegt sich außer der Hand und der Antwort der App.

### 3.2 Storyboard mit Zeitcode (12 s)

Bildausschnitt wie in 2.5 (rechte Boardhälfte, fest). Stand vor dem ersten Zug: Als Nächstes
angeschnitten mit drei Karten, In Bearbeitung mit **einer** Karte („Doku-Konsistenz prüfen",
„1 / 2"), Erledigt sieben Karten, Flamme „6".

| Zeit | Bild | Was der Zuschauer sieht | Ton |
|---|---|---|---|
| 0:00–0:01 | Ruhe | Cursor liegt still auf „LinkedIn-Video aufnehmen" am linken Bildrand (Hover-Schatten) | — |
| 0:01–0:03 | **Zug 1:** „LinkedIn-Video aufnehmen" → In Bearbeitung | Karte gleitet ins Bild, Spring-Settle, kurzes Zappeln (Größen-Pop). Kapsel „1 / 2" → „2 / 2", färbt sich | — |
| 0:03–0:04 | Ruhe | 1 s | — |
| 0:04–0:07,5 | **Zug 2:** „Demo-Liste für Screenshots anlegen" → In Bearbeitung → **Dialog** | Karte landet, das Glas-Blatt erscheint: „Über deinem Limit — Weniger gleichzeitig, mehr fertig". **1,5 s stehen lassen.** Return. Karte gleitet zurück aus dem Bild | — |
| 0:07,5–0:08,5 | Ruhe | 1 s | — |
| 0:08,5–0:10 | **Zug 3:** „LinkedIn-Video aufnehmen" → Erledigt | Karte legt sich ab, **240 ms Atem**, Durchstrich zieht über den Titel; Kapsel „2 / 2" → „1 / 2" (Flamme außerhalb des Ausschnitts) | **Erledigt-Klang** |
| 0:10–0:12 | Ruhe | Cursor gleitet langsam aus dem Bild. Aus | — |

Kein Zoom-out, kein Schlussbild. Das letzte Frame ist das Board nach dem dritten Zug.

### 3.3 Bild- und Schnittregeln

- **Keine Kamerabewegung.** Der Ausschnitt steht von Frame 1 bis zum Ende. Bewegung gehört
  Ereignissen — das gilt für das Video wie für das Board.
- Skalierung: aus der 2×-Aufnahme so ausschneiden, dass 15-pt-Titel auf dem 1080-Canvas
  ~22 px hoch sind (Faktor ≈ 0,75 der 2×-Pixel). Auf dem Telefon sind das rund 8 pt, die
  Grenze der Lesbarkeit.
- **Der Dialog muss im Ausschnitt liegen.** Er erscheint mittig über dem Fenster; das Fenster
  vor der Aufnahme so setzen, dass die Mitte des Fensters im rechten Drittel des Ausschnitts
  liegt — am Testframe prüfen, notfalls Ausschnitt nach links verschieben.
- Nichts beschleunigen. Leerlauf zwischen den Zügen auf die Zeiten oben trimmen, die Züge
  selbst unangetastet.

### 3.4 Was **nicht** ins Video kommt

Kein Backlog-Zug, kein Karten-Editor, keine Statistik, kein Zoom-out auf das ganze Board.
Zwölf Sekunden, drei Züge, eine Regel. Wer das ganze Board sehen will, findet es im
Thumbnail (3.7) oder im Repository.

### 3.5 Aufnahme — Drehbuch für David (die Züge kann nur eine echte Hand machen)

Vorbereitung (kann Claude weitgehend übernehmen, Abschnitt 6):

- [ ] Alte App-Instanzen beenden, App aus dem Projektordner starten
- [ ] Demo-Listen seeden (README.md, Schritt 1); das Skript schreibt die Spalten: „Doku-Konsistenz
      prüfen" in In Bearbeitung, die drei anderen laut 2.1 in Als Nächstes
- [ ] Einstellungen wie 2.2, Fenster wie 2.3, Display wie 2.4
- [ ] Testframe (`screencapture -l <windowID>`), daraus den 1:1-Ausschnitt schneiden:
      Lesbarkeit, Dialog-Position, Rand, Glas-Struktur
- [ ] QuickTime → Ablage → Neue Bildschirmaufnahme → Bereich um das Fenster mit Rand;
      Optionen: Mauszeiger anzeigen, Mausklicks **nicht** hervorheben; Mikrofon aus

Der Take (drei Wiederholungen, die ruhigste gewinnt; zwischen den Takes ⌘Z dreimal):

1. Cursor auf „LinkedIn-Video aufnehmen" legen, **2 s still halten**
2. Zug 1 — ruhig nach In Bearbeitung ziehen (~1 s), loslassen, **2 s warten**
3. Zug 2 — „Demo-Liste …" nach In Bearbeitung ziehen, Dialog kommt, **2 s nichts tun**, Return,
   2 s warten
4. Zug 3 — „LinkedIn-Video aufnehmen" nach Erledigt ziehen, **3 s warten**
5. Cursor langsam nach unten rechts aus dem Fenster, Aufnahme stoppen

Regeln beim Ziehen: nicht zu schnell, nicht zittern, nicht über anderen Karten schweben
(Hover-Schatten ist Rauschen), in der Mitte der Zielspalte loslassen. Misslingt ein Zug:
⌘Z, Take neu — bei zwölf Sekunden lohnt kein Flicken.

### 3.6 Schnitt — reproduzierbar per Skript, kein Klick-Programm

Werkzeug: `ffmpeg` (`brew install ffmpeg`). Der Schnitt ist ein Skript im Projekt
(`social/linkedin/cut.sh`, entsteht nach dem ersten Take), damit ein zweiter Take denselben
Schnitt bekommt.

Bausteine:

1. **Trim** der Take-Datei auf die Abschnitte (Zeitmarken aus dem Take ablesen), Ruhephasen
   auf die Zeiten aus 3.2 kürzen, Züge selbst unangetastet (kein `setpts`).
2. **Ausschnitt:** fester `crop=W:H:X:Y` (W = H, aus dem Testframe), dann
   `scale=1080:1080:flags=lanczos`.
3. **Ton:** `-i GlassKanban/CompletionChime.wav` mit `adelay` an die Erledigt-Marke, sonst
   Stille (`anullsrc`), damit die Datei eine Tonspur hat.
4. **Export:** `-c:v libx264 -profile:v high -crf 18 -pix_fmt yuv420p -r 30 -movflags +faststart`,
   AAC 128 kbit/s. Erwartete Größe 3–8 MB.
5. **Abnahme:** in QuickTime bei Telefonbreite (≈ 390 pt) ansehen: Titel lesbar, Dialog ganz
   im Bild, Durchstrich und Flamme sichtbar.

### 3.7 Standbild-Ableger aus demselben Material

Ein Frame aus Zug 3 — die Karte angehoben über Erledigt, Hover-Schatten, Cursor sichtbar —
ist das Vorschaubild (LinkedIn erlaubt ein eigenes Thumbnail) und, falls je ein Bild-Post
gebraucht wird, das Bild.

### 3.8 Aufwand und Risiken

| | |
|---|---|
| Aufwand | Vorbereitung 1–2 h (davon Display-Setup der größte Unbekannte), Aufnahme 15 min, Schnitt 1 h, Abnahme 15 min |
| Risiko 1 | **Kein HiDPI-Weg** auf dem Mac mini funktioniert → 1× ist nicht akzeptabel; MacBook leihen |
| Risiko 2 | Drag per Hand nicht sauber → Takes wiederholen; Züge lassen sich nicht synthetisch erzeugen (CLAUDE.md) |
| Risiko 3 | Dialog liegt außerhalb des Ausschnitts → am Testframe prüfen (3.3) |
| Risiko 4 | Streak-Zahl weicht ab („6 → 6") → vor dem Take im Statistik-Fenster prüfen; notfalls Erledigt-Daten um einen Tag verschieben |
| Risiko 5 | Zwölf Sekunden mit Dialog sind für Nicht-Kanban-Leser eine Sache zu viel → dann Idee B |

---

## 4. Idee B — „Ein Zug" (7 Sekunden, Loop)

### 4.1 Die Idee in drei Sätzen

Ein einziger Zug, sieben Sekunden: Eine Karte wird von „In Bearbeitung" nach „Erledigt"
gezogen, legt sich ab, atmet einmal, und der Durchstrich zieht über den Titel. (Die Flamme
nickt dabei links in der Toolbar — im 1:1-Ausschnitt nicht sichtbar; ein Ausschnitt, der sie
zeigt, verlöre Erledigt. Der Durchstrich ist der Moment, die Flamme steht im Text.) Kein Dialog, kein zweiter Zug — nur der eine Moment, für den die
App gebaut ist. Das Video ist so geschnitten, dass es beim Wiederholen ohne Sprung von vorn
beginnt, und funktioniert dadurch wie ein GIF im Feed. Es ist die kürzeste Form, in der die
App noch sie selbst ist: ein Zug, ein Atem, Ruhe.

### 4.2 Storyboard mit Zeitcode (7 s, Loop-fähig)

Bildausschnitt wie 2.5 und 3.3, fest. Stand: „In Bearbeitung" mit zwei Karten („2 / 2":
„LinkedIn-Video aufnehmen" oben, „Doku-Konsistenz prüfen" darunter), „Erledigt" mit acht.
**Das ist der Zustand, den das Seeding hinterlässt** (seit 05.09. liegt die LinkedIn-Karte
für Idee B direkt in In Bearbeitung; für Idee A zieht David sie vor dem Take zurück nach Als
Nächstes).

| Zeit | Bild | Ton |
|---|---|---|
| 0:00–0:01 | Ruhe. Cursor liegt still auf „LinkedIn-Video aufnehmen" (Hover-Schatten sichtbar — die Karte ist schon „gefasst") | — |
| 0:01–0:02,5 | Zug: Karte hebt sich, gleitet nach Erledigt (ruhige Hand, ~1 s), Spring-Settle | — |
| 0:02,5–0:02,8 | **Atem** (240 ms Settle-Pause, unangetastet) | — |
| 0:02,8–0:03,5 | Durchstrich zieht über den Titel; Kapsel „2 / 2" → „1 / 2" (die Flamme nickt links außerhalb des Ausschnitts) | **Erledigt-Klang** |
| 0:03,5–0:06 | Ruhe. Cursor gleitet langsam aus dem Bild (nach unten rechts) | — |
| 0:06–0:07 | **Rückblende:** 0,6 s Überblendung auf das erste Frame — Karte zurück in In Bearbeitung. Dann beginnt der Loop | — |

Die Überblendung am Ende ist der einzige Schnitt-Eingriff, der nicht aus der App kommt. Sie
ist nötig, weil ein Loop sonst mit einem Sprung beginnt — und sie ist ehrlich: Jeder sieht,
dass zurückgespult wird, niemand glaubt, die Karte springe von selbst zurück. Alternative
ohne Überblendung: 1,5 s Schwarz (Fade) zwischen Ende und Anfang. Beides am Schnitt
vergleichen, die ruhigere Variante nehmen.

### 4.3 Warum das trotz sieben Sekunden trägt

- Der eine Zug enthält **alle drei Belohnungsmomente** der App: Settle, Durchstrich, Flamme.
  Die Reibung des WIP-Dialogs fehlt — die gehört zu Idee A.
- Sieben Sekunden werden im Feed fast immer zu Ende gesehen; beim zweiten Durchlauf entdeckt
  man die Flamme, beim dritten den Atem vor dem Durchstrich. Das ist der Loop-Effekt: Das
  Video wird beim Wiederholen *besser*, nicht langweiliger.
- Der Beitragstext trägt hier mehr Last als bei Idee A, weil das Bild nur eine Sache sagt:
  fertig. Deshalb passt zu B der Kanban-Text (7.2), dessen erster Satz genau der Dialog ist,
  den das Video **nicht** zeigt — Bild und Text ergänzen sich, statt sich zu wiederholen.

### 4.4 Aufnahme und Schnitt

- Aufnahme wie 3.5, aber nur **ein** Zug: Cursor 2 s still auf der Karte, ziehen, 4 s warten,
  Cursor raus. Drei Takes, der ruhigste gewinnt. Die Karte vorher mit ⌘Z zurückholen.
  Ist ein Take von Idee A sauber, ist dessen Zug 3 bereits dieses Video.
- Schnitt wie 3.6: fester `crop`, Trim, Klang, dann Loop-Überblendung
  (`xfade=transition=fade:duration=0.6` gegen ein 1-s-Standbild des ersten Frames).
- Zusätzlich echte GIF-Datei für andere Kanäle: `palettegen`/`paletteuse` bei 20 fps,
  720 px Kante, Erwartung 3–6 MB. Nicht für LinkedIn.

### 4.5 Aufwand und Risiken

| | |
|---|---|
| Aufwand | Vorbereitung wie A (1–2 h, davon Display der größte Posten), Aufnahme 10 min, Schnitt 45 min — oder null, wenn aus Take A geschnitten |
| Risiko 1 | Ohne den Dialog zeigt das Video nicht, was das Board von jedem anderen unterscheidet — es zeigt, wie sich Fertigwerden *anfühlt*. Das ist ein anderes, kleineres Versprechen; der Text muss den Rest tragen |
| Risiko 2 | Loop-Sprung wirkt billig → Überblendung sauber setzen, auf dem Telefon prüfen |
| Risiko 3 | Zu wenig Bewegung für den Feed-Algorithmus in den ersten 2 s → Cursor-Hover ab Frame 1, Zug ab 1,5 s |

---

## 5. Empfehlung

**Idee B — „Ein Zug", sieben Sekunden — als Beitrag.** Idee A entsteht aus derselben
Vorbereitung und demselben Take-Tag und liegt bereit, falls der Beitrag den WIP-Dialog
braucht. Begründung:

- Die Vorgabe lautet: ganz kurz, wirksam, minimal, ruhig. B hat den Rhythmus der App —
  ein Zug, ein Atem, Ruhe — und nichts, was man weglassen könnte. A ist schon eine Erzählung.
- Der eine Zug enthält alle drei Belohnungsmomente (Settle, Durchstrich, Flamme). Das ist der
  Teil der App, den niemand aus einem Screenshot erraten kann; der Dialog lässt sich in einem
  Satz im Text nachliefern, der Durchstrich nicht.
- Sieben Sekunden werden zu Ende gesehen und wiederholt; jeder Durchlauf zeigt ein Detail
  mehr. Ein Loop *ist* Understatement: Er drängt nicht, er liegt da.
- Als Loop bleibt B wiederverwendbar: README, Kommentar-Antworten, Messenger, später der
  Store-Auftritt.

Wann A statt B: wenn der Beitragstext über WIP-Limits und Reibung geht und das Video die
Frage zeigen soll, nicht nur die Antwort. Dann A mit dem Kanban-Text (7.2), B mit dem
KI-Text (7.1) — die Texte sind nicht an die Ideen gebunden.

---

## 6. Was Claude autonom erledigen kann — und was nicht

| Schritt | Claude | David |
|---|---|---|
| Demo-Listen anlegen und Spalten schreiben (`seed-demo-reminders.swift`) | ✅ | einmalig den macOS-Dialog „Zugriff auf Erinnerungen" für das Terminal bestätigen |
| Einstellungen der App setzen, Fenstergröße, Testframe | ✅ | — |
| HiDPI/BetterDisplay einrichten | ⛔ Systemeinstellung, Installation | ✅ |
| Wallpaper wählen, Dock ausblenden | ⛔ Systemeinstellung | ✅ (5 min) |
| Die Züge (B: einer, A: drei) | ⛔ Drag ist nicht synthetisierbar | ✅ (Drehbuch 4.4 bzw. 3.5) |
| Schnitt-Skript, Export, Abnahme auf Lesbarkeit | ✅ (`brew install ffmpeg` vorausgesetzt) | Freigabe des finalen Cuts |
| Loop-Schnitt und GIF-Export (Idee B) | ✅ | Freigabe |
| Upload, Beitragstext posten | ⛔ Veröffentlichung | ✅ |

---

## 7. Beitragstexte — zwei Entwürfe

Beide unter 1.300 Zeichen (LinkedIn zeigt ~210 Zeichen vor „mehr anzeigen" — der erste Satz
ist der Hook), keine Emojis, keine Hashtag-Wand (drei am Ende), Link zur App im ersten
Kommentar, nicht im Text. Ton: derselbe wie die App — benennen, nicht kommentieren.

### 7.1 Thema: KI beim App-Bau

> Das Board in diesem Video verwaltet seinen eigenen Release.
>
> Glass Kanban ist eine native macOS-App: ein Kanban-Board über Apple Erinnerungen, kein
> Server, kein Konto, keine Cloud. Gebaut an Abenden, zu zweit — ich und Claude Code.
>
> Was die KI gut konnte: Breite. Rund 10.000 Zeilen SwiftUI, 340 Tests, zwei Sprachen, eine
> Dokumentation, die Entscheidungen samt Datum festhält. Was sie nicht konnte: Nein sagen.
> Jede Karten-Tooltip, jede Motivationszeile, jedes pulsierende Signal, das sie vorschlug,
> wäre Rauschen gewesen. Die Entscheidung, was *nicht* gebaut wird, blieb Handarbeit — und
> war der größere Teil.
>
> Drei Regeln haben die App geformt: Glas ist Chrome, nie Inhalt. Bewegung gehört
> Ereignissen, nie Dauerzuständen. Reibung statt Verbot.
>
> Die Karte im Video heißt „LinkedIn-Video aufnehmen". Stimmt.
>
> #PersonalKanban #macOS #ClaudeCode

Prüfung gegen die sieben Fragen: Hook benennt einen Zustand (Meta-Ebene) ohne ihn zu
erklären. Die Zahlen stehen in einem Satz beisammen, nicht verteilt. Der letzte Absatz ist
der einzige Witz, mit einem Wort aufgelöst. Kein „stolz", kein „endlich", kein „Reise".

### 7.2 Thema: Personal Kanban

> Weniger gleichzeitig, mehr fertig.
>
> Diesen Satz zeigt mein Kanban-Board, wenn ich eine dritte Sache anfange, bevor eine fertig
> ist. Es verbietet nichts. Es fragt — und die bequemste Antwort ist Return: erst abschließen.
>
> Personal Kanban (Jim Benson, Tonianne DeMaria Barry) hat zwei Regeln: Arbeit sichtbar
> machen, begonnene Arbeit begrenzen. Alles andere ist Ausgestaltung. Die sieben Sekunden
> zeigen, was nach der Frage kommt: eine Karte, ein Durchstrich, ein Ton. Keine Punkte, keine
> Fanfare, kein Onboarding. Mehr nicht.
>
> Die App heißt Glass Kanban und liegt über Apple Erinnerungen. Sie ist noch nicht im Store.
> Was sie kann und warum, steht im ersten Kommentar.
>
> #PersonalKanban #WIPLimit #macOS

### 7.3 Erster Kommentar (beide)

> Repository mit Konzept, Spezifikation und Backlog: <GitHub-URL>. Die drei Dokumente sind
> die eigentliche Arbeit — die App ist das, was übrig blieb.

(URL per `gh repo view --json url` bestimmen, nicht raten.)

---

## 8. Produktionsplan — Reihenfolge und Kästchen

Befehle und erwartete Ergebnisse stehen in `README.md` in diesem Ordner.

**Session 1 — Grundlage (Claude, ~1 h, David für zwei Freigaben):**
- [ ] `seed-demo-reminders.swift` bauen und laufen lassen; Ergebnis in der Erinnerungen-App
      gegen 2.1 prüfen (Farben, Fälligkeiten, Wiederholung, Erledigt-Daten)
- [ ] Einstellungen setzen (README.md, Schritt 2), App starten, Flamme muss „6" zeigen (Schritt 4)
- [ ] Fenster 1300 × 640 pt, Testframe schießen, den festen 1:1-Ausschnitt daraus schneiden,
      **Ergebnis an David senden** (Lesbarkeit, Hintergrund, Rand)

**Session 2 — Display und Look (David, ~30 min):**
- [ ] HiDPI-Weg aus 2.4 wählen und einrichten
- [ ] Wallpaper, Dock, Schreibtisch-Symbole
- [ ] Testframe erneut (Claude), Freigabe des Looks

**Session 3 — Aufnahme und Schnitt (David 20 min, Claude 2–3 h):**
- [ ] Takes nach 4.4 (B, drei Takes) und 3.5 (A, drei Takes) — zusammen unter 20 Minuten
- [ ] `brew install ffmpeg`, `cut.sh`, Export B (1080 × 1080, ≈ 7 s, Loop) und A (≈ 12 s)
- [ ] GIF-Export von B für README und andere Kanäle
- [ ] Abnahme beider Dateien auf Telefonbreite; Thumbnail-Frame aus dem Erledigt-Zug

**Danach:**
- [ ] Demo-Listen stehen lassen (RELEASE.md Phase 3, „Demo-Datensatz" abhaken und auf dieses
      Dokument verweisen) oder mit `--remove` entfernen
- [ ] B posten; A bleibt als Reserve für einen späteren Beitrag über WIP-Limits
- [ ] Dieses Dokument nach dem zweiten Beitrag löschen oder unter RELEASE.md Phase 3 als
      Verweis eintragen — ein Plan, der länger lebt als sein Vorhaben, ist Drift

---

## 8a. Upload-Checkliste LinkedIn (Stand 05.09.2026)

Was die Datei mitbringt (von `cut.sh` sichergestellt, am synthetischen Take gemessen):

| Eigenschaft | Wert | Warum |
|---|---|---|
| Format | MP4, H.264 High, Level 4.0, `yuv420p` | LinkedIns sicherste Kombination; alles andere wird erst recht neu kodiert |
| Auflösung | 1080 × 1350 (4:5), dazu 1080 × 1080 (1:1) | 4:5 füllt den mobilen Feed, 1:1 als Reserve für Desktop-lastige Zielgruppen |
| Bildrate | konstant 30 fps | `screencapture` liefert variable Bildrate (gemessen `30/19`) — LinkedIn kommt damit schlecht klar, deshalb fest auf 30 |
| Farbe | BT.709 in allen drei Tags, TV-Range | LinkedIn kodiert neu; ohne saubere Tags rät der Encoder die Matrix und die Karten werden gelblich oder flau. **Die Tags müssen im Filtergraph gesetzt werden** (`setparams`), die Encoder-Optionen allein reichen nicht (gemessen) |
| Keyframes | jede Sekunde (`-g 30`) | sauberes erstes Bild als Vorschaubild, sauberer Loop-Anfang |
| Ton | AAC 48 kHz stereo, Stille außer dem Erledigt-Klang (−13,5 dB Spitze) | Autoplay ist stumm; wer einschaltet, hört nur den Klang. Kein Normalisieren nötig |
| Größe | unter 1 MB je Clip | weit unter dem Limit von 5 GB, Upload sofort |
| `faststart` | gesetzt | Wiedergabe beginnt vor dem vollständigen Laden |

Sicherheitszonen im 4:5-Bild: LinkedIn legt den Stumm-Schalter unten rechts und die
Restlaufzeit unten links über das Video — beides liegt im Wallpaper-Rand unter dem Fenster,
nicht auf den Karten (Fenster endet bei ~1130 von 1350 px). Oben liegt nichts.

Beim Posten (David):

1. **Nativ hochladen**, vom Desktop, als Video-Beitrag — kein YouTube-Link, kein
   „Dokument". Datei: `glass-kanban-one-move-4x5.mp4`.
2. **Vorschaubild** setzen: `glass-kanban-thumbnail-4x5.png` (erstes Bild, Cursor liegt still).
   Ohne eigenes Vorschaubild nimmt LinkedIn ein beliebiges Frame.
3. Kein Videotitel, keine Untertitel-Datei (keine Sprache). LinkedIns automatische
   Untertitel bleiben leer — in Ordnung.
4. Text aus Abschnitt 7 einsetzen; der erste Satz muss vor „… mehr anzeigen" stehen
   (~210 Zeichen). Kein Link im Text, Link als **erster Kommentar** direkt nach dem Posten.
   Drei Hashtags am Ende, keine Erwähnungen.
5. Nach dem Posten **auf dem Telefon prüfen**: Loop, Farben (Karten weiß, nicht gelblich),
   Lesbarkeit. Weicht die Farbe ab, ist es LinkedIns Neukodierung — dann 1:1-Datei testen,
   nicht die Tags im Schnitt ändern.
6. Beitrag in der ersten Stunde nicht bearbeiten (Bearbeitungen setzen die Verteilung zurück).
   Auf Kommentare in den ersten Stunden antworten.
7. Zeitpunkt: Dienstag bis Donnerstag, morgens zwischen 7 und 9 Uhr — Plattformdurchschnitt,
   kein Naturgesetz; das eigene Netzwerk entscheidet.

Zweitverwertung: `glass-kanban-one-move-4x5.gif` für README und Messenger; auf LinkedIn
**nicht** hochladen (bleibt dort ein Standbild).

## 9. Verworfen, damit es nicht wiederkommt

| Idee | Warum nicht |
|---|---|
| Board in HTML/After Effects nachbauen | Zeigt nicht den aktuellen Stand, sondern eine Behauptung. Widerspricht Regel 2 |
| Text-Overlays auf dem Board („Pull", „WIP 2", Pfeile) | Glas ist Chrome, nie Inhalt. Wer Pfeile braucht, hat das falsche Bild gewählt |
| Musikbett | Jede Musik ist eine Stimme. Die App hat keine |
| Dunkelmodus als Hauptvariante | Der laute Kontrast im weißen Feed; die Referenz ist das helle Desk-Setup. Als Zweitvariante für später offen |
| 16:9-Video | Auf dem Telefon ein Briefmarken-Board; der feste 1:1-Ausschnitt auf die rechte Hälfte löst das besser |
| Kamerafahrt, die der Karte folgt (Erstentwurf 05.09., 26 s, sechs Züge) | Bewegung, die nicht aus der App kommt, und zu lang. Bewegung gehört Ereignissen — auch im Video |
| Zoom-out auf das ganze Board als Schlussbild | Ein Schlussbild ist ein Outro. Das letzte Frame ist der Zustand nach dem Zug |
| Karte, die sich ohne Cursor bewegt | Sieht nach Mockup aus. Der Cursor ist die Hand |
| Streak „47" oder Milestone-Hinweis im Bild | Prahlerei; die Zahl im Video ist ein Tick von 6 auf 7, kein Trophäenschrank |
| Statistik-Popover im Video | Eigener Beitrag. Ein Video, eine Sache |
| Sprecher/Voice-over, Untertitel | Keine Sprache, keine Untertitel nötig; ein Sprecher wäre Coaching |
| Überfällige Karte im Video | Das einzige rote Element der App dominiert jedes Bild. Bleibt draußen |
| Dokument-Karussell (PDF) statt Video | Am 05.09. erwogen und verworfen: Standbilder zeigen weder Settle noch Durchstrich noch Klang — genau die Dinge, die der Beitrag zeigen soll |
| Echte `.gif`-Datei auf LinkedIn hochladen | Wird dort als Standbild angezeigt; der Loop kommt als MP4 |


---

## Anhang A — Ausführung

Ersetzt am 05.09.2026 durch `README.md` in diesem Ordner: der Ablauf, wie er für Take 14
tatsächlich gelaufen ist (Datensatz v2, Fenster 1220 × 1000 pt, ffmpeg/AVFoundation,
synthetischer Zug auf HID-Ebene, Marken per `marks.sh`). Die ursprüngliche Fassung mit den
Zwischenständen liegt in der Git-Historie.
