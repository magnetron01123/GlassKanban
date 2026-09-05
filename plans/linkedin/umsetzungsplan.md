# LinkedIn-Video — Umsetzungsplan (05.09.2026)

Für eine eigene Session mit Opus. Wer dies liest, setzt um, ohne die Entscheidung neu zu
führen: **Idee B „Ein Zug" (7 s, Loop) ist der Beitrag, Idee A „Drei Züge" (12 s) wird aus
demselben Take-Tag mitgeschnitten und bleibt Reserve.** Alles Warum steht in `konzept.md`.

## Zuerst lesen — in dieser Reihenfolge, nichts anderes

1. `plans/linkedin/konzept.md`, Abschnitt 1 (Haltung) und Abschnitt 5 (Empfehlung) — 3 Minuten
2. `plans/linkedin/konzept.md`, Anhang A vollständig — das ist die Befehlsebene dieses Plans
3. `CLAUDE.md`, Abschnitt „Arbeitsweise", Punkte zu Screenshots, Drag & Drop, `os.Logger`
   und `-derivedDataPath` — Regeln, die hier greifen
4. `plans/linkedin/konzept.md`, Abschnitte 3.2/3.5 und 4.2/4.4 nur **unmittelbar vor der
   Aufnahme** (Phase 4)

Nicht lesen: SPEC.md, CONCEPT.md, BACKLOG.md, RELEASE.md. Alles, was daraus gebraucht wird,
steht schon im Konzept.

## Ziel / Nicht-Ziel

**Ziel (Stand 05.09.2026, erreicht):** Ein Clip als MP4 in **1:1 (1080 × 1080)**, H.264/AAC, BT.709,
30 fps, ≈ 4 s, harter Loop — das ganze App-Fenster (1220 × 1000 pt) mit echtem Desktop-Rand
oben und unten, aus einer echten Aufnahme mit dem Demo-Datensatz v2; dazu GIF, Thumbnail-PNG
und Kontrollframes auf Telefonbreite. Abgelegt in `~/Movies/GlassKanban-LinkedIn/final/`.
Der ursprüngliche Plan (4:5 + 1:1, rechte Boardhälfte, 7 s) ist in konzept.md unter
„Ergebnis" als überholt markiert.

**Nicht-Ziel:** Keine Änderung an der App, an `project.yml` oder an den Swift-Quellen unter
`GlassKanban/`. Kein Beitragstext (steht fertig in konzept.md Abschnitt 7). Kein Upload. Keine
Nachbau-Animation außerhalb der App. Keine Abweichung vom Storyboard ohne Rückfrage.

## Rollen und Haltepunkte

Die Session arbeitet allein, bis sie einen **Haltepunkt** erreicht. An einem Haltepunkt sendet
sie das Ergebnis (Datei oder Bild per SendUserFile), sagt in einem Satz, was David tun soll,
und wartet. Es gibt genau vier Haltepunkte:

| Haltepunkt | Session liefert | David tut |
|---|---|---|
| H1 nach Phase 1 | Testframe 1:1 + Telefon-Verkleinerung | bestätigt Look oder nennt, was stört |
| H2 nach Phase 2 | Messwert „UI Looks like" | richtet 2×-Display ein (Systemeinstellungen/BetterDisplay), meldet sich |
| H3 in Phase 4 | Aufnahme läuft | zieht die Karten nach Drehbuch, sagt „fertig" |
| H4 nach Phase 5 | vier Kontrollframes + Loop-Hinweis | nimmt ab oder fordert einen anderen Take |

Zwischen Haltepunkten keine Rückfragen. Ist etwas unklar, gilt die Annahme aus dem Konzept,
und sie wird im Messprotokoll (unten) notiert.

**Regeln, die immer gelten:**
- Nie in Reminders-Listen schreiben, die nicht „Glass Kanban" oder „Privat" heißen.
- `columns.json` und die App-Defaults nur bei **geschlossener** App anfassen; vorher sichern.
- Screenshots der App per computer-use (`app_screenshot`, Bundle-ID
  `com.davidtrogemann.GlassKanban`). Vor jedem Screenshot: `pgrep -fl "Glass Kanban"` — es darf
  nur die Instanz aus dem Projektordner laufen.
- Kein Zug wird synthetisch ausgelöst (Drag funktioniert nicht, CLAUDE.md). Karten bewegt
  David; die Session bewegt nichts außer dem Fenster.
- Jede Messung ins Messprotokoll, mit Wert, nicht mit „ok".

---

## Phase 0 — Messen (10 min, kein Haltepunkt)

Weiche: Alles, was hier abweicht, ändert die Reihenfolge der Phasen.

- [x] `pgrep -fl "Glass Kanban"` → keine Instanz; sonst beenden (`osascript -e 'tell application "Glass Kanban" to quit'`)
- [x] `ls -la "Glass Kanban.app/Contents/MacOS/"` → Bundle vorhanden, Datum jünger als der letzte Commit
      (`git log -1 --format=%cd`). Älter → `scripts/build-app.sh --manual` und warten
- [x] `system_profiler SPDisplaysDataType | grep "UI Looks like"` → notieren. Steht dort
      `2560 x 1440`: Display ist 1×, **Phase 2 ist Pflicht** vor Phase 4
- [x] `which ffmpeg` → fehlt: David bei H1 um `brew install ffmpeg` bitten (dauert, läuft parallel)
- [x] `swift --version` → Toolchain vorhanden (Xcode 26)
- [x] Defaults sichern: `D=com.davidtrogemann.GlassKanban; cp ~/Library/Containers/$D/Data/Library/Preferences/$D.plist /tmp/prefs-backup.plist`
      → Datei da. `plutil -p /tmp/prefs-backup.plist | grep -A3 "wipLimits\|excludedCalendarIDs\|appAppearance"` → Werte ins Messprotokoll (das sind die Rückstellwerte)
- [x] `cp ~/Library/Containers/$D/Data/Library/Application\ Support/GlassKanban/columns.json /tmp/columns-backup.json` → Datei da
- [x] Prüfen, ob eine lokale Reminders-Quelle existiert („Auf meinem Mac"): das ID-Skript aus
      konzept.md A.3 laufen lassen; erscheint keine Liste mit lokaler Quelle, legt das
      Seeding-Skript die Listen in iCloud an (fällt auf CalDAV zurück) — dann **synchronisieren
      sie aufs iPhone**. Das ist akzeptabel, aber ins Messprotokoll und David bei H1 sagen

## Phase 1 — Datensatz, Einstellungen, Testframe (30 min, endet mit H1)

Befehle und Erwartungen: konzept.md **A.2 bis A.6**, in dieser Reihenfolge.

- [x] A.2 Seeding → Ausgabe „created 22 reminders" und „4 pulls written"; JSON-Prüfung zeigt
      `['inProgress', 'next', 'next', 'next']` (plus vorhandene echte Einträge)
- [x] A.3 Einstellungen per `defaults write` (verifiziert 05.09.); `plutil -p` zeigt
      `wipLimits {inProgress 2, next 5}`, `appAppearance light`, `excludedCalendarIDs` = alle
      Nicht-Demo-Listen
- [x] A.4 App starten, Screenshot, Sechs-Punkte-Liste abhaken — **jeder Punkt einzeln im
      Messprotokoll**. Flamme ≠ „6": Erledigt-Daten im Skript um −1 Tag, `--remove`, neu
- [x] A.5 Fenster 1300 × 612 → `/tmp/window-id` zeigt `w=1300 h=612`
- [x] A.6 Testframe, 1:1-Ausschnitt, Telefon-Verkleinerung → beide PNG
- [ ] **H1:** `/tmp/frame_1to1.png` und `/tmp/frame_phone.png` senden. Ein Satz: „Lesbarkeit,
      Rand und Hintergrund so freigeben? Parallel bitte `brew install ffmpeg`." Warten.

Kommt Kritik am Hintergrund: Wallpaper-Kandidaten aus A.7 nennen, David wählt; Testframe
wiederholen, erneut senden. Kommt Kritik an der Lesbarkeit: Fenster auf 1240 × 612 (weniger
Rand, Karten größer im Ausschnitt), A.6 wiederholen.

## Phase 2 — Display auf 2× (David, endet mit H2)

Die Session kann hier nichts ausführen. Sie liefert David die Anleitung aus konzept.md
**A.7** (drei Wege in Reihenfolge) und wartet. Nach Rückmeldung:

- [ ] `system_profiler SPDisplaysDataType | grep "UI Looks like"` → `1280 x 720` oder `1440 x 900`
- [ ] Fenster liegt auf dem 2×-Display: `/tmp/window-id` → Koordinaten innerhalb dessen Bereichs
- [ ] A.5 und A.6 wiederholen (das Fenster hat sich beim Displaywechsel bewegt)
      → Testframe jetzt ~2600 px breit. Ist er ~1300: Display ist immer noch 1×, zurück zu A.7
- [ ] Dock/Schreibtisch/Wallpaper: David hat es gesetzt; im Testframe prüfen, dass kein
      Dock-Rand und keine Symbole im Bereich Fenster + 40 pt liegen

Phase 2 entfällt, wenn Phase 0 schon ein 2×-Display gemessen hat.

## Phase 3 — Aufnahme vorbereiten (10 min, kein Haltepunkt)

- [ ] `cat plans/linkedin/konzept.md | sed -n '/### 4.4/,/### 4.5/p'` und `/### 3.5/,/### 3.6/p`
      lesen — die Drehbücher
- [ ] `plans/linkedin/record.sh 0 3` — **3-s-Probelauf**: Datei `/tmp/take0.mov` entsteht,
      `ffprobe` zeigt Breite ≈ 2 × (w+80). Nicht ≈ 2×: zurück zu Phase 2
- [ ] Cursor-Test: In diesem 3-s-Probelauf soll der Cursor im Bereich liegen (David bitten,
      ihn kurz aufs Fenster zu legen — kein Haltepunkt, eine Zeile reicht). Einen Frame ziehen
      (`ffmpeg -ss 1 -frames:v 1`), ansehen: Cursor sichtbar? Nein → QuickTime-Weg aus A.8,
      David übernimmt Start/Stopp der Aufnahme
- [ ] Board-Zustand wie A.4 (falls seit H1 etwas gezogen wurde: ⌘Z bis Sollzustand)

## Phase 4 — Aufnahme (David 15 min, endet mit H3 je Take)

Sechs Takes, jeder mit derselben Schleife:

1. Session: `plans/linkedin/record.sh N` starten (40 s), Ausgabe „Aufnahme läuft, Take N,
   Drehbuch B/A" senden; `plans/linkedin/drehbuch.md` liegt David vor
2. David zieht nach Drehbuch (B: ein Zug; A: drei Züge), sagt „fertig"
3. Session: Aufnahme läuft ohnehin nach 40 s aus; `ffprobe` auf die Datei; Ergebnis notieren
4. Session: „⌘Z je Zug, dann Take N+1?" — David stellt zurück, die Session prüft per
   Screenshot, dass der Sollzustand wieder steht (Flamme „6", In Bearbeitung „1 / 2")

- [ ] Take 1–3: Idee B (`/tmp/take1.mov` … `take3.mov`)
- [ ] Take 4–6: Idee A (`/tmp/take4.mov` … `take6.mov`)
- [ ] Je Take: Dauer, Breite, Höhe, fps ins Messprotokoll

Weniger Takes sind erlaubt, wenn David nach dem zweiten sagt „der war gut".

## Phase 5 — Schnitt und Abnahme (Session 1–2 h, endet mit H4)

- [ ] Take-Auswahl: alle Takes einer Idee als Kontaktbogen — je Take drei Frames (Hover,
      Loslassen, Ende) mit `ffmpeg -ss T -frames:v 1`; den ruhigsten wählen (Cursor liegt still,
      kein Hover über fremden Karten, Loslassen mittig). Wahl begründen im Messprotokoll
- [ ] Zeitmarken ablesen: `plans/linkedin/frames.sh /tmp/takeN.mov` für jeden Take, Frames
      ansehen, Marken bestimmen (Bildnummer ÷ 4 = Sekunde). Kein QuickTime nötig
- [ ] `CROP_*` nach A.8 berechnen, Probeframe schneiden, wie A.6 abnehmen
- [ ] Block „MARKS" in `plans/linkedin/cut.sh` füllen, Skript laufen lassen (A.9)
- [ ] `ffprobe`-Prüfung aller vier MP4: h264, 1080 × 1350 bzw. 1080 × 1080, aac, 30/1, Farbtags `bt709,bt709,bt709,tv`, Dauer B 6,5–8 s, A 11–13 s
- [ ] Loop-Prüfung B: letzten und ersten Frame nebeneinander ansehen — Karte an derselben
      Stelle, Flamme „6" in beiden, Cursor an derselben Stelle. Weicht der Cursor ab: 
      Überblendung auf 0,8 s verlängern (`xfade … duration=0.8`), neu schneiden
- [ ] Kontrollframes beider Videos bei 0 s, Loslassen, Durchstrich, Ende; bei 390 px Breite
      ansehen: Titel lesbar, Durchstrich sichtbar, Flamme „7" im Endframe
- [ ] Thumbnail: `glass-kanban-thumbnail-4x5.png` (erstes Bild, schreibt `cut.sh`)
- [ ] **H4:** MP4 B, MP4 A, GIF, Thumbnail und die Kontrollframes senden. Ein Satz: „Loop in
      QuickTime mit ⌥⌘L prüfen; anderen Take oder Freigabe?" Warten.

## Phase 6 — Aufräumen (10 min, nach Freigabe)

- [ ] Defaults zurück: Werte aus dem Messprotokoll (Phase 0) per `defaults write` setzen,
      `plutil -p` prüft. **Nicht** die ganze Backup-plist zurückkopieren (Fensterposition
      und Fremdschlüssel würden mit überschrieben)
- [ ] Demo-Listen: stehen lassen. In RELEASE.md Phase 3 den Punkt „Demo-Datensatz" abhaken
      mit Verweis „siehe plans/linkedin/konzept.md 2.1" — das ist die einzige Doku-Änderung
      dieses Vorhabens
- [ ] Dock, Schreibtisch, Wallpaper: David (A.7, letzter Absatz)
- [ ] Take-Dateien und `/tmp/cut` an einen Ort außerhalb von `/tmp` kopieren, den David nennt
      (Vorschlag: `~/Movies/GlassKanban-LinkedIn/`); Pfade ins Messprotokoll
- [ ] Dieses Dokument und konzept.md bleiben, bis der Beitrag online ist; danach löschen
      oder als Verweis in RELEASE.md Phase 3 belassen (David entscheidet)

## Doku-Pflichten

Eine einzige: RELEASE.md Phase 3, Kästchen „Demo-Datensatz" (Phase 6). Der Doku-Wächter
(`scripts/doc-guard.sh`) meldet sich nicht, weil keine Swift-Datei angefasst wird. Kein
Commit ohne Davids Wort; Branch bleibt `docs/consistency-pass` oder ein neuer
`chore/linkedin-video`, wenn David das will.

## Abnahme

Erfüllt am 05.09.2026 (Take 12, Datensatz v2):

1. `final/glass-kanban-one-move-1x1.mp4` — 1080 × 1080, 3,97 s, h264/aac, bt709, harter Loop (Naht-Farbdelta 0,03)
2. `final/glass-kanban-one-move-1x1.gif` (0,7 MB) und `final/glass-kanban-thumbnail-1x1.png`
3. `final/kontrollframes-telefonbreite.png`, `final/take12.mov` (Rohaufnahme 2520 × 2520)
4. Messprotokoll unten, Rückstellung in Phase 6 protokolliert
5. Idee A entfällt (passt nicht in den Ausschnitt); frühere Fassungen liegen in `final/alt-*/`
6. Davids Freigabe: Bildaufteilung und Datensatz v2 wurden in dieser Session abgenommen

## Was schiefgehen kann, und was dann

| Symptom | Ursache | Weg |
|---|---|---|
| Seeding: „No Reminders access" | TCC-Dialog nicht bestätigt oder für falsche App | Dialog erscheint bei der Host-App des Terminals; sonst Systemeinstellungen → Datenschutz → Erinnerungen |
| Seeding: „Demo lists already exist" | früherer Lauf | `--remove`, erneut |
| Board zeigt fremde Karten | `excludedCalendarIDs` unvollständig | ID-Skript erneut, alle Nicht-Demo-IDs eintragen, App neu starten |
| Flamme grau ohne Zahl | Erledigungen nicht an aufeinanderfolgenden Tagen erkannt | Statistik öffnen, „Letzte 7 Tage"-Zeile lesen, `completedDaysAgo` anpassen |
| „In Bearbeitung" zeigt Platzhalter | Pull nicht angekommen | `columns.json` prüfen, ID der Karte vergleichen (Erinnerungen-App zeigt keine IDs; ID-Skript um Titel-Ausgabe erweitern) |
| Dialog kommt nicht beim dritten Zug | WIP nicht 2 | `plutil -p` prüfen; App war beim `defaults write` offen → schließen, erneut |
| Testframe 1300 px statt 2600 | Display 1× | Phase 2 |
| Aufnahme ohne Cursor | `-C` wirkt nicht im Videomodus | QuickTime-Weg (A.8) |
| `cut.sh` bricht bei `xfade` | Segmentlängen < Überblendung oder ungleiche fps | Marken prüfen; `ffprobe` beider Segmente vergleichen |
| GIF > 8 MB | zu viele Farben/Frames | `fps=15`, `scale=640`, `bayer_scale=3` |

## Messprotokoll (während des Bauens füllen)

| Datum | Phase | Messung | Wert |
|---|---|---|---|
| 05.09.2026 | 0 | Display | 2 × Dell U2722DE, „UI Looks like 2560 x 1440" (1×) |
| 05.09.2026 | 0 | ffmpeg | nicht installiert → 05.09. 13:10 per `brew install ffmpeg` installiert (9.0.1), auf Davids Wort „Alles weitere vorbereiten" |
| 05.09.2026 | 5 (vorab) | `cut.sh` Trockenlauf | synthetischer 40-s-Take aus dem Testframe, CROP 692/692/688/0: beide MP4 h264/aac 1080×1080, Klang bei der Marke (−13,5 dB max), sonst Stille (−91 dB), GIF 720 px 118 Frames 0,47 MB |
| 05.09.2026 | — | Formatrecherche | 4:5 gilt 2026 als Optimum für den mobilen Feed, 1:1 als sichere Universalwahl, 9:16 wird im Video-Tab gepusht, passt aber nicht zum Querformat und zur Desktop-Zielgruppe. Entscheidung: 4:5 Hauptdatei, 1:1 dazu. Quellen: yansmedia.com/blog/linkedin-video-specs, contentin.io/blog/linkedin-post-specs, quso.ai/blog/linkedin-video-size, blog.sendspark.com/linkedin-video-specs |
| 05.09.2026 | 5 (vorab) | `cut.sh` Trockenlauf 4:5 + 1:1 | Rand 40/130, S=1: Crops `692x692+688+90` und `692x865+688+4`; vier MP4 (1080×1350 / 1080×1080), Fenster mittig im 4:5, Telefon-Verkleinerung lesbar |
| 05.09.2026 | 5 (vorab) | Encoding-Härtung | `screencapture` liefert VFR (`30/19`) → fest 30 fps; Farbtags nur per `setparams` im Filtergraph sauber (Encoder-Optionen allein: transfer `bt470m`); jetzt alle vier MP4 `bt709,bt709,bt709,tv,30/1`, Keyframe jede Sekunde, Level 4.0, CRF 17 preset slow; Thumbnail-PNG wird mitgeschrieben |
| 05.09.2026 | 3 (vorab) | `record.sh`, `frames.sh`, `drehbuch.md` | angelegt, Syntax geprüft; `record.sh` noch nicht mit echter Aufnahme gelaufen (braucht Board im Vordergrund + Bildschirmaufnahme-Freigabe) |
| 05.09.2026 | 0 | `defaults write` in Container-Domain | wirkt, inkl. `-dict`/`-array` (Probeschlüssel, wieder gelöscht) |
| 05.09.2026 | 0 | Seeding-Skript, window-id | kompilieren; window-id gegen laufende App geprüft (`id=1496 w=1500 h=950`) |
| 05.09.2026 | 0 | `screencapture -v -C -R` | erzeugt Datei (2-s-Test); Cursor im Bild ungeprüft |
| 05.09.2026 | 0 | Rückstellwerte | wipLimits {inProgress 3, next 5}; appAppearance "system"; excludedCalendarIDs [5AF20BC1-D927-4FC3-8E6C-096D52FDBCA3]; completionSoundEnabled nicht gesetzt; Sicherung /tmp/prefs-backup.plist, /tmp/columns-backup.json |
| 05.09.2026 | 0 | Reminders-Quellen | nur iCloud, keine lokale → Demo-Listen liegen in iCloud (IDs Privat 5E1687FA-…, Glass Kanban 88170E04-…) |
| 05.09.2026 | 1 | Seeding-Ausgabe | created 22 reminders; 4 pulls written |
| 05.09.2026 | 1 | JSON-Lanes | 1× inProgress + 3× next (Demo) + 2× next (echt, unangetastet); danach LinkedIn-Karte per columns.json auf inProgress (Startzustand Idee B) |
| 05.09.2026 | 1 | Nachbesserung Datensatz | Notizen auf 3 Karten gesetzt; 6 Titel gekürzt, weil sie bei 300 pt Spaltenbreite abgeschnitten wurden |
| 05.09.2026 | 1 | A.4 Sechs-Punkte-Liste | alle sechs erfüllt (Flamme 6, 10 / 2 / 5 + 2 / 2, 8, Falz „1 noch nicht fällig", Chip „Heute") |
| 05.09.2026 | 1 | Fenster (window-id) | id=1524 x=200 y=120 w=1300 h=612 — 612 ist die Mindesthöhe, 560 wurde verweigert |
| 05.09.2026 | 1 | Testframe | 1300 × 612 (1×); 1:1-Ausschnitt 692 rechtsbündig, Telefon-Verkleinerung lesbar; Flamme außerhalb des Ausschnitts |
| 05.09.2026 | 1 | Bereichsaufnahme (`-R`) | nicht möglich, solange das Claude-Fenster vor dem Board liegt; macOS-Dialog „Bildschirmaufnahme" für Claude offen — von David zu beantworten |
| 05.09.2026 | 2 (vor Umstellung) | Ausgangsmessung | beide Dell: `UI Looks like 2560 x 1440` (1×); App nicht gestartet; ffmpeg 9.0.1 vorhanden; BetterDisplay nicht installiert; Dock autohide=0, Schreibtischsymbole an |
| 05.09.2026 | 2 | Werkzeug | macOS hat kein CLI für Auflösungen → `brew install displayplacer` (1.4.0); Rückstellbefehl gesichert in `/tmp/display-restore.sh` |
| 05.09.2026 | 2 | HiDPI-Modi des Dell | `mode 15: 1280x720 scaling:on` vorhanden, aber **unbrauchbar**: der Aufnahmebereich braucht 1380 × 872 pt, der Bildschirm hätte nur 1280 × 720 pt. Gewählt: `mode 40: 1920x1080 scaling:on` (Framebuffer 3840 × 2160, Panel 2560 × 1440) |
| 05.09.2026 | 2 | UI Looks like | `1920 x 1080` (Hauptdisplay); zweites Display unverändert 2560 × 1440 bei Origin (0,−1440) |
| 05.09.2026 | 2 | Abweichung Fensterposition | y = 200 statt 120: bei y = 120 läge die Oberkante des Aufnahmebereichs (y − 130) über der Menüleiste. `/tmp/window-id` → `id=1611 x=200 y=200 w=1300 h=612` |
| 05.09.2026 | 2 | Bildschirmaufnahme-Freigabe | **steht bereits** — `screencapture -l` und `-R` liefern echten Inhalt; der offene Punkt aus Phase 1 hat sich erledigt |
| 05.09.2026 | 2 | Testframe Fenster | 2600 × 1224 px = exakt 2× von 1300 × 612 ✓ (bei 1× wären es 1300 × 612) |
| 05.09.2026 | 2 | Testframe Bereich (`-R 160,70,1380,872`) | 2760 × 1744 px = exakt 2× ✓ |
| 05.09.2026 | 2 | Bühne | Dock autohide=1, Schreibtischsymbole aus, Wallpaper gesetzt. Erster Bereichs-Testframe zeigte **fremde Fenster** (Claude, Mail) im oberen 130-pt-Rand → `plans/linkedin/stage.sh` angelegt (blendet alle Apps außer Glass Kanban aus) und fest in `record.sh` verdrahtet (`trap … show` beim Beenden). Zweiter Testframe: nur Board auf Wallpaper ✓ |
| 05.09.2026 | 2 | Wallpaper | Sonoma.heic gegen iMac Silver.heic verglichen (je 1:1 und 4:5 gerendert); Session empfahl Silber, **David wählte Sonoma** — gesetzt und im Referenzframe bestätigt |
| 05.09.2026 | 2 | Crops aus `cut.sh` bei S=2 | 1:1 `1384x1384+1376+180`, 4:5 `1384x1730+1376+7` — beide innerhalb 2760 × 1744 ✓; Telefon-Verkleinerung auf 390 px: Titel und Durchstrich lesbar ✓ |
| 05.09.2026 | 3 | Cursor-Auflage (David) | Im ersten Take prüfen, dass der Mauszeiger als **normaler Pfeil** erscheint — kein Greifhand-Symbol, kein grünes Kopier-Plus am Zeiger. Erscheint ein Badge: Take verwerfen |
| 05.09.2026 | 3 | **Synthetischer Zug funktioniert doch** | Die CLAUDE.md-Notiz vom 14.08. gilt nur für den *Hintergrund*-Drag: `app_drag` hebt die Karte an, das Loslassen kommt nie an, die Karte bleibt im Schwebezustand hängen (nur ein App-Neustart löst ihn). Auf **HID-Ebene** dagegen (`computer_batch` mit `left_mouse_down`, sieben `mouse_move`, `left_mouse_up`) läuft der Zug vollständig durch: Karte landet in Erledigt, Durchstrich, Kapseln 1 / 2 und 9, Flamme 6 → 7. Zweimal reproduziert, jedes Mal per „Bearbeiten › Widerrufen" sauber zurückgestellt |
| 05.09.2026 | 3 | `screencapture -v` unbrauchbar | Liefert ein **eingefrorenes Standbild**: 495 aus `take1.mov` extrahierte Frames byteidentisch, obwohl der Zug nachweislich auf dem Schirm stattfand. Ignoriert außerdem `-V` (lief Minuten über die angeforderten 30 s), und SIGINT beendet ohne Datei. `record.sh` deshalb auf ffmpeg/AVFoundation umgebaut; die alte Fassung liegt als `record.sh.screencapture-bak` daneben |
| 05.09.2026 | 3 | ffmpeg/AVFoundation | `-f avfoundation -i "1"` greift das volle HiDPI-Backing **3840 × 2160** ab = exakt 2× des 1920 × 1080-Schreibtischs, also derselbe Crop wie geplant (2760 × 1744 + 320 + 140). 600 Frames / 30 fps / 19,97 s, echte Bewegung |
| 05.09.2026 | 3 | Cursor | `-capture_cursor 1` zeichnet ihn auf, als **normaler Pfeil**, kein Greifsymbol und kein Kopier-Badge (Frame geprüft, Zeiger auf der LinkedIn-Karte) |
| 05.09.2026 | 3 | Bühne | `stage.sh hide` braucht 0,9 s, `show` 0,6 s — der Vorlauf in `record.sh` (0,9 + 1 + 3 s) ist also kurz und nicht die Ursache der leeren Takes |
| 05.09.2026 | 3 | **Blocker: keine Gleichzeitigkeit** | Aufnahme (Bash) und Zug (computer-use) laufen **nacheinander**, auch wenn sie in einem Zug abgeschickt werden — gemessen: 8-s-Aufnahme 16:55:48,87–16:55:57,40, währenddessen fünf Mauswege kommandiert; im Video keine einzige Cursorbewegung, Frames konstant. Zweimal so beobachtet (Takes zeigen den Startzustand, der Zug passierte danach). Der Recorder müsste abgekoppelt laufen — `run_in_background` wurde vom Sandbox-Wächter blockiert und **nicht** umgangen. Ohne diese Freigabe kann die Session die Aufnahme nicht selbst fahren |
| 05.09.2026 | 2 | **Befund für Idee A** | Beide Ausschnitte zeigen nur „In Bearbeitung" und „Erledigt". Für Idee B (der Beitrag) genau richtig. Für Idee A liegen Zug 1 und Zug 2 sowie der mittig über dem Fenster stehende WIP-Dialog **außerhalb** des Bildes — A.5/A.6 nehmen das anders an. Breiteres 4:5 ginge nur auf Kosten der Lesbarkeit (801 statt 692 pt Bildbreite ≈ 14 % kleinere Schrift auf Telefonbreite). Entscheidung liegt bei David (H2) |
| 05.09.2026 | 3 | Freigabe | Blocker gelöst: David ließ eine Bash-Regel für `record.sh`/`stage.sh` in `.claude/settings.local.json` eintragen (gitignored, nicht in der eingecheckten Projektdatei). Hintergrundaufnahme läuft seitdem, Zug per computer-use parallel dazu |
| 05.09.2026 | 4 | Take 1 | 2760 × 1744, 30 fps, 750 Frames, 24,97 s. Zug vollständig im Bild: Frames 39–47 Cursor ruht, 48 (12,00 s) Abheben, 54 (13,50 s) gelandet, 58 (14,50 s) Durchstrich und Settle fertig. Nur ein Take nötig |
| 05.09.2026 | 4 | **Grünes Kopier-Plus am Zeiger** | Während des Ziehens hängt ein grünes „+" am Mauszeiger (Frame bei 12,5 s, in voller Auflösung geprüft). Das ist **App-Verhalten, nicht Artefakt des synthetischen Zugs**: `ColumnView.swift:183` nutzt `.draggable(card.id)` mit `.dropDestination(for: String.self)` (Zeile 304); SwiftUI zeigt dafür standardmäßig das Kopier-Badge. Ein Zug von Hand sähe genauso aus. Semantisch falsch für einen Kanban-Zug (Ziehen ist Verschieben, nicht Kopieren) — Entscheidung offen, Änderung wäre ein Eingriff in die Swift-Quellen und damit Nicht-Ziel dieses Vorhabens |
| 05.09.2026 | 5 | Marken (MARKS-Block) | `B_HOVER=9.9; B_DROP=13.5; B_END=17.0`; `CUT_A=0`-Schalter ergänzt, weil Idee A nicht in den Ausschnitt passt |
| 05.09.2026 | 5 | gewählter Take | Take 1 — Cursor liegt in der Hover-Phase neun Frames lang exakt still, Loslassen mittig in „Erledigt", kein Schweben über fremden Karten |
| 05.09.2026 | 5 | ffprobe beider MP4 | beide `h264`, `aac` 48 kHz, `bt709,bt709,bt709,tv`, `30/1`, 7,50 s; 1080 × 1350 und 1080 × 1080 ✓ |
| 05.09.2026 | 5 | GIF / Thumbnail | GIF 2,2 MB (4:5) und 2,1 MB (1:1), beide unter der 8-MB-Grenze; Thumbnail-PNG je Format geschrieben |
| 05.09.2026 | 5 | Kontrollframes | 0 s Hover, 3,6 s gelandet (Erledigt 9, In Bearbeitung 1 / 2, noch ohne Durchstrich), 4,3 s Durchstrich sichtbar, 7,4 s zurück im Startbild. Auf 390 px Breite alle Titel lesbar |
| 05.09.2026 | 5 | Loop-Prüfung | erster und letzter Frame deckungsgleich — Karten, Kapseln (2 / 2, 8) und Cursorposition stimmen überein; keine Verlängerung der Überblendung nötig |
| 05.09.2026 | 6 | Ablageort | `~/Movies/GlassKanban-LinkedIn/` (beide MP4, beide GIF, beide Thumbnails, `take1.mov`, Kontroll- und Loop-Frames) |
| 05.09.2026 | 5 | **Ausschnitt: Widerspruch Konzept ↔ Absicht** | David: „natürlich soll man das gesamte Fenster der App sehen". Das Konzept sagt an zwei Stellen das Gegenteil — 2.5: „Der Ausschnitt zeigt die **rechte Hälfte** des Boards (In Bearbeitung und Erledigt, links angeschnitten Als Nächstes)", und A.6 führt genau das als Abnahmekriterium. Gebaut wurde nach Dokument. **Das Dokument ist an dieser Stelle zu korrigieren, nicht die Absicht** |
| 05.09.2026 | 5 | Kosten des Vollfensters (gemessen) | Halbes Board: 1384 px Aufnahme → 1080 px Ausgabe = **1,56 px/pt**. Ganzes Fenster: 2760 px → 1080 px = **0,78 px/pt**, also exakt halb so groß; Kartentitel landen auf einem 390 px breiten Telefon bei rund 4–5 px Zeilenhöhe. Gilt für **jedes** Format (4:5, 1:1, 16:9) — der Faktor hängt allein an „1380 pt Boardbreite auf 1080 px Videobreite", nicht am Seitenverhältnis |
| 05.09.2026 | 5 | Vollfenster technisch | Kein 4:5- oder 1:1-Bild kann das ganze Fenster vor **echtem** Wallpaper zeigen: 1380 pt Breite bräuchten 1725 pt Höhe, der Bildschirm hat 1080 pt. `cut.sh` bekam deshalb `FRAME=full`, das die Aufnahme auf ein unscharf vergrößertes Duplikat desselben Wallpapers legt — kein erfundener Inhalt, aber eine Kompositionsschicht. Ausgabe geprüft: beide MP4 h264, 1080 × 1350 / 1080 × 1080, bt709, 30/1, 7,50 s |
| 05.09.2026 | 5 | Rand im Vollfenster verkleinert | `FULL_MARGIN` (Vorgabe 8 pt) schneidet auf das Fenster statt auf den Aufnahmebereich: Crop `2632x1256+64+244`. Das Fenster füllt jetzt die volle Videobreite — 1080 statt 1017 px, **+6 %**. Mehr geht ohne Anschnitt des Fensters nicht |
| 05.09.2026 | 5 | Grenze der Vergrößerung | Am Telefon füllt das Video **in jedem** Seitenverhältnis die Bildschirmbreite, das Fenster also auch. 16:9 (`CUT_169=1`, 1080 × 640) nimmt nur den toten Raum weg, es vergrößert die App nicht — und der Beitrag belegt dabei weniger Feed-Höhe. Einziger weiterer Hebel wäre ein schmaleres Fenster (Board-Minimum 1240 pt statt 1300 = weitere 5 %) |
| 05.09.2026 | 5 | **4:5 ist für dieses Board nicht füllbar** | Gegen die Annahme geprüft, das Fenster einfach auf 4:5 zu ziehen. Gemessen: Board-Mindestbreite ist **1220 pt** (nicht 1240, wie das Konzept schreibt); 4:5 hieße dann 1220 × 1525 pt, der Bildschirm hat 1440 pt — passt nicht. Und bei 1220 × 1360 pt (dem Höchsten, was passt) sind zwei Drittel der Spalten **leer**: die Leerfläche wandert nur von außen nach innen. Füllen bräuchte rund 30 Karten je Spalte, also ~100 insgesamt — Widerspruch zum ersten Design-Prinzip |
| 05.09.2026 | 5 | Display 2560 × 1440 HiDPI | `mode 43` gesetzt; Aufnahme bleibt **2×** (Fenster 1300 × 1350 pt → 2600 × 2700 px). Erst diese Höhe erlaubt echten Wallpaper-Rand über und unter dem Fenster |
| 05.09.2026 | 5 | Neuer Aufbau (Davids Vorgabe) | Rand oben/unten großzügig, seitlich knapp, und **echt aufgenommen statt nachträglich gefüllt** („sieht amateurhaft aus"). Fenster 1300 × 612 pt bei (400,420), `MX=20 MY=364` → Aufnahmebereich 1340 × 1340 pt, quadratisch, unter der Menüleiste, 2680 × 2680 px. `cut.sh` bekam `FRAME=native`: nur skalieren, kein Crop, kein Bett, keine Balken |
| 05.09.2026 | 4 | Takes 2 und 3 verdorben | Beide Male sprang mitten im Take ein macOS-Rechte-Dialog nach vorn („claude" möchte den **Finder** steuern) und brach den Zug ab. Ursache war `stage.sh`, das den Finder mit ausblenden wollte — dafür braucht es Apple-Events-Zustimmung. Finder ist jetzt aus der Liste genommen; Schreibtischsymbole sind ohnehin aus, er zeigt also nichts |
| 05.09.2026 | 4 | Take 4 (brauchbar) | 2680 × 2680, 30 fps, 750 Frames, 24,97 s. Marken: Ruhe 10,25–12,00 s, Abheben 12,25 s, gelandet 13,75 s, Durchstrich fertig 14,25 s, Cursor verlässt das Bild ab 17,00 s → `B_HOVER=10.3; B_DROP=13.75; B_END=17.0` |
| 05.09.2026 | 5 | Schnitt nativ 1:1 | `FRAME=native`: nur skalieren, kein Crop, kein Bett. 1080 × 1080, h264, aac, bt709 durchgängig, 30/1, **7,10 s**. Loop geprüft: erster und letzter Frame in Kartenlage, Kapseln und Cursorposition identisch |
| 05.09.2026 | 5 | **Sechs-Linsen-Review (Workflow)** | 67 Agenten, sechs unabhängige Blickwinkel (Komposition, Bewegung, Lesbarkeit, Feed-Tauglichkeit, Prinzipientreue, Artefakte), jeder Befund anschließend adversarisch geprüft. Zwei Blocker überlebten die Widerlegung, dazu ein selbst gefundener |
| 05.09.2026 | 5 | Blocker 1: Farbsprung am Loop | Das `xfade`-Segment war BT.601 kodiert und BT.709 dekodiert → das Wallpaper sprang an der Naht um ~17 Stufen im Grünkanal (~9 %), einmal je Schleife. Gemessen im unteren Wallpaper-Band gegen eine Rauschgrenze von 0,02 |
| 05.09.2026 | 5 | Blocker 2: toter Clip | 63 % der Laufzeit eingefroren, davon 1,57 s am Anfang — genau das Fenster, in dem im Feed über Weiterscrollen entschieden wird. Das Vorschaubild war derselbe tote Frame |
| 05.09.2026 | 5 | Blocker 3 (selbst gefunden): Geistertext | Die 0,6-s-Überblendung legte zwei verschiedene Kartenlisten übereinander; in „Erledigt" standen Zeilen doppelt. Liest sich als Glitch, nicht als Übergang |
| 05.09.2026 | 5 | Behebung | `LOOP_XFADE=0` — harter Schnitt statt Überblendung (behebt Blocker 1 und 3 zugleich); Take 6 mit Zwischenpausen in der Choreografie neu aufgenommen und eng geschnitten (behebt Blocker 2). Nachgemessen: Loop-Naht 0,11 statt 17 Stufen, bewegte Frames 54 % statt 11 %, Frame 1→2 = 36 geänderte Pixel (kein totes Startbild), Stillstand nur noch 0,87 s (gewollte Ruhe vor dem Zug) und 0,33 s (Settle) |
| 05.09.2026 | 5 | **Bildaufteilung gelöst** | Davids Vorgabe „App im Vordergrund, seitlich wenig, oben/unten ein bisschen" ist in 1:1 unerfüllbar: das Fenster ist 2,12:1, ein Quadrat erzwingt 285 px Rand oben und unten. `FRAME=hero` mit `SIDE_PT=20`/`VERT_PT=70` ergibt 1080 × 606, Fenster 97 % der Breite und 81 % der Höhe, **Desktop-Anteil 22 % statt 54 %** |
| 05.09.2026 | 4 | Take 6 (final) | 2680 × 2680, 30 fps, 20 s. Marken 13,83 / 17,47 / 19,05 → Clip **5,23 s**: 1,0 s Anfahrt, 0,97 s Ruhe, 1,67 s Zug, 0,37 s Settle, Durchstrich, kurzer Schluss |
| 05.09.2026 | 5 | Endprüfung | h264, aac 48 kHz, 1080 × 606, `bt709,bt709,bt709,tv`, 30/1, 5,23 s, 0,9 Mbit/s; GIF 0,7 MB; Thumbnail-PNG. Ablage `~/Movies/GlassKanban-LinkedIn/final/` |
| 05.09.2026 | 5 | **Offen: grünes Kopier-Plus** | Bleibt. Es ist App-Verhalten (`ColumnView.swift:183` `.draggable` + `.dropDestination`), 1,33 s sichtbar. Wegzubekommen nur über `onDrop(of:delegate:)` mit `DropProposal(operation: .move)` — Eingriff in die Swift-Quellen, ausdrückliches Nicht-Ziel dieses Vorhabens, braucht Davids Wort |
| 05.09.2026 | 5 | **Formatlogik umgedreht (Davids Vorgabe)** | Bisher wurde das Bild vom Fenster abgeleitet, jetzt das Fenster vom Format: LinkedIn-Format zuerst, dann das Fenster so groß, dass es das Format füllt, Rest als Desktop oben/unten. 4:5 ist auf diesem Bildschirm unmöglich (Board in voller Breite bräuchte 1575 pt Höhe, Bildschirm 1440), also **1:1**. Fenster **1300 × 1000 pt** bei (400,200), `MX=20 MY=170` → Bereich 1340 × 1340 pt. Fenster im Bild 97 % breit, 75 % hoch, Desktop-Anteil **28 %** (fast alles oben/unten). Preis: untere Spaltenhälften sind leeres Glas — von David bewusst in Kauf genommen („mir ist klar, dass die App eher breit als hoch ist") |
| 05.09.2026 | 4 | Take 7 verworfen | ffmpeg/AVFoundation lieferte keine Frames (hing >5 min ohne Datei), Prozess beendet; 2-s-Probe danach wieder in Ordnung. Zug war trotzdem gelaufen → Karte zurückgezogen |
| 05.09.2026 | 4 | **Take 8 (final)** | 2680 × 2680, 30 fps, 20 s. Anfahrt 14,60–15,77, Ruhe 0,97 s, Zug 16,73–18,40, Settle 0,37 s, Durchstrich bis ~19,4 → Marken `14.60 / 18.40 / 19.60`, Clip **5,00 s** |
| 05.09.2026 | 5 | Endprüfung Take 8 | `FRAME=native`, `LOOP_XFADE=0`: 1080 × 1080, h264, aac 48 kHz, bt709/bt709/bt709/tv, 30/1, 1,1 Mbit/s. Bewegte Frames 46 %, Frame 1→2 = 19 Pixel (Bewegung ab Bild 1), Stillstände nur 0,93 s (Ruhe) und 0,33 s (Settle), Loop-Naht-Farbdelta 0,01/0,01/0,02. Ablage `~/Movies/GlassKanban-LinkedIn/final/` (16:9-Fassung aus Take 6 nach `final/alt-16x9/` verschoben) |
| 05.09.2026 | 5 | Schrift über Auflösung? | Nein — Punktgrößen sind fix, Auflösung ändert nur die Pixeldichte. Einziger sauberer Hebel: Fenster auf das Board-Minimum **1220 pt** → Schrift **+6,6 %**. Gezogen |
| 05.09.2026 | 4 | **Take 9 (final)** | Fenster 1220 × 940 pt bei (440,200), `MX=20 MY=160` → Bereich 1260 × 1260 pt = 2520 px. Davids Vorgabe: Video beginnt mit dem Zeiger **auf** der Karte, keine Anfahrt — Zeiger vor Aufnahmestart platziert. Zug 7,83–9,50, Settle 0,33 s, Durchstrich bis 10,8, Zeiger verlässt ab 11,27 → Marken `7.20 / 9.50 / 11.20`, Clip **4,00 s** |
| 05.09.2026 | 5 | Endprüfung Take 9 | 1080 × 1080, h264, aac 48 kHz, bt709/bt709/bt709/tv, 30/1, 1,2 Mbit/s. Bewegte Frames 50 %, Stillstände 0,57 s (Ruhe auf der Karte, gewollt) + 0,30/0,33 s (Settle), Loop-Naht-Farbdelta 0,01/0,02/0,08. Erster Frame: Zeiger auf der Karte; letzter Frame: 9 / 1 / 2, Flamme 7, kein Geist |
| 05.09.2026 | 5 | **Preis der 1220 pt** | Sechs Titel werden mit „…" abgeschnitten (bei 1300 pt: einer): Datenschutzerklärung, Wiederholungen, App-Store-Screenshots, TestFlight, Board bleibt…, WIP-Dialog. Abwägung liegt bei David: +6,6 % Schrift gegen sechs Ellipsen. Die 1300-pt-Fassung (Take 8) liegt in `final/alt-1300pt/` |
| 05.09.2026 | 1 (v2) | **Demo-Datensatz neu für den Show-Aspekt** | Auf Davids Wunsch: weniger Tickets, Titel ohne Ellipse, Listen visuell optimiert. `seed-demo-reminders.swift` v2 (v1 als `.v1` daneben): **18** statt 22 Tickets, alle Titel ≤ 28 Zeichen (bei 1220 pt keine einzige Ellipse, vorher sechs), Notizen ein- bis zweizeilig, nur die Liste „Glass Kanban" sichtbar (ein Akzent statt Blau/Grün-Mischung; „Privat" bleibt leer angelegt), eine wiederkehrende Backlog-Karte als Falz („1 noch nicht fällig" — Regel: `isNotYetDue` greift nur bei wiederkehrenden Backlog-Karten mit Datum). LinkedIn-Karte direkt in `inProgress` geseedet. `--remove` + Seed bei geschlossener App: 18 reminders, 5 pulls; Spalten 7 · 3/5 · 2/2 · 6, Flamme 6 |
| 05.09.2026 | 2 (v2) | Fenster | 1220 × 900 pt bei (440,180), Rand 20/180 → Bereich 1260 × 1260 pt, Desktop-Anteil 30 %. Mehr Luft in den Spalten ist gewollt (weniger Karten) |
| 05.09.2026 | 4 | Take 10 verworfen | Alle Messwerte in Ordnung (4,00 s, Loop-Naht 0,07), aber die Sichtprüfung fand die **Menüleiste im Bild** („…ster Hilfe" oben links): Fenster bei y=180 mit 180 pt Rand → Bereich ab y=0. Fenster auf y=230 versetzt (Bereich 50..1310). Lehre: Bereichs-Oberkante immer ≥ 28 pt prüfen |
| 05.09.2026 | 4 | **Take 11 (final, Datensatz v2)** | Fenster 1220 × 900 pt bei (440,230), `MX=20 MY=180`, 2520 × 2520 px. Marken automatisch aus der Bewegungsanalyse: `7.42 / 9.63 / 11.38` → **3,97 s**. Zeiger liegt ab Bild 1 auf der Karte |
| 05.09.2026 | 5 | Endprüfung Take 11 | 1080 × 1080, h264, aac 48 kHz, bt709/bt709/bt709/tv, 30/1, 1,16 Mbit/s. Bewegte Frames 53 %, Stillstände 0,5 s (Ruhe) + 0,37/0,30 s (Settle), Loop-Naht-Farbdelta 0,02/0,00/0,05, oberste 30 px ohne Menüleisten-Text. Sicht: kein abgeschnittener Titel, Falz „1 noch nicht fällig", Ende 7 · 1/2 · 7, Flamme 6 → 7, kein Geist. Ablage `final/`, Vorgänger (Datensatz v1) in `final/alt-v1-datensatz/` |
| 05.09.2026 | 4 | **Take 12 (final)** | Auf Davids Wunsch Fenster nach oben und unten verlängert: **1220 × 1000 pt** bei (440,170), `MX=20 MY=130`, Bereich 40..1300 (Menüleiste frei). Desktop-Anteil **23 %**. Marken automatisch `7.02 / 9.23 / 10.98` → **3,97 s** |
| 05.09.2026 | 5 | Endprüfung Take 12 | 1080 × 1080, h264, aac 48 kHz, bt709/bt709/bt709/tv, 30/1, 1,11 Mbit/s. Bewegte Frames 48 %, Stillstände 0,5 s (Ruhe) + 0,33/0,37 s (Settle), Loop-Naht-Farbdelta 0,01/0,01/0,03, oberste 30 px ohne Menüleisten-Text. Sicht: kein abgeschnittener Titel, Ende 7 · 1/2 · 7, Flamme 6 → 7, kein Geist. Ablage `final/`, 900-pt-Fassung in `final/alt-900pt/` |
| 05.09.2026 | 6 | Rückstellung geprüft (plutil) | App bei geschlossenem Zustand: `wipLimits {inProgress 3, next 5}`, `appAppearance system`, `excludedCalendarIDs [5AF20BC1-…]`, `completionSoundEnabled` entfernt (war vorher nicht gesetzt), Fenster wieder 1500 × 950. Display beide Dell `UI Looks like 2560 x 1440` (1×), Dock autohide 0, Schreibtischsymbole an, `displayplacer` deinstalliert, Bash-Regel für `record.sh`/`stage.sh` aus `.claude/settings.local.json` entfernt. **Nicht zurückgestellt:** Wallpaper (Sonoma) — der ursprüngliche Hintergrund wurde in Phase 0 nicht notiert; Demo-Listen „Glass Kanban"/„Privat" bleiben laut Plan (RELEASE.md Phase 3), Entfernen: `/tmp/seed-demo --remove` bei geschlossener App |
| 05.09.2026 | 7 | **Kopier-Plus entfernt (App-Code)** | Davids Entscheidung: machen. Branch `feature/drag-move-operation`: `dropDestination` in ColumnView.swift durch `onDrop(of:delegate:)` mit `LaneDropDelegate` ersetzt, `dropUpdated` meldet `DropProposal(operation: .move)`; Ein-/Austritt treiben das Aufleuchten, `performDrop` lädt die Karten-ID asynchron aus dem Item-Provider. Build grün (`scripts/build-app.sh --manual`). **Nachweis am laufenden Programm:** Zug 7 s in der Luft gehalten, AVFoundation-Aufnahme mit Zeiger, Frames bei 6/8/10 s — Pfeil ohne Badge (`final/nachweis-zeiger-ohne-kopier-plus.png`); Drop zweimal erfolgreich (Karte wechselte die Spalte, Zielspalte ohne Nachleuchten). Nebenbefund: `screencapture -C` zeigt während einer laufenden Drag-Session weder Zeiger noch Drag-Bild — für solche Nachweise AVFoundation nehmen. Das Unit-Test-Ziel kompiliert ColumnView.swift nicht (project.yml), die Änderung ist nur am Bildschirm prüfbar |
| 05.09.2026 | 7 | Take 13 verworfen — Badge in der Spaltenlücke | Alle Messwerte in Ordnung, aber bei 1,4 s trägt der Zeiger wieder das Kopier-Plus: Zeigerspitze bei x = 798 px, „In Bearbeitung" endet bei 787, „Erledigt" beginnt bei 806 — der Zeiger steht in der **Lücke**. Dort ist nur der Board-Hintergrund Drop-Ziel (`BoardView.swift`, `dropDestination { false }`), und der meldet keine Operation → Standard *copy*. Der Nachweis zuvor hielt über einer Spalte und war deshalb sauber. Konsequenz: auch der Board-Rückhalt braucht einen Delegate mit `.move` |
| 05.09.2026 | 7 | Board-Rückhalt umgebaut + Nachweis | `BoardView.swift`: `dropDestination { false }` durch `BoardBackstopDelegate` ersetzt — `validateDrop` true, `dropUpdated` → `.move`, `performDrop` false (landet nirgends, beendet nur das Ghosting), `dropExited` beendet den Zug nur, wenn `info.location` außerhalb der Board-Fläche liegt (Übergabe an eine Spalte kommt ebenfalls als Exit an; Größe per `onGeometryChange`). Build grün. **Nachweis:** Karte 7 s in der Spaltenlücke gehalten (Zeiger x = 1349 pt), AVFoundation-Frames bei 7/9/11 s — Pfeil ohne Badge (`final/nachweis-zeiger-in-spaltenluecke.png`); Loslassen in der Lücke änderte nichts, Karte entghostet sauber |
| 05.09.2026 | 7 | Nebenbefund Gatekeeper | Nach dem Build lag wieder `com.apple.quarantine` auf dem Bundle im Projektordner → Start aus einem AppTranslocation-Pfad, Gatekeeper-Dialog auf dem zweiten Display („In den Papierkorb legen" ist dort der Standardknopf — nicht angerührt, David klickt „Fertig"), danach fensterlose Prozesse. Ausweg: für den Dreh aus `~/Library/Caches/GlassKanban/DerivedData/Build/Products/Debug/` starten (außerhalb iCloud, dieselbe Binary) |
| 05.09.2026 | 4 | **Take 14 (final, ohne Kopier-Plus)** | Gleiche Geometrie wie Take 12 (1220 × 1000 pt, `MX=20 MY=130`), App aus DerivedData. Marken automatisch `7.69 / 9.93 / 11.65` → 3,96 s |
| 05.09.2026 | 5 | Endprüfung Take 14 | 1080 × 1080, h264, aac 48 kHz, bt709/bt709/bt709/tv, 30/1, 1,09 Mbit/s. Bewegte Frames 50 %, Stillstände 0,5 s (Ruhe) + 0,23/0,27 s (Settle), Loop-Naht-Farbdelta 0,00/0,06/0,02, keine Menüleiste. **Zeiger bei 1,0 s (Quellspalte), 1,4 s (Lücke) und 1,8 s (Zielspalte): Pfeil ohne Badge** (`final/kontrollframes-zeiger-im-zug.png`). Ende 7 · 1/2 · 7, Flamme 6 → 7. Ablage `final/`, Take 12 nach `final/alt-mit-kopier-plus/` |
| 05.09.2026 | 7 | Zweite Rückstellung geprüft | Nach Take 14 erneut: App beendet, `wipLimits {3, 5}`, `appAppearance system`, `excludedCalendarIDs [5AF20BC1-…]`, `completionSoundEnabled` entfernt, Fensterrahmen 1500 × 950, Display 2560 × 1440 (1×), Dock sichtbar, Schreibtischsymbole an, `displayplacer` deinstalliert. Weiterhin offen: Wallpaper (Original unbekannt), Demo-Listen (laut Plan bleiben), Gatekeeper-Dialog auf Display 2 („Fertig" klicken). Code-Checkpoint: Commit `2ca6ada` auf `feature/drag-move-operation` (ColumnView, BoardView, SPEC); BACKLOG/CLAUDE/RELEASE-Änderungen und `plans/` noch uncommitted |
| 05.09.2026 | 6 | Ablageort der Dateien | `~/Movies/GlassKanban-LinkedIn/final/` (Take 12: MP4, GIF, Thumbnail, Kontrollframes, `take12.mov`); frühere Fassungen in `final/alt-16x9`, `alt-1300pt`, `alt-v1-datensatz`, `alt-900pt`; ältere Takes und Schnitte nur noch unter `/tmp` |

---

## Stand 05.09.2026, spät — abgeschlossen

Erledigt: Phasen 0–6, dazu Phase 7 (Kopier-Plus im App-Code behoben, Take 14). Endfassung in
`~/Movies/GlassKanban-LinkedIn/final/` (MP4, GIF, Thumbnail, Kontrollframes, Nachweise, Rohtake).
Doku: konzept.md „Ergebnis", RELEASE.md-Kästchen, BACKLOG-Eintrag (umgesetzt), CLAUDE.md
(Drag-Notiz, Quarantäne-Hinweis), SPEC.md (Drag & Drop als Verschieben). Umgebung zweimal
zurückgestellt (Messprotokoll Phase 6/7); Demo-Listen auf Davids Wunsch entfernt — der Datensatz
lebt in `seed-demo-reminders.swift` und ist mit einem Aufruf wieder da. Offen nur das Posten
(konzept.md 8a).

## Startprompt für die Umsetzungs-Session (kopieren)

> Setze `plans/linkedin/umsetzungsplan.md` um, beginnend bei „Stand 05.09.2026 — was offen
> ist". Lies zuerst genau die Dateien und Abschnitte unter „Zuerst lesen", nichts weiter.
> Phase 0 und 1 sind erledigt, die Messwerte stehen im Messprotokoll — nicht wiederholen.
> Ich habe den Look freigegeben. Starte mit Phase 2: gib mir die Display-Anleitung aus
> konzept.md A.7, warte auf mein „fertig", dann miss nach (H2) und geh weiter bis H3. Bei
> jedem Haltepunkt sendest du das Ergebnis als Datei und wartest. Bewege keine Karten selbst,
> schreibe nur in die Reminders-Listen „Glass Kanban" und „Privat", fasse `columns.json` und
> App-Defaults nur bei geschlossener App an, und trage jede Messung ins Messprotokoll ein.
> Ich bin am Rechner und übernehme die Züge nach `plans/linkedin/drehbuch.md`.

Wenn der Look **nicht** freigegeben ist: den Satz „Ich habe den Look freigegeben" durch die
Änderung ersetzen (z. B. „Wallpaper heller", „Fenster 1240 breit") — die Session wiederholt
dann A.5/A.6 und sendet H1 erneut, bevor sie in Phase 2 geht.
