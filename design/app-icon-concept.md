# App-Icon — Konzept: „Drei Spalten, die mittlere betont"

Status: umgesetzt. Ausgeliefert wird `GlassKanban/AppIcon.icon`, ein
Icon-Composer-Dokument — macOS 26 rechnet Glas, Spiegelung und Schatten selbst
und leitet daraus Hell-, Dunkel- und Getönt-Variante ab.

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
| links (Backlog) | 22 | 44 | 34 | 92 |
| Mitte (In Arbeit) | 58 | 44 | 34 | 92 |
| rechts (Erledigt) | 94 | 44 | 34 | 92 |

Überlappung 8, Eckenradius 10, durchgehend `.continuous` — die gleiche
Squircle-Familie, die `Board.columnShape` verwendet. Ein kreisrunder Radius
wäre genau das „fast nativ", vor dem `DesignSystem.swift` warnt.

Die mittlere Spalte liegt vorn und trägt den tieferen Schatten. Der ist das
Einzige, was die drei trennt — deshalb sitzt sie in einer eigenen Gruppe:
Icon Composer vergibt Schatten pro Gruppe, nie pro Ebene.

## Farben

Der Ton stammt aus der App: `#DCDEE0`, das Fensterglas im laufenden Board
gemessen. Keine Akzentfarbe — die App beansprucht keine Markenfarbe, und Teal
ist in `Board.wipLimitTint` als Kapazitätssignal belegt. Zur Helligkeit siehe
„Wiedererkennung" oben.

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

## Was ausgeliefert wird: das `.icon`-Dokument

Ein Icon-Composer-Dokument ist kein Binärformat, sondern schlicht ein Ordner
mit `icon.json` und den Ebenenbildern. Es wird deshalb hier **erzeugt** statt in
der GUI zusammengeklickt — sonst driftet es von den Konstanten oben weg.

Aufbau von `GlassKanban/AppIcon.icon`:

| | Hell | Dunkel (`fill-specializations`) |
|---|---|---|
| Platte (`solid`) | `#8D8F91` | `#3F4041` |
| Spalten | Glas, Durchsicht 0,5 | Glas, Durchsicht 0,5 |

Beide Plattenwerte tragen den Farbton des App-Fensterglases. Zwei Gruppen:
äußere Spalten (Schatten 0,3), mittlere Spalte darüber (Schatten 0,55).
`specular` an — den Rest macht macOS.

**Die Ebenen sind flache Silhouetten, keine Bilder.** macOS leitet Glas,
Glanzkante und Schatten selbst daraus ab. Hätte man eine gemalte Fassung
übergeben, lägen zwei Glasbehandlungen übereinander.

Damit fällt die Hand-Arbeit an Rändern und Füllungen für das ausgelieferte
Icon weg — sie bleibt im Generator als Referenz und als Notfall-Fallback
(`AppIcon.appiconset`), ist aber **nicht** das, was gebaut wird.

### Hell, Dunkel und Getönt

Der kompilierte Katalog enthält drei getrennte Ebenenstapel — je einen für
`NSAppearanceNameAqua`, `NSAppearanceNameDarkAqua` und `ISAppearanceTintable`
— auch dann, wenn das Manifest nichts über sie sagt. **Eine Dunkelvariante ist
also vorhanden; macOS leitet sie ab.** Dazu kommen sieben flach gerenderte
Größen unter `NSAppearanceNameSystem`.

Die Dunkelfassung wird **explizit gesetzt**, nicht dem System überlassen. Eine
Fassung ohne jede Dunkel-Angabe wirkte im Dunkelmodus deutlich zu hell — die
Füllung ist ein fester Farbwert, und nichts deutet darauf hin, dass er von
selbst nachdunkelt.

**Prüfstand.** Die Dunkelfassung ließ sich nicht bestätigen — und der Weg
dorthin gehört dokumentiert, damit ihn niemand zweimal geht:

- Die App-Einstellung „Erscheinungsbild" hilft nicht: sie setzt
  `NSApp.appearance` und wirkt auf die Fenster. Das Dock zeichnet **alle**
  Symbole im System-Erscheinungsbild; eine App kann ihr eigenes Dock-Symbol
  nicht umschalten.
- `assetutil` listet Renditions nur auf und extrahiert nicht.
- Über CoreUI (`CUICatalog`) sind die drei Stapel erreichbar, aber es sind
  `_CUILayerStackRendition` ohne Bildzugriff. Ihre Rohdaten (`srcData`) sind je
  551 Bytes, unterscheiden sich zwischen Hell und Dunkel um **zwei Bytes** und
  enthalten Kompositionswerte, **keine Farben**.
- Offscreen rendern geht mit
  `NSAppearance.performAsCurrentDrawingAppearance` — die Methode heißt so, ein
  früherer Versuch scheiterte an einem erfundenen Namen. Gegenprobe bestanden
  (`windowBackgroundColor` liefert `#FFFFFF` gegen `#1E1E1E`). Das Icon kommt
  in beiden Erscheinungen als `#9DA0A2` heraus — **identisch**. Dieser Weg
  liest allerdings die flach gerenderte Fassung, nicht den Ebenenstapel, den
  das Dock zusammensetzt.

Zusammen genommen: die Plattenfarbe ist sehr wahrscheinlich in beiden
Erscheinungen dieselbe, und der Dunkel-Eintrag bewirkt vermutlich nichts. Er
bleibt trotzdem stehen — er schadet nicht, und falls macOS ihn auswertet, ist
der Ton dort richtig.

**Deshalb ist der Plattenton so gewählt, dass er in beiden Fällen trägt.** Ob
die Dunkelfassung greift oder nicht, ändert an der Lesbarkeit nichts; das war
die Abtastung gegen hellen und dunklen Grund.

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
