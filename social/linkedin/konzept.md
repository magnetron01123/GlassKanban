# LinkedIn-Clip „Ein Zug" — Konzept und Texte (05.09.2026)

Zweck: ein kurzer Video-Loop für einen Beitrag auf Davids LinkedIn-Profil, der das Board in
Bewegung zeigt und als Aufhänger für einen Text über **KI beim App-Bau** oder **Personal
Kanban** dient. Anspruch: professionell, aktueller Projektstand, beeindrucken durch
Understatement.

Dieses Dokument ist das Warum und die Texte. **Wie der Clip entsteht, steht in `README.md`
in diesem Ordner** — Schritt für Schritt mit Nachweisen. Die fertigen Dateien liegen daneben
(`glass-kanban-one-move-1x1.mp4`, `.gif`, `glass-kanban-thumbnail-1x1.png`). Es ist kein
Bauplan im Sinne von `plans/README.md` (kein App-Verhalten), sondern die Produktionsgrundlage
für diesen und den nächsten Beitrag; der Demo-Datensatz bedient zugleich RELEASE.md Phase 3.

---

## 1. Haltung: Wie Understatement hier aussieht

Die App spricht wie ein Werkzeug (CONCEPT.md, „Ton der Texte"). Der Beitrag muss dasselbe
tun, sonst widerspricht die Verpackung dem Inhalt:

1. **Zeigen statt behaupten.** Kein Text *auf* dem Board, kein Badge, kein „built with AI",
   keine Pfeile, keine Callouts. Glas ist Chrome, nie Inhalt — das gilt auch für das Video.
2. **Die echte App, echter Zeiger.** Keine Nachbau-Animation in After Effects oder HTML. Der
   Zeiger bleibt sichtbar: Eine Karte, die sich „von selbst" bewegt, sieht nach Mockup aus;
   eine Hand, die zieht, nach Werkzeug.
3. **Keine Musik.** LinkedIn spielt stumm an; wer Ton einschaltet, hört nur, was die App
   selbst macht: den Erledigt-Klang. Ein Detail für Aufmerksame — genau richtig.
4. **Die Meta-Ebene ist der einzige Witz:** Das Board zeigt den eigenen Release-Backlog der
   App. Die Karte, die auf „Erledigt" landet, heißt **„LinkedIn-Video aufnehmen"**. Wer's
   merkt, lächelt; wer nicht, sieht ein glaubwürdiges Projekt-Board. Kein Erklärtext dazu.
5. **Der Text trägt die Botschaft, das Video den Beweis.** Alles über KI, Kanban,
   Arbeitsweise steht im Beitragstext. Das Video wäre auch ohne Text verständlich.
6. **Klein bleiben.** Vier Sekunden, ein fester Bildausschnitt, keine Kamerafahrt, kein
   Intro, kein Outro, kein Logo. Das Video hat den Rhythmus der App: ein Zug, ein Atem, Ruhe.

---

## 2. Grundlage

### 2.1 Demo-Datensatz (zugleich RELEASE.md Phase 3, „Demo-Datensatz")

Angelegt per `seed-demo-reminders.swift` (Fassung v2 vom 05.09.2026; `--remove` räumt auf).
Dasselbe Skript schreibt die Spalten (`next`/`inProgress`) direkt in die `columns.json` der
App — deshalb muss die App dabei **geschlossen** sein; das Skript verweigert sonst. Alle
Daten sind relativ zu heute, der Seed ist vor jeder Aufnahme neu zu setzen (README.md,
Schritt 1).

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
Falz „1 noch nicht fällig" und der Chip „Heute" sind zwei stille Details, die Kenner der
App-Philosophie wiedererkennen — ohne dass etwas erklärt wird. Keine „47" bei der Flamme:
Das wäre Prahlerei; der Tick von 6 auf 7 reicht.

**Bewusst weggelassen:** eine überfällige Karte (rotes „Überfällig"-Badge). Realistisch wäre
sie, aber sie ist das einzige laute Element der Oberfläche und würde im Standbild dominieren.

### 2.2 Einstellungen der App für die Aufnahme

| Einstellung | Wert | Grund |
|---|---|---|
| Listen-Auswahl | nur „Glass Kanban" und „Privat" | private Daten bleiben draußen, ohne sie anzufassen |
| WIP-Limit „In Bearbeitung" | **2** | Kapsel „2 / 2": das Limit ist im Bild, ohne dass der Dialog erscheint |
| WIP-Limit „Als Nächstes" | 5 (Standard) | Kapsel „3 / 5" wirkt geplant, nicht knapp |
| Erledigt-Klang | an | der einzige Ton des Videos |
| Erscheinungsbild | **Hell** | der weiße Feed; die Referenz ist das helle Desk-Setup |
| Systemsprache | Deutsch | Beitrag ist deutsch; eine englische Variante braucht eine eigene Aufnahme |
| „Noch nicht Fälliges einklappen" | an (Standard) | erzeugt die Falz-Zeile |

### 2.3 Bild

- **Ganzes Fenster, 1:1, 1080 × 1080.** Davids Vorgabe: Die App steht im Vordergrund, nicht
  der Hintergrund. Das Fenster ist 1220 × 1000 pt — 1220 ist die Mindestbreite des Boards
  und damit die größte Schrift ohne abgeschnittene Titel; 1000 füllt das Quadrat mit
  20 pt Rand seitlich und 130 pt oben/unten (Desktop-Anteil 23 %). Der Rand ist **echt
  aufgenommen**, nie nachträglich gefüllt: ein unscharfes Wallpaper-Bett sah amateurhaft aus.
- **4:5 ist auf diesem Bildschirm unmöglich:** Das Board in voller Breite bräuchte 1575 pt
  Höhe, der Schirm hat 1440. 1:1 ist die sichere Universalwahl für Feed und Desktop.
- **2×-Pixel.** Der Mac mini hängt an 1×-Displays; für ein Video, das Qualität transportieren
  soll, ist 1× zu weich (Text 15 px). Deshalb wird das Display für die Aufnahme per
  `displayplacer` auf 2560 × 1440 HiDPI gestellt (README.md, Schritt 3).
- **Bühne:** Wallpaper Sonoma (Davids Wahl gegen iMac Silver), Dock ausgeblendet,
  Schreibtisch-Symbole aus, Menüleiste außerhalb des Bildes, andere Fenster ausgeblendet.
  Zeiger: macOS-Standard, normale Größe, als schlichter Pfeil — kein Kopier-Plus (das war
  App-Verhalten und ist seit 05.09.2026 behoben, SPEC.md „Interaktion").
- **Bewegung der App bleibt unangetastet:** Kartenzug, Settle-Pause, Durchstrich, Flamme,
  Klang — die Belohnungsmomente sind das Design. Geschnitten wird nur Leerlauf.

### 2.4 LinkedIn-Formatfakten (Stand 05.09.2026, vor dem Upload gegenprüfen)

| | Wert | Folge |
|---|---|---|
| GIF | LinkedIn zeigt hochgeladene GIFs als Standbild | Bewegung im Feed nur als **MP4-Loop**; die `.gif` ist für README und Messenger |
| Länge | 3 s bis 10 min; kurze Videos werden zu Ende gesehen und wiederholt; die ersten 2 s entscheiden | ≈ 4 s, Bewegung ab dem ersten Bild |
| Codec | MP4, H.264, 30 fps, AAC-Tonspur (auch wenn still), ≤ 10 Mbit/s | `cut.sh` |
| Ton | Autoplay stumm, ~80 % sehen ohne Ton | muss stumm funktionieren; der Klang ist Bonus |
| Loop | Feed-Videos wiederholen sich in der Regel, nicht garantiert | Ende und Anfang passen aneinander (harter Schnitt) |
| Thumbnail | eigenes Vorschaubild möglich | erstes Bild: Zeiger auf der Karte |

---

## 3. Der Clip: „Ein Zug" (≈ 4 s, Loop)

Ein fester Bildausschnitt, ein Zug: Der Zeiger liegt auf „LinkedIn-Video aufnehmen" in
„In Bearbeitung", zieht sie nach „Erledigt", die Karte legt sich ab, ein Atem, der
Durchstrich zieht über den Titel, die Flamme geht von 6 auf 7. Dann Ruhe, dann von vorn.

| Zeit | Bild | Ton |
|---|---|---|
| 0,0–0,5 s | Ruhe. Zeiger liegt auf der Karte — keine Anfahrt (Davids Vorgabe), Bewegung ab Bild 1 | — |
| 0,5–2,2 s | Zug: Karte hebt sich, gleitet nach Erledigt, Spring-Settle. Kapsel „2 / 2" → „1 / 2" | — |
| 2,2–2,5 s | **Atem** (Settle-Pause, unangetastet) | — |
| 2,5–3,0 s | Durchstrich zieht über den Titel; Erledigt „6" → „7", Flamme nickt, „6" → „7" | **Erledigt-Klang** |
| 3,0–4,0 s | Ruhe | — |

Warum das trägt: Der eine Zug enthält alle drei Belohnungsmomente der App (Settle,
Durchstrich, Flamme) — der Teil, den niemand aus einem Screenshot erraten kann. Vier
Sekunden werden zu Ende gesehen und wiederholt; beim zweiten Durchlauf entdeckt man die
Flamme, beim dritten den Atem vor dem Durchstrich. Ein Loop *ist* Understatement: Er drängt
nicht, er liegt da. Der WIP-Dialog fehlt bewusst — der Beitragstext liefert ihn in einem
Satz nach (4.2), Bild und Text ergänzen sich, statt sich zu wiederholen.

Der Loop ist ein **harter Schnitt**: Die 0,6-s-Überblendung zurück zum Anfang erzeugte
Geistertext in „Erledigt" (zwei Kartenlisten ineinander) und einen Farbsprung an der Naht;
ein harter Schnitt hat beides nicht, und die Karte springt sichtbar zurück, was ehrlicher ist
als ein Verwischen.

---

## 4. Beitragstexte — zwei Entwürfe

Beide unter 1.300 Zeichen (LinkedIn zeigt ~210 Zeichen vor „mehr anzeigen" — der erste Satz
ist der Hook), keine Emojis, drei Hashtags am Ende, Link zur App im ersten Kommentar, nicht
im Text. Ton: derselbe wie die App — benennen, nicht kommentieren. Die Texte sind nicht an
den Clip gebunden; beide passen zu ihm.

### 4.1 Thema: KI beim App-Bau

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

Prüfung gegen die sieben Fragen: Hook benennt einen Zustand (Meta-Ebene), ohne ihn zu
erklären. Die Zahlen stehen in einem Satz beisammen. Der letzte Absatz ist der einzige Witz,
mit einem Wort aufgelöst. Kein „stolz", kein „endlich", kein „Reise".

### 4.2 Thema: Personal Kanban

> Weniger gleichzeitig, mehr fertig.
>
> Diesen Satz zeigt mein Kanban-Board, wenn ich eine dritte Sache anfange, bevor eine fertig
> ist. Es verbietet nichts. Es fragt — und die bequemste Antwort ist Return: erst abschließen.
>
> Personal Kanban (Jim Benson, Tonianne DeMaria Barry) hat zwei Regeln: Arbeit sichtbar
> machen, begonnene Arbeit begrenzen. Alles andere ist Ausgestaltung. Die vier Sekunden
> zeigen, was nach der Frage kommt: eine Karte, ein Durchstrich, ein Ton. Keine Punkte, keine
> Fanfare, kein Onboarding. Mehr nicht.
>
> Die App heißt Glass Kanban und liegt über Apple Erinnerungen. Sie ist noch nicht im Store.
> Was sie kann und warum, steht im ersten Kommentar.
>
> #PersonalKanban #WIPLimit #macOS

### 4.3 Erster Kommentar (beide)

> Repository mit Konzept, Spezifikation und Backlog: <GitHub-URL>. Die drei Dokumente sind
> die eigentliche Arbeit — die App ist das, was übrig blieb.

(URL per `gh repo view --json url` bestimmen, nicht raten.)

---

## 5. Upload-Checkliste LinkedIn (Stand 05.09.2026)

Was die Datei mitbringt (von `cut.sh` sichergestellt, an Take 14 gemessen):

| Eigenschaft | Wert | Warum |
|---|---|---|
| Format | MP4, H.264 High, Level 4.0, `yuv420p` | LinkedIns sicherste Kombination |
| Auflösung | 1080 × 1080 | siehe 2.3 |
| Bildrate | konstant 30 fps | die Aufnahme läuft fest mit 30, LinkedIn kommt mit variabler Bildrate schlecht klar |
| Farbe | BT.709 in allen drei Tags, TV-Range | LinkedIn kodiert neu; ohne saubere Tags rät der Encoder die Matrix und die Karten werden gelblich. Die Tags müssen im Filtergraph gesetzt werden (`setparams`), Encoder-Optionen allein reichen nicht (gemessen) |
| Keyframes | jede Sekunde | sauberes erstes Bild als Vorschaubild, sauberer Loop-Anfang |
| Ton | AAC 48 kHz stereo, Stille außer dem Erledigt-Klang | Autoplay ist stumm; wer einschaltet, hört nur den Klang |
| Größe | ≈ 0,5 MB | Upload sofort |
| `faststart` | gesetzt | Wiedergabe beginnt vor dem vollständigen Laden |

Sicherheitszonen: LinkedIn legt Stumm-Schalter und Restlaufzeit unten über das Video —
beides liegt im Wallpaper-Rand unter dem Fenster, nicht auf den Karten.

Beim Posten (David):

1. **Nativ hochladen**, vom Desktop, als Video-Beitrag — kein YouTube-Link, kein „Dokument".
   Datei: `glass-kanban-one-move-1x1.mp4`.
2. **Vorschaubild** setzen: `glass-kanban-thumbnail-1x1.png` (erstes Bild, Zeiger auf der
   Karte). Ohne eigenes Vorschaubild nimmt LinkedIn ein beliebiges Bild.
3. Kein Videotitel, keine Untertitel-Datei. LinkedIns automatische Untertitel bleiben leer.
4. Text aus Abschnitt 4 einsetzen; der erste Satz muss vor „… mehr anzeigen" stehen. Kein
   Link im Text, Link als **erster Kommentar** direkt nach dem Posten. Drei Hashtags am
   Ende, keine Erwähnungen.
5. Nach dem Posten **auf dem Telefon prüfen**: Loop, Farben (Karten weiß, nicht gelblich),
   Lesbarkeit. Weicht die Farbe ab, ist es LinkedIns Neukodierung — nicht die Tags im
   Schnitt ändern.
6. Beitrag in der ersten Stunde nicht bearbeiten (Bearbeitungen setzen die Verteilung
   zurück). Auf Kommentare in den ersten Stunden antworten.
7. Zeitpunkt: Dienstag bis Donnerstag, morgens zwischen 7 und 9 Uhr — Plattformdurchschnitt,
   kein Naturgesetz.

Zweitverwertung: `glass-kanban-one-move-1x1.gif` für README und Messenger; auf LinkedIn
**nicht** hochladen (bleibt dort ein Standbild).

---

## 6. Verworfen, damit es nicht wiederkommt

| Idee | Warum nicht |
|---|---|
| **Idee A „Drei Züge"** (12 s: anfangen, WIP-Dialog, fertig werden) | Erzählung statt Rhythmus; braucht „Als Nächstes" im Bild und passt so nicht in ein lesbares Quadrat. Der Dialog kommt als Satz im Text |
| Rechte Boardhälfte als Ausschnitt, 4:5 als Hauptformat | Davids Vorgabe: die App steht im Vordergrund; 4:5 ist mit dem ganzen Board auf diesem Schirm unmöglich (2.3) |
| Überblendung als Loop-Naht | Geistertext und Farbsprung (3); harter Schnitt |
| Zug von Hand, Aufnahme mit `screencapture` | `screencapture -v` lieferte ein eingefrorenes Standbild; der Zug läuft synthetisch auf HID-Ebene und ist damit wiederholbar (README.md) |
| Board in HTML/After Effects nachbauen | Zeigt nicht den aktuellen Stand, sondern eine Behauptung. Widerspricht Regel 2 |
| Text-Overlays auf dem Board („Pull", „WIP 2", Pfeile) | Glas ist Chrome, nie Inhalt. Wer Pfeile braucht, hat das falsche Bild gewählt |
| Musikbett | Jede Musik ist eine Stimme. Die App hat keine |
| Dunkelmodus als Hauptvariante | Lauter Kontrast im weißen Feed; die Referenz ist das helle Desk-Setup. Als Zweitvariante offen |
| 16:9-Video | Auf dem Telefon ein Briefmarken-Board |
| Kamerafahrt, die der Karte folgt (Erstentwurf, 26 s, sechs Züge) | Bewegung, die nicht aus der App kommt, und zu lang |
| Zoom-out auf das ganze Board als Schlussbild | Ein Schlussbild ist ein Outro. Das letzte Bild ist der Zustand nach dem Zug |
| Karte, die sich ohne Zeiger bewegt | Sieht nach Mockup aus. Der Zeiger ist die Hand |
| Streak „47" oder Meilenstein-Hinweis im Bild | Prahlerei; die Zahl im Video ist ein Tick von 6 auf 7 |
| Statistik-Popover im Video | Eigener Beitrag. Ein Video, eine Sache |
| Sprecher, Untertitel | Keine Sprache nötig; ein Sprecher wäre Coaching |
| Überfällige Karte im Video | Das einzige rote Element der App dominiert jedes Bild |
| Dokument-Karussell (PDF) statt Video | Standbilder zeigen weder Settle noch Durchstrich noch Klang |
| Echte `.gif` auf LinkedIn hochladen | Wird dort als Standbild angezeigt; der Loop kommt als MP4 |
