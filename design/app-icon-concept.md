# App-Icon — Konzept: „Drei Scheiben, die mittlere vorn"

Status: umgesetzt. Ausgeliefert wird `GlassKanban/AppIcon.icon`, ein
Icon-Composer-Dokument — macOS 26 rechnet Glas, Spiegelung und Schatten selbst
und leitet daraus Hell-, Dunkel- und Getönt-Variante ab.

## Leitidee

Das Icon zeigt das **Board**, nicht ein Ticket: drei überlappende Glasscheiben,
die mittlere breiter, höher, dichter und vorne, mit Schattenwurf auf die beiden
dahinter. Zwei Ablagen links und rechts, dazwischen die Arbeit.

Kein Motiv aus einzelnen Karten, kein Symbol, keine Schrift — bei 16 pt in der
Menüleiste überlebt genau eine Aussage, und die soll „Board" sein.

## Warum die Mitte den Fokus trägt

Kanbans Kern ist das WIP-Limit; die Maxime lautet „stop starting, start
finishing". Der Engpass, auf den man schaut, ist die laufende Arbeit —
„Erledigt" ist ein Archiv, dessen Wert bereits geliefert ist.

Das Board macht es intern längst genauso: Laut `iteration-2-concept.md`
gehört „die Bühne" den Arbeitsspalten, Backlog und Erledigt sind „Ablagen an
den Rändern" (Punkt 8); auf breiten Displays wachsen nur die Arbeitsspalten auf
440 pt, während die Ablagen bei 320 pt gedeckelt bleiben (Punkt 9); und
erledigte Karten verlieren in `CardView.swift` bewusst ihren Ambient-Schatten.

Das Breitenverhältnis der Scheiben im Icon (58 zu 48) ist genau dieses
440-zu-320.

## Geometrie

Entworfen auf einem **160 × 160**-Raster, beim Rendern skaliert. macOS zeichnet
App-Icons als 824 × 824 großes abgerundetes Quadrat innerhalb der 1024er
Fläche; der Rand ist Platz für den Schatten des Icons.

| Scheibe | x | Breite | y | Höhe | Reihenfolge |
|---|---|---|---|---|---|
| links (Backlog) | 14 | 48 | 43 | 74 | zuerst |
| rechts (Erledigt) | 98 | 48 | 43 | 74 | dann |
| Mitte (In Arbeit) | 51 | 58 | 34 | 92 | zuletzt, vorne |

Eckenradius 11, durchgehend `.continuous` — die gleiche Squircle-Familie, die
`Board.columnShape` verwendet. Ein kreisrunder Radius wäre genau das „fast
nativ", vor dem `DesignSystem.swift` warnt.

Die mittlere Scheibe ist oben und unten höher als die beiden hinteren. Dieser
Überstand ist wichtig: dort steht sie frei vor dem Hintergrund und liest sich
sofort als vorderste Ebene.

## Der zweifarbige Rand — und warum es ohne ihn nicht funktioniert

Gilt für die **gemalte** Fassung. Im ausgelieferten `.icon` zeichnet macOS die
Kanten selbst; die Erkenntnis unten ist trotzdem der Grund, warum die
Komposition mit Überlappung überhaupt trägt.

Jede Scheibe trägt einen **umlaufenden** Rand aus zwei Lagen:

1. eine dunkle Kontaktlinie, oben transparent, nach unten zunehmend
2. darüber eine helle Glanzlinie, oben kräftig, nach unten auslaufend

Das entspricht dem, was Glas tatsächlich tut: oben tritt Licht ein (heller
Spiegel), unten aus (dunkle Brechungslinie). Zwei frühere Fassungen sind genau
hier gescheitert:

- **Nur eine Glanzkante oben.** Dann fehlt an den Überlappungen jede Kante,
  und die drei Scheiben verschmelzen zu einer Silhouette — das Icon las sich
  als Lichtschalter.
- **Nur die helle Lage.** Funktioniert im Dunkelmodus, weil Weiß auf dunklem
  Glas hohen Kontrast hat, verschwindet im Hellmodus aber vollständig: dort
  liegt Weiß auf ohnehin hellem Glas. Erst die dunkle Lage gibt der hellen
  Variante überhaupt eine Kante — und damit lesen beide Erscheinungen gleich
  stark als Glas.

## Farben — die GUI führt

Das Icon ist **vollständig neutral**, ohne jeden Farbton. Das ist keine
Geschmacksentscheidung, sondern eine Messung: das Fenstermaterial der App
(`.hudWindow`, siehe `HUDGlassMaterial.swift`) liefert über jedem Untergrund
exakt R=G=B — über Weiß `#F4F4F4`, über Mittelgrau `#BBBBBB`, über Schwarz
`#878787`, im Dunkelmodus entsprechend. Dazu sind Karten reines Weiß bzw.
Grau 25 %, und die Spalten sind nur ein schwarzer Wash. Nichts in der App trägt
einen Farbstich.

Eine frühere Fassung des Icons war graublau getönt und stand damit neben dem
eigenen Fenster. Der Helligkeitsmittelwert des Hintergrundverlaufs liegt jetzt
auf dem Glaston, den das Fenster über einem neutralen Schreibtisch zeigt.

Keine Akzentfarbe: die App beansprucht keine eigene Markenfarbe, und Teal ist
in `Board.wipLimitTint` als Kapazitätssignal belegt.

| Element | Hell | Dunkel |
|---|---|---|
| Hintergrund (Verlauf diagonal) | `#DADADA` → `#969696` | `#434343` → `#121212` |
| Ablagescheiben, Füllung (oben → unten) | Weiß 26 % → 6 % | Weiß 12 % → 5 % |
| Fokusscheibe, Füllung | Weiß 58 % → 28 % | Weiß 34 % → 16 % |
| Glanzrand Ablage | Weiß 100 % → 16 % | Weiß 65 % → 18 % |
| Glanzrand Fokus | Weiß 100 % → 24 % | Weiß 100 % → 30 % |
| Kontaktrand Ablage / Fokus | Schwarz 26 % / 34 % | Schwarz 35 % / 45 % |
| Schatten Fokusscheibe | Schwarz 42 % | Schwarz 70 % |
| Schatten des Icons | Schwarz 25 % | Schwarz 30 % |

Der Hintergrundverlauf spannt bewusst weiter, als es auf den ersten Blick nötig
wirkt: durchscheinende Scheiben lesen sich nur dann als durchscheinend, wenn
dahinter etwas zu sehen ist.

Die dunkle Palette ist **nicht** aus der hellen abgeleitet, sondern gegen sie
abgestimmt: dieselben Deckkräfte wirken auf dunklem Grund deutlich schwächer,
also wurde jeder Wert so lange angehoben, bis beide Erscheinungen
nebeneinander gleich stark als Glas lesen.

Unterhalb von 32 px entfällt der äußere Schatten des Icons — er würde nur
Pixel fressen, die die Silhouette braucht. Ränder und Scheibenschatten bleiben,
weil gerade sie bei kleiner Größe die drei Flächen trennen.

## Bewusst verworfen

- **Einzelne Karten oder ein Ticket als Motiv.** Sagt bei kleiner Größe
  „Dokument", nicht „Kanban", und kollidiert optisch mit Erinnerungen/Notizen.
- **Unterschiedlich hohe Säulen (aufsteigend).** Liest sich als
  Balkendiagramm und stellt ausgerechnet „Erledigt" heraus.
- **Scheiben mit Fugen statt Überlappung.** War die Zwischenlösung, nachdem
  die erste Überlappung verschmolz. Klar lesbar, aber ohne Tiefe — die
  Liquid-Glass-Wirkung entsteht erst durch die Schichtung.
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

- `fill`: der Plattenverlauf als `linear-gradient` (die Hell-Werte aus der
  Tabelle oben)
- Gruppe „Storage": `storage-panes.png`, Ebenenfarbe Grau 40 %,
  Durchsicht 0,25
- Gruppe „Focus": `focus-pane.png`, deckend weiß, tieferer Schatten

Zwei Gruppen, weil Icon Composer Schatten **und** Durchsicht pro Gruppe
vergibt und nicht pro Ebene — und die beiden Rollen brauchen von beidem
unterschiedlich viel.

**Die Ebenen sind flache Silhouetten, keine Bilder.** macOS leitet Glas,
Glanzkante und Schatten selbst daraus ab. Hätte man die gemalte Fassung
übergeben, lägen zwei Glasbehandlungen übereinander.

**Nicht alles ist Glas.** Eine Zwischenfassung hatte die Durchsicht auf beiden
Gruppen — damit wurde das ganze Icon durchscheinend, was für ein macOS-Icon
unüblich ist und der Doktrin der App widerspricht: `DesignSystem.swift` gibt
Glas dem Rahmen und lässt Inhalt deckend. Die vordere Scheibe ist deshalb
Papier wie eine Karte, die beiden dahinter sind die vertieften Bahnen.

**Die Bahnen sind dunkler eingefärbt.** Blieben sie weiß wie die Vorderscheibe,
verschmolzen alle drei bis 32 pt zu einem Klotz — die Glanzkanten und der
Schatten, die sie bei voller Größe trennen, sind dort längst weg. Das Board
macht dasselbe (`Board.columnFill` ist ein schwarzer Wash), nur schwächer;
das Icon muss Größen überstehen, in denen das Board nie gezeichnet wird.

Damit fällt die Hand-Arbeit an Rändern und Füllungen für das ausgelieferte
Icon weg — sie bleibt im Generator als Referenz und als Notfall-Fallback
(`AppIcon.appiconset`), ist aber **nicht** das, was gebaut wird.

### Hell, Dunkel und Getönt

Der kompilierte Katalog enthält drei getrennte Ebenenstapel — je einen für
`NSAppearanceNameAqua`, `NSAppearanceNameDarkAqua` und `ISAppearanceTintable`
— auch dann, wenn das Manifest nichts über sie sagt. **Eine Dunkelvariante ist
also vorhanden; macOS leitet sie ab.** Dazu kommen sieben flach gerenderte
Größen unter `NSAppearanceNameSystem`.

Das ist bewusst so gelassen und nicht überschrieben. Der Sinn von Liquid Glass
ist, dass alle Icons dieselbe, vom System abgestimmte Ableitung durchlaufen;
eine neutrale Platte mit neutralen Silhouetten ist genau die Eingabe, für die
diese Ableitung gedacht ist. Ein eigener Dunkel-Entwurf würde das Icon weniger
nativ machen, nicht mehr.

**Grenze der Prüfbarkeit.** Wie die Dunkelvariante aussieht, lässt sich mit den
vorhandenen Werkzeugen nicht offscreen zeigen: die Stapel sind
`_CUILayerStackRendition`, die nur der System-Compositor flachrechnet, und
`assetutil` kann Renditions ohnehin nur auflisten. Ein Umschalten unter
Systemeinstellungen → Erscheinungsbild ist die verbleibende Prüfung.

Was dagegen belegt ist: Ebenenfarben schlagen durch. Zwei Kontrollbauten mit
grauem und rotem Ebenen-`fill` ergaben, aus dem Katalog extrahiert, Scheiben in
RGB 174/174/175 beziehungsweise 246/49/46. Falls die Dunkelvariante je bewusst
gestaltet werden soll, ist `fill-specializations` auf **Ebenen**-Ebene der Weg
(so macht es auch das einzige `.icon`-Beispiel, das sich auf dem System finden
ließ) — die Wirkung wäre dann aber nur durch Umschalten der Erscheinung zu
kontrollieren.

Eine frühere Fassung dieses Dokuments behauptete, ein Override auf oberster
Ebene werde nachweislich ignoriert. Das war ein Fehlschluss: gemessen wurde die
`SizeOnDisk` des Ebenenstapels, und die ist eine Beschreibungsgröße, die sich
mit Farben gar nicht ändert. Ob der Schlüssel dort wirkt, ist schlicht ungeklärt.

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
