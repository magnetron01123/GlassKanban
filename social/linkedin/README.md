# LinkedIn-Clip neu erzeugen — Ablauf

Ziel: `glass-kanban-one-move-1x1.mp4` (1080 × 1080, h264/aac, BT.709, 30 fps, ≈ 4 s,
harter Loop), dazu GIF und Thumbnail — aus einer echten Aufnahme des Boards mit dem
Demo-Datensatz. Der Ablauf ist für eine eigene Session geschrieben und wurde am
05.09.2026 so durchlaufen (Take 14). Jeder Schritt hat Befehl, Erwartung und einen
Nachweis, der etwas hinterlässt. Arbeitsverzeichnis ist der **Projektstamm**.

Warum es so aussieht, steht in `konzept.md` (Haltung, Datensatz, Beitragstexte,
Upload-Checkliste). Hier steht nur das Wie.

| Datei | Zweck |
|---|---|
| `seed-demo-reminders.swift` | Demo-Liste anlegen/entfernen, Spalten in `columns.json` schreiben |
| `window-id.swift` | Position und Größe des Board-Fensters in Punkten |
| `stage.sh` | blendet alle anderen Apps aus (`hide`) und wieder ein (`show`) |
| `record.sh` | nimmt einen Take auf: Fenster + Rand, Zeiger, 20 s, ffmpeg/AVFoundation |
| `marks.sh` | liest die drei Schnittmarken per Bewegungsanalyse aus dem Take |
| `cut.sh` | schneidet MP4, GIF und Thumbnail; ruft `marks.sh`, wenn keine Marken übergeben werden |
| `frames.sh` | Kontaktbogen (ein Bild je 0,25 s) zum Nachsehen |

## 0. Voraussetzungen (5 min)

```
pgrep -fl "Glass Kanban" || echo "keine Instanz"     # laufende Instanz → beenden
which ffmpeg displayplacer                           # fehlt: brew install ffmpeg displayplacer
ls ~/Library/Caches/GlassKanban/DerivedData/Build/Products/Debug/"Glass Kanban.app"
```

- Die App **aus DerivedData** starten, nicht aus dem Projektordner — die Kopie in iCloud
  Drive kann quarantänisiert sein und startet dann aus einem Temp-Pfad (CLAUDE.md,
  „Arbeitsweise"). Fehlt der Build: `scripts/build-app.sh --manual`.
- Rechte, die macOS je einmal abfragt und die nur der Mensch bestätigen kann:
  **Erinnerungen** für das Terminal (bei Schritt 1) und **Bildschirmaufnahme** für die
  App, aus der das Terminal läuft (bei Schritt 4). Sonst nichts.
- Sichern, was zurückgestellt wird:

```
D=com.davidtrogemann.GlassKanban
cp ~/Library/Containers/$D/Data/Library/Preferences/$D.plist /tmp/prefs-backup.plist
cp ~/Library/Containers/$D/Data/Library/Application\ Support/GlassKanban/columns.json /tmp/columns-backup.json
displayplacer list | tail -1 > /tmp/display-restore.sh      # letzte Zeile = Rückstellbefehl
```

## 1. Demo-Datensatz (5 min) — bei geschlossener App

Der Datensatz ist **relativ zu heute** (Fälligkeit, Erledigt-Daten, Streak). Ein alter
Seed zeigt eine falsche Flamme, deshalb immer neu anlegen:

```
swiftc -O -o /tmp/seed-demo social/linkedin/seed-demo-reminders.swift
/tmp/seed-demo --remove 2>/dev/null; /tmp/seed-demo
```

Erwartung: `created 18 reminders in Glass Kanban, Privat` und `5 pulls written`.
„Privat" wird leer angelegt, nur „Glass Kanban" trägt Karten. Das Skript verweigert,
wenn die App läuft. Nachweis:

```
python3 -c "import json;d=json.load(open('$HOME/Library/Containers/com.davidtrogemann.GlassKanban/Data/Library/Application Support/GlassKanban/columns.json'));print(sorted(v['lane'] for v in d['pulls'].values()))"
```

→ zweimal `inProgress`, dreimal `next` (plus vorhandene echte Einträge).

## 2. App-Einstellungen (5 min) — bei geschlossener App

```
D=com.davidtrogemann.GlassKanban
defaults write $D wipLimits -dict inProgress -int 2 next -int 5
defaults write $D appAppearance -string light
defaults write $D completionSoundEnabled -bool true
defaults write $D foldNotYetDue -bool true
```

Listen: `excludedCalendarIDs` ist die Liste der **ausgeblendeten** Listen-IDs. Alle IDs
eintragen, deren Titel nicht „Glass Kanban" oder „Privat" ist:

```
swift - <<'EOF'
import EventKit
let s = EKEventStore(); let g = DispatchGroup(); g.enter()
s.requestFullAccessToReminders { _, _ in g.leave() }; g.wait()
for c in s.calendars(for: .reminder) { print(c.calendarIdentifier, c.title) }
EOF
defaults write $D excludedCalendarIDs -array "<ID-1>" "<ID-2>" …
```

Nachweis nicht mit `defaults read` (cfprefsd-Cache), sondern:

```
plutil -p ~/Library/Containers/$D/Data/Library/Preferences/$D.plist | grep -A3 "wipLimits\|appAppearance\|excludedCalendarIDs"
```

Systemsprache Deutsch (der Beitrag ist deutsch).

## 3. Bühne (5 min)

```
defaults write com.apple.dock autohide -bool true; killall Dock
defaults write com.apple.finder CreateDesktop false; killall Finder
osascript -e 'tell application "System Events" to tell every desktop to set picture to POSIX file "/System/Library/Desktop Pictures/Sonoma.heic"'
```

Display auf **2×** (die Aufnahme braucht 2520 px für 1260 pt): in `displayplacer list`
beim Hauptdisplay die Zeile `res:2560x1440 … scaling:on` suchen und deren `mode:N` setzen:

```
displayplacer list | grep "Persistent screen id\|2560x1440.*scaling:on"
displayplacer "id:<Persistent screen id des Hauptdisplays> mode:<N>"
```

Nachweis kommt in Schritt 4 (Aufnahmebreite). Zwei Fallen, beide gemessen: Der Finder
darf **nicht** ausgeblendet werden (Apple-Events-Dialog mitten im Take; `stage.sh` lässt
ihn deshalb aus), und ein Gatekeeper-Dialog kann auf dem zweiten Display liegen und die
Aufnahme-App blockieren — vorher nachsehen.

## 4. App, Fenster, Zeiger (5 min)

```
open ~/Library/Caches/GlassKanban/DerivedData/Build/Products/Debug/"Glass Kanban.app"; sleep 3
osascript -e 'tell application "System Events" to tell process "Glass Kanban" to tell window 1
  set position to {440, 170}
  set size to {1220, 1000}
end tell'
swiftc -O -o /tmp/window-id social/linkedin/window-id.swift; /tmp/window-id
```

Erwartung: `w=1220 h=1000`. 1220 ist die Mindestbreite des Boards (größte Schrift ohne
abgeschnittene Titel); 1000 füllt das Quadrat, Rand 20 pt seitlich, 130 pt oben/unten,
Menüleiste bleibt draußen.

Screenshot per computer-use (`app_screenshot`, Bundle-ID `com.davidtrogemann.GlassKanban`)
und diese Liste abhaken, **jeden Punkt einzeln**:

- Backlog: 6 Karten und die Falz „1 noch nicht fällig", Kapsel „7"
- Als Nächstes: 3 Karten, Kapsel „3 / 5"
- In Bearbeitung: „Doku-Konsistenz prüfen" und „LinkedIn-Video aufnehmen" (Chip „Heute", `!!`), Kapsel „2 / 2"
- Erledigt: 6 Karten mit Durchstrich, Kapsel „6"
- Toolbar links: Flamme mit **„6"**. Anders → Erledigt-Daten liegen falsch, Schritt 1 wiederholen
- keine Karte aus fremden Listen, kein abgeschnittener Titel

Dann den Zeiger **auf die Karte „LinkedIn-Video aufnehmen"** legen (computer-use
`mouse_move`, Kartenmitte aus dem Screenshot) und liegen lassen. Der Clip beginnt mit
dem Zeiger auf der Karte, ohne Anfahrt.

## 5. Aufnahme (2 min je Take)

```
social/linkedin/record.sh 1        # 3 s Vorlauf, dann 20 s → /tmp/take1.mov
```

Das Skript blendet andere Apps aus, holt das Board nach vorn, findet das Display selbst
(„Capture screen 0") und blendet die Apps am Ende wieder ein.

**Der Zug** läuft synthetisch, aber nur auf HID-Ebene (CLAUDE.md, „Drag & Drop"): ab
Sekunde 7 nach dem Start eine `computer_batch` mit `left_mouse_down` auf der Karte,
**sieben** `mouse_move` in gleichen Schritten auf dieselbe Höhe in der Spalte
„Erledigt" (eine Spaltenbreite weiter rechts, ≈ 300 pt bei 1220 pt Fenster), danach
`left_mouse_up`; Gesamtdauer ≈ 1,7 s. Danach **nichts** mehr bewegen, bis die Aufnahme
endet. Der Hintergrund-`app_drag` taugt nicht: Er lässt die Karte nie los.

Nachweis:

```
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,nb_frames -show_entries format=duration -of default=nw=1 /tmp/take1.mov
```

→ `2520 × 2520`, `30/1`, ≈ 600 Frames. Ist die Breite 1260: Display steht auf 1×, zurück
zu Schritt 3. Sichtprüfung eines Frames beim Zug (`ffmpeg -ss 8 -frames:v 1`): Zeiger als
**schlichter Pfeil**, kein grünes Plus, kein Greifsymbol.

Für einen weiteren Take: `Bearbeiten › Widerrufen` in der App (Karte zurück, Flamme 6),
Zeiger wieder auf die Karte, `record.sh 2`.

## 6. Schnitt (2 min)

```
social/linkedin/cut.sh /tmp/take1.mov /tmp/cut
```

Das Skript liest die Marken selbst (`marks.sh`: Ruhe 0,5 s, Zug, Settle, Durchstrich,
Nachlauf 1,1 s) und meldet sie; erwartete Cliplänge **3,8–4,1 s**. Sind die Marken
unplausibel: `social/linkedin/frames.sh /tmp/take1.mov`, Bilder ansehen, Marken von Hand
als Argumente 3–5 übergeben.

Nachweis, alles in einem Lauf:

```
F=/tmp/cut/glass-kanban-one-move-1x1.mp4
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate,color_space,color_transfer,color_primaries,color_range -show_entries format=duration -of default=nw=1 $F
for t in 0 1.0 1.4 1.8; do ffmpeg -v error -y -ss $t -i $F -frames:v 1 /tmp/cut/check-$t.png; done
ffmpeg -v error -y -sseof -0.04 -i $F -frames:v 1 /tmp/cut/check-last.png
```

→ `h264`, `1080 × 1080`, `30/1`, `bt709/bt709/bt709/tv`. Bilder: bei 0 s Zeiger auf der
Karte; bei 1,0 / 1,4 / 1,8 s (Quellspalte, Spaltenlücke, Zielspalte) Zeiger ohne Badge;
letztes Bild Kapseln **7 · 1/2 · 7**, Flamme **7**, kein Geist der Karte. Loop: Datei in
QuickTime mit ⌥⌘L abspielen, die Naht darf nicht springen.

Am 05.09.2026 gemessen: Der Standardaufruf auf `take14.mov` liefert 3,90 s (von Hand
geschnitten waren es 3,97 s), identisches Thumbnail, gleiche Bitrate — dasselbe Video.

## 7. Ablage

```
cp /tmp/cut/glass-kanban-one-move-1x1.mp4 /tmp/cut/glass-kanban-one-move-1x1.gif /tmp/cut/glass-kanban-thumbnail-1x1.png social/linkedin/
mkdir -p ~/Movies/GlassKanban-LinkedIn && cp /tmp/take1.mov ~/Movies/GlassKanban-LinkedIn/
```

Ins Repo kommen nur die drei Ergebnisdateien. Rohtake und Kontrollframes bleiben in
`~/Movies`.

## 8. Rückstellung (5 min) — bei geschlossener App

```
osascript -e 'tell application "Glass Kanban" to quit'
sh /tmp/display-restore.sh
defaults write com.apple.dock autohide -bool false; killall Dock
defaults write com.apple.finder CreateDesktop true; killall Finder
D=com.davidtrogemann.GlassKanban
cp /tmp/prefs-backup.plist ~/Library/Containers/$D/Data/Library/Preferences/$D.plist
/tmp/seed-demo --remove          # oder stehen lassen, wenn die Liste noch gebraucht wird
```

Nachweis mit `plutil -p` auf die plist (Werte wie vor Schritt 2) und `displayplacer list`
(1×). Das Wallpaper vorher notieren, wenn es zurück soll — am 05.09.2026 fehlte diese
Notiz.
