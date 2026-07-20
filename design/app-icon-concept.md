# App-Icon — Konzept: „Drei Spalten, die mittlere betont"

Status: umgesetzt. Ausgeliefert wird der gemalte Asset-Katalog
`GlassKanban/Assets.xcassets/AppIcon.appiconset` — Glas, Glanzkanten und
Schatten sind gezeichnet, nicht vom System gerechnet. Warum nicht das
Icon-Composer-Dokument: siehe „Der Zielkonflikt" unten.

## Leitidee

Das Icon zeigt das **Board**, nicht ein Ticket: drei gleich große Glasspalten
auf einer einfarbigen Platte, leicht überlappend, die mittlere vorn.

Kein Motiv aus einzelnen Karten, kein Symbol, keine Schrift — bei 16 pt in der
Menüleiste überlebt genau eine Aussage, und die soll „Board" sein.

**Alle drei Spalten sind gleich.** Sie sind drei Spalten eines Boards;
unterschiedliche Größen oder Farben machen daraus verschiedene Arten von Objekt
und die Board-Lesart ist weg (siehe „Bewusst verworfen"). Betont wird die
mittlere allein dadurch, dass sie vorn liegt und Schatten wirft.

## Wiedererkennung zwischen Icon und App

Vier Dinge tragen sie:

1. **Formensprache** — dieselben `.continuous`-Squircles und Radienfamilie wie
   `Board.columnShape`.
2. **Komposition** — drei Spalten, die mittlere hervorgehoben, so wie das Board
   die Arbeitsspalte hervorhebt.
3. **Material** — Glas mit Spiegelung, das Material des Fensters.
4. **Farbton** — exakt der des Fensterglases (`#DCDEE0`, im Board gemessen),
   nur dunkler.

**Warum nicht dieselbe Helligkeit:** Die Flächen der App sind durchscheinend
und liegen auf dem Schreibtischbild — sie leihen sich Kontrast von dort. Ein
Icon hat nichts hinter sich. Mit dem wörtlichen Fensterton als Platte
verschwindet es auf hellem Dock-Grund, und die weißen Glasspalten haben keinen
Kontrast mehr. Geprüft über eine Reihe von Plattenhelligkeiten: ab etwa 0,56
lesen die Spalten auf hellem wie dunklem Grund.

**Verworfen:** eine weiße Karte in der mittleren Spalte, als direktes Zitat der
Board-Karten. Sie verschmilzt mit der Glasspalte zu einem hellen Fleck und
macht das Motiv unklarer statt klarer.

## Warum die Mitte den Fokus trägt

Kanbans Kern ist das WIP-Limit; die Maxime lautet „stop starting, start
finishing". Der Engpass, auf den man schaut, ist die laufende Arbeit —
„Erledigt" ist ein Archiv, dessen Wert bereits geliefert ist.

Das Board macht es intern längst genauso: Laut `iteration-2-concept.md`
gehört „die Bühne" den Arbeitsspalten, Backlog und Erledigt sind „Ablagen an
den Rändern" (Punkt 8); auf breiten Displays wachsen nur die Arbeitsspalten auf
440 pt, während die Ablagen bei 320 pt gedeckelt bleiben (Punkt 9); und
erledigte Karten verlieren in `CardView.swift` bewusst ihren Ambient-Schatten.

Im Icon übersetzt sich das nicht in Größe, sondern in Tiefe: die
Arbeitsspalte liegt vorn.

## Geometrie

Entworfen auf einem **160 × 160**-Raster, beim Rendern skaliert. macOS zeichnet
App-Icons als 824 × 824 großes abgerundetes Quadrat innerhalb der 1024er
Fläche; der Rand ist Platz für den Schatten des Icons.

| Spalte | x | Breite | y | Höhe |
|---|---|---|---|---|
| links (Backlog) | 35 | 34 | 36 | 88 |
| Mitte (In Arbeit) | 63 | 34 | 36 | 88 |
| rechts (Erledigt) | 91 | 34 | 36 | 88 |

Überlappung 6, Eckenradius 9, durchgehend `.continuous` — die gleiche
Squircle-Familie, die `Board.columnShape` verwendet. Ein kreisrunder Radius
wäre genau das „fast nativ", vor dem `DesignSystem.swift` warnt.

Die mittlere Spalte liegt vorn, hat aber **dieselben Werte** wie die beiden
anderen — Farbe, Durchsicht, Kante, Schatten. Die Tiefe entsteht allein daraus,
dass zwei durchscheinende Lagen übereinander dunkler werden. Das ist, was Glas
tut, und es macht den Effekt schon bei normaler Icon-Größe sichtbar.

## Farben

**Weiße Platte, graue Spalten** — `#FEFEFF` oben nach `#EBEBED` unten, gemessen
am Icon von Erinnerungen (`#FEFEFF` / `#EFEFEF`). Eine graue Platte stand in der
Leiste neben den Systemsymbolen fremd da; Weiß stellt das Icon in dieselbe
Familie.

Das trifft nebenbei das Board besser als jede frühere Fassung: dort ist das
Fenster hell und die Bahnen **verdunkeln** es (`Board.columnFill` ist ein
schwarzer Wash). Genau dieses Verhältnis hat das Icon jetzt — deshalb liegen
die Spalten als schwarze Lagen auf der Platte, nicht als weiße.

Keine Akzentfarbe — die App beansprucht keine Markenfarbe, und Teal ist in
`Board.wipLimitTint` als Kapazitätssignal belegt.

Die Spalten lassen bewusst Rand: eine erste weiße Fassung füllte die Platte
fast aus und wirkte schwer neben Erinnerungen, dessen Inhalt viel Weiß stehen
lässt.

## Warum die Spalten Glas sein müssen

Die App heißt Glass Kanban. Eine Zwischenfassung zeichnete die Spalten als
dunkelgraue Flächen mit heller Oberkante — das ist gebürstetes Metall, nicht
Glas, und damit war das Icon unbrauchbar.

Glas entsteht aus vier Dingen zusammen, keines reicht allein:

1. **Durchsicht.** Die Füllung ist ein sehr schwacher Wash (Schwarz 6 % oben
   nach 13 % unten), nicht eine Fläche. Man sieht die Platte hindurch.
2. **Lichtkante oben.** Ein kräftiger weißer Rand, wo Licht eintritt.
3. **Brechungslinie unten.** Eine dunkle Kante, aber **nur in der unteren
   Hälfte**. Lief sie von oben, saß sie direkt unter der Lichtkante und die
   Scheibe kippte wieder ins Metallische.
4. **Innenlicht.** Ein Verlauf *innerhalb* der Scheibe, von der Oberkante zur
   Mitte auslaufend. Das ist der eigentliche Unterschied zu einer flachen
   Platte: die Helligkeit sitzt im Körper, nicht nur auf dem Umriss.

Dazu ein weicher Schatten unter jeder Scheibe, damit sie über der Platte steht.

Die Spalten sind außerdem schmaler und höher als zuvor (34 × 88 statt 38 × 78),
damit sie als Spalten lesen und nicht als Blöcke.

Unterhalb von 32 px entfällt der äußere Schatten des Icons — er würde nur
Pixel fressen, die die Silhouette braucht.

## Bewusst verworfen

- **Einzelne Karten oder ein Ticket als Motiv.** Sagt bei kleiner Größe
  „Dokument", nicht „Kanban", und kollidiert optisch mit Erinnerungen/Notizen.
- **Unterschiedlich hohe Säulen (aufsteigend).** Liest sich als
  Balkendiagramm und stellt ausgerechnet „Erledigt" heraus.
- **Überlappende Scheiben.** Zweimal versucht, zweimal gescheitert. Die
  Scheiben verschmelzen zu einer Silhouette. Der Reparaturversuch — die
  äußeren dunkler einfärben, damit sie sich absetzen — machte es schlimmer:
  aus drei Spalten wurden zwei dunkle Klötze mit einem hellen Zeichen
  dazwischen, und das Motiv war nicht mehr zu erkennen. **Lehre:** jede
  Einzelverbesserung (Kontrast, Kleingröße, Deckkraft) muss gegen die Frage
  geprüft werden, ob das Ganze noch ein Board zeigt. Mehrere lokal richtige
  Schritte ergaben zusammen ein unlesbares Icon.
- **Eine durchscheinende Platte.** Die Spalten sind Glas, der Grund nicht: ein
  Icon, durch das man hindurchsieht, ist auf dem Schreibtisch kein
  Bedienelement. Deshalb `solid` statt Verlauf oder Durchsicht.
- **Vier Scheiben** entsprechend der vier echten Spalten. Bei 16 px unlesbar,
  und die beiden äußeren sagen ohnehin dasselbe: Ablage. Drei ist die
  kanonische Kanban-Abstraktion.
- **Getöntes Teal.** Hübsch und im Dock unterscheidbar, kollidiert aber mit
  der reservierten Bedeutung von Teal im Code.
- **Warmes Sandgrau.** Hätte die Papier-Metapher aufgegriffen und wäre im
  Dock am unterscheidbarsten gewesen, liest sich aber weniger als „Glas".
- **Kühles Graublau.** War zwischenzeitlich gesetzt und gab dem Icon im Dock
  mehr Eigenständigkeit — passte aber nicht zum eigenen Fenster, das
  nachweislich neutral ist. Im Zweifel führt die GUI.

## Der Zielkonflikt: gemalt oder Icon Composer

Beide Wege wurden gebaut und verglichen.

| | Gemalter Katalog | `.icon` (Icon Composer) |
|---|---|---|
| Aussehen | genau wie entworfen | macOS rendert neu, flacher |
| Spalten gleich | garantiert, ein Renderer | nur bei identischen Gruppenwerten |
| Helligkeit steuerbar | ja | ja |
| Eigene Dunkelfassung | **nein** | ja, aber nicht prüfbar |

**Klassische App-Icon-Kataloge tragen keine Hell/Dunkel-Varianten.** Ein
Katalog mit `"appearances": [{"appearance": "luminosity", "value": "dark"}]`
kompiliert ohne Fehler *und ohne Wirkung*: `actool` verwirft die Dunkel-
Einträge stillschweigend, im Ergebnis steht keine einzige Erscheinungs-Kennung.

Beim `.icon` gibt es die drei Stapel — dafür rechnet macOS das Glas selbst und
das Ergebnis sah anders aus als der abgestimmte Entwurf. Zwei Gruppen mit
unterschiedlichen Schattenwerten (0,3 gegen 0,55) ließen die mittlere Spalte
zudem wie eine andere Größe wirken, obwohl die Ebenen exakt gleich hoch waren
(beide 275–748 px im 1024er Bild) — macOS beleuchtet jede Gruppe einzeln.

Entschieden wurde für den gemalten Katalog: drei von vier Anforderungen sind
damit nachweisbar erfüllt, und ein Symbol für beide Erscheinungen ist auf macOS
der Normalfall. Der Plattenton ist so gewählt, dass er auf hellem wie dunklem
Dock-Grund trägt.

Das `.icon`-Dokument erzeugt das Skript weiterhin mit — falls die
Dunkelfassung später wichtiger wird als die Kontrolle über das Aussehen.
Ein `.icon` ist schlicht ein Ordner mit `icon.json` und Ebenenbildern, also
erzeugbar statt in der GUI zusammenklickbar.

### Grenzen der Prüfbarkeit beim `.icon`

Dokumentiert, damit der Weg nicht zweimal gegangen wird:

- Die App-Einstellung „Erscheinungsbild" hilft nicht: sie setzt
  `NSApp.appearance` und wirkt auf die Fenster. Das Dock zeichnet **alle**
  Symbole im System-Erscheinungsbild.
- `assetutil` listet Renditions nur auf und extrahiert nicht.
- Über CoreUI sind die drei Stapel erreichbar, aber es sind
  `_CUILayerStackRendition` ohne Bildzugriff; ihre Rohdaten enthalten
  Kompositionswerte, **keine Farben**.
- Offscreen rendern geht mit
  `NSAppearance.performAsCurrentDrawingAppearance` — Gegenprobe bestanden,
  das Icon kommt in beiden Erscheinungen identisch heraus. Dieser Weg liest
  allerdings die flach gerenderte Fassung, nicht den Ebenenstapel.

## Erzeugung

    swift scripts/render-app-icon.swift <zielordner>

Schreibt `AppIcon.icon` (nach `GlassKanban/` kopieren — das ist der
ausgelieferte Stand), dazu den Fallback-`AppIcon.appiconset`, die gemalten
Ebenen und Vorschauen in Hell und Dunkel. Nach jeder Änderung an den Konstanten
im Skript neu laufen lassen.

XcodeGen braucht dafür keine Sonderregel: es erkennt `.icon` als
`wrapper.icon` und legt es als eine Einheit in die Resources-Phase.

Prüfen, ohne das ganze Projekt zu bauen:

    xcrun actool --app-icon AppIcon --compile <out> --platform macosx \
      --minimum-deployment-target 26.0 \
      --output-partial-info-plist <out>/p.plist <pfad>/AppIcon.icon

Wichtig: Der Bundle-Name muss `AppIcon.icon` lauten, sonst findet `actool` das
Asset nicht und erzeugt stillschweigend nur die Plist statt eines Icons.
