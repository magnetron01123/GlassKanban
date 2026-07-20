# App-Icon — Konzept: „Vier Glasspalten, ein Board"

Status: umgesetzt. Ausgeliefert wird `GlassKanban/AppIcon.icon`, ein
Icon-Composer-Dokument mit **zwei fertig gemalten Ebenenbildern** — eines hell,
eines dunkel. Glas, Glanzkanten und Schatten sind gezeichnet, nicht vom System
gerechnet; das `.icon` dient hier nur dazu, je nach System-Erscheinung das
richtige Bild zu zeigen. Wie das geht und warum kein klassischer Katalog:
siehe „Hell und Dunkel" unten.

## Leitidee

Das Icon zeigt das **Board**, nicht ein Ticket: vier gleich große Glasspalten
auf einer weißen Platte, leicht überlappend — die vier Bahnen des Boards
(Backlog, Als Nächstes, In Bearbeitung, Erledigt).

Kein Motiv aus einzelnen Karten, kein Symbol, keine Schrift — bei 16 pt in der
Menüleiste überlebt genau eine Aussage, und die soll „Board" sein.

**Alle vier Spalten sind gleich** — gleiche Farbe, Durchsicht, Kante und
Schatten. Sie sind vier Bahnen eines Boards; unterschiedliche Größen oder
Farben machen daraus verschiedene Arten von Objekt und die Board-Lesart ist
weg (siehe „Bewusst verworfen"). Die Tiefe entsteht allein aus den
Überlappungen: zwei durchscheinende Glaslagen übereinander werden dunkler.
Das ist, was Glas tut, und macht den Effekt schon bei normaler Icon-Größe
sichtbar — nicht erst in der 1024er-Vorschau.

## Wiedererkennung zwischen Icon und App

Vier Dinge tragen sie:

1. **Formensprache** — dieselben `.continuous`-Squircles und Radienfamilie wie
   `Board.columnShape`.
2. **Komposition** — die vier Bahnen des Boards, nebeneinander.
3. **Material** — Glas mit Spiegelung, das Material des Fensters.
4. **Verhältnis** — helle Platte, dunklere Bahnen: genau wie im Board, wo das
   Fenster hell ist und die Bahnen es verdunkeln.

**Verworfen:** eine weiße Karte in einer Spalte, als direktes Zitat der
Board-Karten. Sie verschmilzt mit der Glasspalte zu einem hellen Fleck und
macht das Motiv unklarer statt klarer.

## Geometrie

Entworfen auf einem **160 × 160**-Raster, beim Rendern skaliert. macOS zeichnet
App-Icons als 824 × 824 großes abgerundetes Quadrat innerhalb der 1024er
Fläche; der Rand ist Platz für den Schatten des Icons.

Vier Spalten, Breite 30, Höhe 88, ab y = 36, zentriert. Jede beginnt
`Breite − Überlappung` weiter rechts als die vorige.

Überlappung 8, Eckenradius 9, durchgehend `.continuous` — die gleiche
Squircle-Familie, die `Board.columnShape` verwendet. Ein kreisrunder Radius
wäre genau das „fast nativ", vor dem `DesignSystem.swift` warnt.

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
- **Getöntes Teal.** Hübsch und im Dock unterscheidbar, kollidiert aber mit
  der reservierten Bedeutung von Teal im Code.
- **Warmes Sandgrau.** Hätte die Papier-Metapher aufgegriffen und wäre im
  Dock am unterscheidbarsten gewesen, liest sich aber weniger als „Glas".
- **Kühles Graublau.** War zwischenzeitlich gesetzt und gab dem Icon im Dock
  mehr Eigenständigkeit — passte aber nicht zum eigenen Fenster, das
  nachweislich neutral ist. Im Zweifel führt die GUI.

## Hell und Dunkel

Das Icon zeigt in hellem System die helle, in dunklem die dunkle Fassung. Der
Weg dahin war der Kern der Sache, weil **zwei naheliegende Ansätze nicht
funktionieren:**

1. **Klassischer Katalog mit Dunkel-Eintrag.** Ein `AppIcon.appiconset` mit
   `"appearances": [{"appearance": "luminosity", "value": "dark"}]` kompiliert
   ohne Fehler *und ohne Wirkung*: `actool` verwirft die Dunkel-Einträge
   stillschweigend, im Ergebnis steht keine einzige Erscheinungs-Kennung.
   macOS-App-Icon-Kataloge tragen schlicht keine Hell/Dunkel-Variante.
2. **`.icon` das Glas selbst rechnen lassen.** Dann leitet macOS zwar eine
   Dunkelfassung ab, aber es rendert das Glas neu und das Ergebnis wich vom
   abgestimmten Entwurf ab.

**Der Ansatz, der beides löst:** ein `.icon` mit *einer* Ebene, deren Bild die
komplette, fertig gemalte Grafik ist — vollflächig, einmal hell, einmal dunkel,
verknüpft über `image-name-specializations` (`appearance: dark`). Im Manifest
ist Glas ausgeschaltet (`specular: false`, `translucency: enabled: false`,
`glass-specializations: [{ value: false }]`, Schatten 0). Damit **rechnet macOS
nichts neu** — es maskiert das Vollbild zur Squircle-Form und setzt es
unverändert ein — und schaltet allein das Bild um. Der äußere Schatten des
Icons kommt vom System, deshalb sind die gemalten Bilder ohne eigenen
Außenschatten und vollflächig (die Platte füllt die ganze 1024er Fläche, nicht
nur die 824er Kunstfläche).

**Belegt** ist die Umschaltung nicht am Aussehen (das ließ sich offscreen nie
zuverlässig rendern — `NSImageView` mit gesetzter `NSAppearance` liefert für
appearance-spezifische Named Images irreführende Ergebnisse, ein früherer
Fehlschluss). Sondern an den Verweisen: der kompilierte Katalog enthält je
einen Ebenenstapel für Aqua, DarkAqua und Tintable, und der **Dunkel-Stapel
verweist auf ein anderes Bild-Rendition** (Identifier 59377) als der Hell-Stapel
(63909) — ausgelesen über CoreUI (`CUIRenditionLayerReference.referenceKey`).
Zwei verschiedene Bilder, also greift die Spezialisierung.

Sichtbar prüfen lässt es sich nur am Dock nach Umschalten von
Systemeinstellungen → Erscheinungsbild; die App-eigene Einstellung „Erscheinung"
reicht nicht, weil das Dock jedes Symbol im **System**-Erscheinungsbild zeichnet.

## Erzeugung

    swift scripts/render-app-icon.swift <zielordner>

Schreibt `AppIcon.icon` (nach `GlassKanban/` kopieren — das ist der
ausgelieferte Stand) mit den beiden Vollbildern `icon-light.png` /
`icon-dark.png`, dazu einen `AppIcon.appiconset` (nur hell, als Referenz), die
Einzelebenen und Vorschauen. Nach jeder Änderung an den Konstanten im Skript
neu laufen lassen.

XcodeGen braucht dafür keine Sonderregel: es erkennt `.icon` als
`wrapper.icon` und legt es als eine Einheit in die Resources-Phase.

Prüfen, ohne das ganze Projekt zu bauen:

    xcrun actool --app-icon AppIcon --compile <out> --platform macosx \
      --minimum-deployment-target 26.0 \
      --output-partial-info-plist <out>/p.plist <pfad>/AppIcon.icon

Wichtig: Der Bundle-Name muss `AppIcon.icon` lauten, sonst findet `actool` das
Asset nicht und erzeugt stillschweigend nur die Plist statt eines Icons.
