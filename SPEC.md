# Glass Kanban — Funktionsspezifikation

Diese Datei beschreibt, **was die App heute tut**. Sie wird mit der App
weiterentwickelt: Ändert sich Verhalten, ändert sich diese Datei mit.

- Warum es so ist (Herleitung, verworfene Alternativen): [CONCEPT.md](CONCEPT.md)
- Was bewusst *nicht* umgesetzt ist: [BACKLOG.md](BACKLOG.md)

> **Warum hier trotzdem Begründungen stehen:** Bei Regeln, die schon einmal versehentlich
> zurückgedreht wurden oder deren Sinn sich nicht aus dem Verhalten ergibt (Animationskurven,
> Kartenhöhen, gleich hohe Statistik-Register), steht die Kurzbegründung samt der bereits
> verworfenen Alternativen **direkt an der Regel** — dort, wo der nächste Eingriff passiert,
> und nicht drei Dateien entfernt. Das ist Absicht, keine Vermischung mit CONCEPT.md: Dort
> liegt die ausführliche Herleitung der *Haltung*, hier die knappe Warnung am *Verhalten*.

> **Historie:** Diese Datei hieß bis Juli 2026 `MVP.md` und war die verbindliche
> Vorab-Spezifikation für die Erstumsetzung. Der MVP ist erreicht und die App inzwischen
> darüber hinausgewachsen — eine Datei, die einen abgeschlossenen Planungsstand festhält,
> während die App weiterläuft, wird zur Fehlerquelle statt zur Referenz. Sie beschreibt
> deshalb ab jetzt den Ist-Stand; der ursprüngliche MVP-Umfang steht in der Git-History.

## App

- **Name:** Glass Kanban
- **Plattform:** natives SwiftUI, macOS 26 (Tahoe)+
- **Sprachen:** Englisch (Quellsprache im Code, String Catalog) und Deutsch (vollwertige
  Lokalisierung, `Localizable.xcstrings`/`InfoPlist.xcstrings`) — Englisch ist die
  Fallback-Sprache für jeden Markt ohne eigene Übersetzung
- **Grundprinzipien:** Personal-Kanban-Philosophie (Arbeit sichtbar machen, Workflow nicht
  stören) + komplett lokal (keine Cloud-Komponente, kein Server, kein Konto, keine
  Zugangsdaten in der App — einzige Berechtigung ist der macOS-Systemdialog für
  Erinnerungs-Zugriff)

## Architektur

- Datenzugriff ausschließlich über EventKit (`EKEventStore`/`EKReminder`), kein eigener
  Datenspeicher
- Bidirektionaler Sync über `EKEventStoreChangedNotification`, kein Polling; zusätzlich
  Refresh um Mitternacht und nach dem Aufwachen aus dem Ruhezustand, damit „Heute"/
  „Überfällig" auf einem tagelang offenen Fenster nicht veralten
- Wird der Erinnerungs-Zugriff nachträglich in den Systemeinstellungen erteilt, übernimmt
  die App das beim nächsten Aktivieren des Fensters — ohne Neustart
- **Wird er entzogen, sagt das Listen-Register das auch dann, wenn noch Listen im Speicher
  liegen** (10.08.2026): Es entscheidet am Zugriffszustand, nicht daran, ob die letzte
  erfolgreiche Abfrage noch etwas hinterlassen hat. Vorher bot es weiter Schalter für
  Listen an, die es nicht mehr lesen durfte
- Normales Fenster, kein Always-on-Top
- Login-Item (Start bei Anmeldung) + gespeicherte Fensterposition/-größe
- Native Toolbar (SwiftUI `.toolbar`/`NSToolbar`) statt selbstgebauter Titelleiste
- Volles natives App-Menü + Tastaturkürzel (siehe unten)
- Respektiert macOS-Bedienungshilfen: „Transparenz reduzieren", „Bewegung reduzieren",
  „Kontrast erhöhen"

## Datenmodell

### Spalten = eigener Speicher der App (seit 13.08.2026)

Die Spalte einer Karte steht in einer Datei, die nur diese App kennt:

`<Container>/Library/Application Support/GlassKanban/columns.json`

Ein Eintrag je Erinnerungs-ID, mit Spur und dem Zeitpunkt des Zugs. Gespeichert werden
**nur `next` und `inProgress`**:

| Spalte | Woher sie kommt |
|---|---|
| Backlog | **kein Eintrag** — der Ruhezustand, wie zuvor „kein Tag" |
| Als Nächstes | Eintrag `next` |
| In Bearbeitung | Eintrag `inProgress` |
| Erledigt | `isCompleted = true` in EventKit, wie immer |

Ein Zug nach Backlog **löscht** den Eintrag; das Format kann also gar nicht zwei Dinge
ausdrücken, die dieselbe Spalte meinen. Erledigt wird bewusst nicht lokal geführt: Dort
lesen Reminders, iPhone, Widgets und die eigene Statistik mit, und eine zweite Wahrheit
liefe von der sichtbaren auseinander.

**Warum überhaupt** (Herleitung in CONCEPT.md, „Spalten gehören dem Board"): Solange die
Spalte als Hashtag in den Notizen stand, konnte sie jedes Programm mit Reminders-Zugriff
ändern — gemessen am 12.08.2026, als ein fremder Kalender-Client neun Minuten nach einer
in der App erledigten Wiederholung `#next` auf die weitergerollte Serie zurückschob. Die
App konnte das erkennen und beantworten; verhindern kann es nur ein Speicher, den
niemand sonst erreicht.

**Was das für Schreibvorgänge heißt:** Ein Zug zwischen Backlog, Als Nächstes und In
Bearbeitung fasst EventKit **gar nicht** mehr an. Nur der Übergang nach Erledigt und
zurück schreibt (`isCompleted`), weil das eine Tatsache über die Aufgabe ist und keine
über diese Ansicht. Die App schreibt in Reminders damit nur noch, was der Nutzer im Editor
oder beim Umbenennen selbst angibt: Titel, Notiztext, URL, Fälligkeit, Priorität, Liste,
`isCompleted` — dazu die Alarm-Mitführung beim Verschieben eines Datums, die Felder eines
wiederhergestellten Tickets (beides unten beschrieben) und einmalig die Aufräumung.

| Zug auf einer **schreibgeschützten** Liste | bis 13.08.2026 | seither |
|---|---|---|
| Backlog ↔ Als Nächstes ↔ In Bearbeitung | „Nicht verschoben" | funktioniert, lautlos |
| → Erledigt und zurück | „Nicht verschoben" | weiter „Nicht verschoben" |

Das ist gewollt: Ob die Erinnerung einer anderen Person geändert werden darf, sagt nichts
darüber, wie dieses Board seine eigene Ansicht sortiert. Die Asymmetrie bleibt erklärbar —
Erledigen ist eine Aussage über die Aufgabe, Ziehen eine über das Brett.

**Identität ist `calendarItemIdentifier`.** Gemessen am 13.08.2026 (iCloud-Scratch-Listen):
Sie überlebt einen Listenwechsel, das Umbenennen von Aufgabe und Liste sowie einen kalten
EventKit-Cache; drei drei Tage alte gespeicherte IDs lösten weiterhin auf, darunter eine
seither weitergerollte Serie. Bricht sie doch, verwaist der Eintrag und die Karte steht im
Backlog — ein Zug. Zwei Brüche werden aktiv behandelt: Das Rückgängigmachen eines Löschens
legt einen **neuen** Datensatz an (die Spur reist im Snapshot mit), und ein Listenwechsel
im Editor schreibt den Eintrag auf die neue ID um.

**Verweildauer:** Der Zeitpunkt des Zugs steht im Eintrag, die Anzeige ist damit exakt
statt genähert. Für Karten, die dieses Board nie bewegt hat, gilt weiterhin die alte
Näherung über `lastModifiedDate`.

**Wenn die Datei fehlt oder unlesbar ist:** leerer Speicher, alle Karten im Backlog — die
sichere Richtung, wiederhergestellt mit je einem Zug. Gelesen wird **eintragsweise
tolerant**: Ein defekter Eintrag kostet diesen einen, nicht die Datei; nur eine unbekannte
Formatversion oder ein kaputter Rumpf verwerfen alles. Geschrieben wird atomar. Scheitert
ein Schreibvorgang, bleibt der Zug in der Sitzung wirksam, es erscheint **kein Dialog**
(eine Zeile in der Konsole), und der nächste Zug versucht es erneut; nach einem Neustart
stünde die Karte im Backlog. Grenze: höchstens 200 Einträge, ältester Zug zuerst — kein
Verfall nach Alter, denn eine Karte darf monatelang in einer Arbeitsspalte stehen.

**Der Speicher ist an diesen Mac gebunden.** Zwei Macs mit dieser App auf denselben Listen
haben getrennte Spalten; die spätere iOS-App bräuchte eine eigene Synchronisation. Das ist
der bewusst bezahlte Preis dafür, dass niemand sonst die Spalte erreichen kann.

### Einmalige Migration der alten Hashtags

Bis 13.08.2026 stand die Spalte als `#next`/`#inprogress` (und in älteren Builds
`#alsnächstes`/`#inbearbeitung`/`#nächstes`/`#bearbeitung`/`#progress`) in den Notizen.
Die Übernahme läuft in zwei Schritten, deren Reihenfolge zwingend ist:

1. **Lesen, je Liste genau einmal.** Beim ersten Auftauchen einer Liste werden ihre Tags
   in den Speicher übernommen und die Liste als übernommen gestempelt. Der Stempel gilt
   **pro Liste**, nicht pro Installation: Ein einzelner Schalter wäre nach dem ersten
   Refresh gesetzt, und der sieht eine in den Einstellungen abgewählte Liste oder ein
   später synchronisierendes Konto nicht — deren Tags wären dauerhaft verloren. Stempel
   und Spalten stehen in derselben Datei und werden in einem Zug geschrieben, können also
   nicht auseinanderlaufen.
2. **Entfernen.** Danach schneidet die App den Tag aus den Notizen — getaktet im
   bestehenden Korrekturlauf, nur auf beschreibbaren Listen, jede Entfernung im
   Korrektur-Ledger gebucht. Geschnitten wird **ausschließlich in den Datensätzen, die
   Schritt 1 beim Lesen namentlich vermerkt hat**; jeder erledigte Datensatz zählt dabei
   mit. Ein Datensatz verlässt diese Liste, sobald sein Schnitt gespeichert ist, ein
   abgebrochener Lauf setzt beim nächsten Refresh fort, und eine leere Liste heißt: Die
   Migration ist vorbei und es wird nie wieder eine Notiz beschnitten.

   **Warum namentlich und nicht „wo ein Tag steht" (gemessen 14.08.2026 in der laufenden
   App):** Die erste Fassung entschied am Vorhandensein eines Tags — und löschte damit
   ein Wort, das der Nutzer gerade selbst geschrieben hatte. „Notiz mit #inprogress
   darin" in den Editor getippt, Editor geschlossen, übrig blieb „Notiz mit darin". Ein
   Tag aus der alten Form und ein frisch getipptes Wort sehen im Text identisch aus; nur
   der Zeitpunkt unterscheidet sie, und den kennt allein der Import. Genau deshalb ist
   die Liste Teil derselben Datei wie die Spalten — sie ist die einzige Stelle, an der
   „alt" definiert ist.

Gelesen wird ein Tag weiterhin **nur wo er allein steht** — links und rechts Leerraum oder
Textgrenze. `#inprogressreport` zählt nicht, ebenso wenig ein Treffer mitten in anderem
Text (`https://example.com/guide#next`, `#next-steps`, `#bearbeitung/2024`, `ABC#NEXT!`).
Stehen mehrere im Text, gewinnt der zuletzt stehende. Die Regel scheitert bewusst nach
innen: `#next.` mit Satzpunkt gilt nicht als Tag, die Karte bleibt im Backlog, der Text
bleibt unangetastet. **Diese Grenzregel ist die letzte sicherheitskritische Stelle der
App** — sie ist der einzige verbliebene Ort, an dem Text aus fremden Notizen geschnitten
wird, und sie hat im Juli 2026 schon einmal echten Nutzertext zerstört. Sie verschwindet
erst mit der Aufräumung selbst, frühestens eine Version nach 1.0.

**Auf schreibgeschützten Listen bleibt der Tag als Text stehen** und wird ab jetzt auch
angezeigt — er gehört der Person, der die Liste gehört. Die App versteckt keine Wörter
mehr, die sie nicht selbst geschrieben hat.

Geprüft am echten Board (13.08.2026): Die Karte, deren Notiz Prosa **und** Tag enthielt,
behielt ihre Prosa zeichengenau und verlor nur den Tag; die Karte, deren Notiz nur aus dem
Tag bestand, hat danach gar keine Notiz mehr; beide blieben in ihrer Spalte.

### Wenn andere Programme dieselben Erinnerungen schreiben

Das Board ist einer von mehreren Schreibern. Erinnerungen synchronisieren über iCloud, in
geteilten Listen sitzt eine zweite Person, und andere Software — Kalender-Clients,
Automatisierungs-Brücken, Kurzbefehle — schreibt in dieselben Datensätze. Eine App, die
nur als alleiniger Schreiber funktioniert, wäre für dieses System kein Produkt.

Am 10.08.2026 gemessen: Ein Kalender-Client mit eigener Datenbank schob alle 19 bis 55
Minuten eine veraltete Kopie von Datensätzen zurück. Sechs Datensätze in dreißig Stunden,
nur einer davon wiederkehrend — die übrigen fielen bloß deshalb nicht auf, weil ein
zurückgeschriebener Tag auf einer *erledigten* Erinnerung nichts Sichtbares ändert.

**Verbindliche Regel (`CorrectionLedger`):**

> Das Board merkt sich, welche Werte es selbst überschrieben hat — je Feld eine **Kette**
> der zuletzt verdrängten Werte, nicht nur den letzten (seit 13.08.2026, höchstens acht).
> Steht in einem Feld später wieder buchstabengenau *einer* dieser verdrängten Werte,
> schreibt das Board seinen jüngsten Wert zurück — höchstens 24 Stunden lang, und **nie
> einen Wert, den der Nutzer nicht selbst an diesem Board eingegeben hat**.

**Warum eine Kette (gemessen 12.–13.08.2026):** Das Board schreibt ein Feld mehrfach um —
ein Zug bucht eine Verdrängung, die Tag-Hygiene eine zweite, ein Edit eine dritte —,
während der fremde Schreiber irgendeine ältere Kopie zurückschiebt. Mit nur einem
gemerkten Wert las sich genau diese Kopie als „dritter Zustand", der Eintrag zog sich
zurück, und die Verteidigung löste sich in dem Moment auf, in dem sie gebraucht wurde.
Die Kette erweitert nur, was als Echo *erkannt* wird — zurückgeschrieben wird weiterhin
ausschließlich der jüngste eigene Wert, unter denselben Richtungsregeln. Ein Wert, der in
keiner Kette steht, bleibt ein dritter Zustand und zieht den Eintrag zurück wie bisher.

**Die Regel fragt nie, *wer* geschrieben hat** — sie kann es nicht, EventKit gibt keine
Herkunft heraus, und sie soll es auch nicht. Erkannt wird ein *Muster* (ein verdrängter
Wert kehrt buchstabengenau zurück), nicht ein Programm. Damit gilt sie unverändert für
jeden zweiten Schreiber: einen Kalender-Client, die Erinnerungen-App, ein iPhone über
iCloud, eine zweite Person in einer geteilten Liste, einen Kurzbefehl, einen zweiten Mac
mit derselben App. Es gibt keine Liste bekannter Störer und soll keine geben.

**Die eine Voraussetzung, die der fremde Schreiber erfüllen muss:** Er ändert Datensätze,
statt sie zu löschen und neu anzulegen. Bleibt die Identität stabil, greift die Regel
(gemessen über vier Vorfälle, 10.08.2026). Legt ein Programm stattdessen neue Datensätze
an, ist der Bezug zum verdrängten Wert weg — dann sieht das Board eine neue Karte und hat
nichts zu verteidigen. Das ist die Grenze der Regel und keine Eigenschaft eines bestimmten
Programms.

**Wie schnell geantwortet wird, hängt vom Feld ab** (10.08.2026 am laufenden Board
gemessen, nicht abgeleitet):

| Feld | Takt |
|---|---|
| Notizen, Titel, URL, Fälligkeit | höchstens eine Antwort pro zehn Minuten je Karte und Feld |

Ein Takt für alle vier Felder, seit dem Formwechsel vom 13.08.2026. Vorher hatten die
Notizen einen schnelleren, weil dort die Spalte lag und jeder verschwundene Arbeits-Tag
bei jedem Refresh neu als Verdrängung gebucht wurde — beides ist entfallen: Die Spalte
liegt im eigenen Speicher, wo kein fremder Schreiber sie erreicht, und was der Ledger
heute verteidigt, sind vier gewöhnliche Textfelder. Das Board schreibt nie von sich aus
öfter als der fremde Schreiber; ohne Gegenschreiben ruht es nachweislich (gemessen: kein
einziger Schreibvorgang nach der Antwort). Was fehlt, ist eine Obergrenze für ein
Programm, das im Sekundentakt schreibt — bewusst offen, siehe BACKLOG.md.

Der letzte Halbsatz trägt die ganze Sicherheit: Jeder Wert, den dieser Mechanismus je
automatisch schreibt, hat der Nutzer hier eingegeben; nie ein erfundener, nie ein
abgeleiteter, nie ein vom fremden Schreiber übernommener. Bloß *beobachtete* Übergänge zu
verteidigen wurde entworfen und verworfen — ein Programm, das häufiger schreibt als der
Nutzer, bekäme so seine alten Werte adoptiert und anschließend mit der Autorität des
Boards durchgesetzt (Herleitung in CONCEPT.md).

**Geschützte Felder und ihre Richtung:**

| Feld | Richtung | Warum begrenzt |
|---|---|---|
| Notizen | beide Richtungen (seit 13.08.2026) | Solange die Spalte in den Notizen stand, konnte ein Restore eine Karte in eine Arbeitsspalte heben; die Notiz ist jetzt reiner Nutzertext, und eine halbe Verteidigung wäre nur noch halb |
| Titel | beide Richtungen | Viele mögliche Werte, ein buchstabengenauer Treffer ist echte Evidenz |
| URL | beide Richtungen, verglichen in geparster Form | sonst liest die Prozentkodierung sich selbst als Dauerecho |
| Fälligkeit | **nur ein verschwundenes** Datum kommt zurück, nie ein verschobenes, nie bei Wiederholungen | ein verschobenes Datum zurückzudrehen hieße, eine gerade gesetzte Frist zu löschen; Serien bewegt EventKit selbst |

**Bewusst nicht geschützt:** Priorität (vier Werte — Byte-Gleichheit ist kein Beweis),
Erledigt-Status (zwei Werte, kein Unterscheidungsmerkmal, und einen Abschluss wegzunehmen
ist der teuerste Fehlalarm dieser Liste), Listenzugehörigkeit, Wiederholungsregel, Alarme
(einziges Feld, dessen Wiederherstellung hörbar wäre), Startdatum und Ort. Unterhalb der
öffentlichen EventKit-API liegen Unteraufgaben, Anhänge und Reminders-eigene Tags — die
sind in beide Richtungen unsichtbar. „Ganze Karte" heißt also: die ganze Karte, wie
EventKit sie beschreibt.

**Gebucht wird nur, was das Board selbst schreibt** — der Editor, das Umbenennen, eine
eigene Korrektur. Bis 13.08.2026 gab es einen Zusatz (ein irgendwo verschwundener
Arbeits-Tag zählte auch als Verdrängung); er ist mit dem Tag entfallen. Ein Zug bucht
seither gar nichts mehr, weil er kein Feld der Erinnerung anfasst.

**Ein Durchgang, ein Speichern je Karte**, in dieser Reihenfolge: beobachten (ein dritter
Zustand zieht den Eintrag zurück — wer seine Meinung ändert, wird nie bekämpft) →
Echo beantworten → einmalige Tag-Aufräumung der Migration → speichern. Die Freigabe eines
verbrauchten Pulls gehört nicht mehr dazu: Sie läuft vor diesem Durchgang und schreibt nur
in den eigenen Speicher. Grenzen: höchstens fünf **Echo-Antworten** je Sync (die
Aufräumung der Migration ist davon nicht betroffen — sie soll zügig fertig werden), je
Karte und Feld eine Antwort pro zehn Minuten, Verfall
nach 24 Stunden, höchstens 200 Karten im Gedächtnis. Ein Wecker holt eine
vom Takt aufgeschobene Antwort nach, weil ein Zustand, der bloß falsch *bleibt*, keinen
Sync auslöst. Schreibgeschützte Listen werden übersprungen.

**Der Nutzer erfährt davon nichts** — kein Hinweis, kein Dialog, kein Badge
(Nutzerentscheidung 10.08.2026). Nachvollziehbar ist es nur über die Konsole
(`subsystem: com.davidtrogemann.GlassKanban`, `category: corrections`).

**Restschaden, offen benannt:** Stellt jemand auf einem anderen Gerät ein Feld
buchstabengenau auf den Wert zurück, den das Board dort binnen 24 Stunden verdrängt hat,
ist das von einem Rückschieber nicht zu unterscheiden und wird überschrieben. Ein
*anderer* Wert — der häufigere Fall — zieht den Eintrag dagegen sofort und endgültig
zurück.

### Ehrliche Zustände und Belohnungen (10.08.2026, aus dem Nutzer-Review)

- **Vor der ersten Antwort sagt das Board nichts.** Bisher blitzte bei jedem Start
  „Nichts zu tun" auf, auf großen oder frisch synchronisierenden Datenbanken sekundenlang.
- **„Keine Erinnerungslisten" ist ein eigener Fall.** Gibt es auf dem Mac überhaupt keine
  Liste, führte der Weg bisher in ein Einstellungs-Register, das die schlechte Nachricht
  nur wiederholen konnte; jetzt führt er in die Erinnerungen-App, wo eine Liste entsteht.
- **Leere Spalten laden nicht ein, während gefiltert wird.** „Fertigwerden beginnt hier"
  über einer Spalte, die drei Karten hält, ist eine falsche Aussage über das Board.
- **Die Wochenzahl erscheint erst nach einer Woche.** Acht Aufgaben am ersten Tag wurden
  zu „56 pro Woche", zwei Zeilen unter „8 Aufgaben dieses Jahr" und neben einem Diagramm
  mit 29 leeren Tagen. Der Tipp nennt jetzt den tatsächlich beobachteten Zeitraum.
- **„Deine längste Folge bisher" steht nur, wenn es etwas heißt** — ab drei Tagen und
  während der Rekord entsteht, nicht ab der allerersten Aufgabe und nicht wochenlang.
  Aufmerksamkeit gehört Ereignissen, nicht Dauerzuständen.
- **Die Flamme nickt nur bei einer Erledigung** — nicht beim Rückgängigmachen und nicht um
  Mitternacht, wenn der Tageszähler auf null springt.
- **„Erst abschließen" ist eine Korrektur, kein Zug:** kein Erledigt-Klang, kein zweiter
  Undo-Schritt. Vorher stellte ⌘Z danach genau die eben abgelehnte Überlastung wieder her.
- **Der WIP-Dialog nennt die Zahl, mit der entschieden wurde** (die ganze Spalte), nicht
  die gefilterte Ansicht. Der Spaltenkopf zeigt weiterhin, was auf dem Schirm ist.
- **Ein neues Ticket landet nur in einer beschreibbaren Liste.** War die Zielliste
  schreibgeschützt, tat das „+" sichtbar nichts — beliebig oft, ohne Meldung.
- **Umbenennen schreibt nur bei echter Änderung.** Ein gespeicherter Titel mit
  Randleerzeichen galt sonst als geändert und setzte die Verweildauer der Karte zurück.
- **Anlegen und erstes Befüllen sind ein Undo-Schritt.**
- **Finden durchsucht die ganze Notiz und das URL-Feld**, nicht nur die drei Zeilen, die
  die Karte zeigt.
- **„Beim Anmelden starten" nimmt sich nicht mehr selbst zurück.** Das Nachziehen des
  Systemzustands galt als Nutzeraktion und meldete den Eintrag ab; im Fehlerfall stand
  eine rohe englische Systemmeldung ohne Ursache. Jetzt: ein eigener Satz und ein Knopf in
  die Anmeldeobjekte.

### Das Sicherheitsnetz (10.08.2026, aus dem Nutzer-Review)

- **⌘Z verliert nie mehr als den einen Schritt.** Eine zurückgenommene Neuanlage („+"
  gedrückt, nichts eingetragen, Escape) wird gar nicht erst auf den Stapel gebucht —
  vorher löschte sie den **gesamten** Undo- und Redo-Verlauf des Fensters, samt einer
  gerade gelöschten Karte, deren Rückfrage ⌘Z ausdrücklich als Rettung genannt hatte. Der
  Eintrag entsteht erst, wenn das Ticket behalten wird.
- **Das Erledigt-Datum überlebt einen Zug.** Wird eine erledigte Karte zurück in eine
  Arbeitsspalte gezogen und der Zug widerrufen, trägt sie wieder ihr **ursprüngliches**
  Datum. Vorher stempelte der Rückweg „jetzt" darauf: Die Karte sprang an die Spitze von
  „Erledigt", zählte erneut für Streak, Wochenschnitt und Durchlaufzeit — und in
  Reminders war der alte Wert verloren.
- **Ein leer abgebrochenes Ticket verschwindet auf jedem Weg**, auch wenn statt des
  Editors das Fenster geschlossen wird (⌘W). Vorher blieb eine titellose Erinnerung
  dauerhaft in der Liste des Nutzers.
- **Verschwindet die offene Karte, schließt der Editor.** Wird sie auf einem anderen Gerät
  gelöscht oder ihre Liste abgewählt, blieb das Board unscharf und die Symbolleiste tot,
  ohne erkennbaren Ausweg.
- **Menübefehle sind gesperrt, wo die Symbolleiste es ist.** ⌘F, ⇧⌘F, ⌘N und ⌘R greifen
  nicht mehr an einer hochgehaltenen Karte oder ohne Erinnerungs-Zugriff vorbei — eine
  Regel, die nur für die Maus galt, ist keine Regel.
- **Der Falz weicht dem Filter.** Ein Suchtreffer hinter dem Falz wurde nie gezeichnet:
  Die Spalte zeigte weder die Karte noch „Keine Treffer", weil gefunden ja etwas wurde.
  Bei aktiver Einschränkung ruht der Schnitt.

### Was das Board gegen sich selbst absichert (10.08.2026)

Aus einem Review der Spaltenlogik entstanden; jeder Punkt hatte ein reproduzierbares
Fehlerbild:

- **Ein Sync, dessen Abfragen älter sind als ein Zug des Nutzers, wird verworfen.** Sonst
  veröffentlichte er den Stand von vor dem Zug: Die Karte sprang sichtbar zurück und einen
  Wimpernschlag später wieder vor — und bei einem neuen Ticket schloss sich der Editor
  mitten im Tippen von selbst.
- **Doppelte Datensätze werden verworfen, der spätere gewinnt.** Offene und erledigte
  Aufgaben werden in zwei getrennten Abfragen geholt; wird eine Karte genau dazwischen
  abgehakt, war sie in beiden und erreichte das Board zweimal unter derselben ID.
- **Das WIP-Limit zählt die ganze Spalte, nicht die gefilterte Ansicht.** Begonnene Arbeit
  ist begonnen, auch wenn ein Filter sie gerade verbirgt; ein Limit, das eine
  Ansichtseinstellung abschaltet, ist keins. Der Spaltenkopf zeigt weiterhin die sichtbare
  Zahl — wo beide auseinandergehen, folgt die Regel dem Board, nicht der Ansicht.
- **Die WIP-Rückfrage erscheint nur bei einem Zug, den der Nutzer gerade macht.** Bei ⌘Z
  fragte sie zu einer Entscheidung, die niemand traf, und „Erst abschließen" legte dabei
  einen neuen Undo-Schritt an — die Karte pendelte zwischen zwei Spalten.
- **Eine gezogene Karte bleibt sichtbar, wo sie landet.** Eine wiederkehrende Karte mit
  künftigem Termin ist im selben Moment „noch nicht fällig", in dem sie im Backlog
  ankommt, und verschwand hinter dem Falz — sichtbar blieb nur eine Zahl in der Falzzeile.
  Die Spalte klappt jetzt auf, genau wie für eine Karte, deren Editor sich schließt.
- **Ein Zug, der ins Leere endet, hinterlässt keinen halben Zustand.** Über der Symbolleiste
  oder außerhalb des Fensters losgelassen, blieb die Karte ausgegraut und alle Tooltips des
  Boards stumm, bis irgendwann ein Zug in einer Spalte endete.
- **Ein fehlgeschlagener Zug lässt den Datensatz unverändert zurück.** EventKit gibt
  zwischengespeicherte Objekte heraus; ein Reminder mit ungespeichertem Tag hätte die Karte
  in der Zielspalte gezeigt, während die Meldung „Nicht verschoben" lautet.
- **Erledigen einer wiederkehrenden Karte parkt sie nicht kurz in „Erledigt".** Die ID
  gehört zu dem Zeitpunkt bereits dem nächsten Durchgang.
- **Nutzertext übersteht auch ungewöhnliche Zeilentrenner.** Notizen aus PDF- oder
  Web-Quellen trennen mit U+2028, ältere mit einem einzelnen `\r`; die galten als *eine*
  Zeile, worauf die Aufräumroutine über den ganzen Text lief und doppelte Leerzeichen in
  Zeilen fraß, die nie ein Tag trugen. Die Trenner selbst bleiben erhalten.
- **Die Kartenanzeige löscht nichts, was nur wie ein Tag aussieht.** `#next-steps` wurde als
  `-steps` angezeigt — und weil dieser Text auch die Suche speist, war die Karte über genau
  ihr eigenes Wort nicht mehr auffindbar.

### Listen-Filter

In den Einstellungen wird gewählt, welche vorhandenen Listen als Quelle einbezogen werden
(z. B. Einkaufsliste ausschließen). Flache Liste aller Listen, keine Gruppierung nach Konto.
Erinnerungen aus gewählten Listen werden gepoolt angezeigt; die Liste selbst wird nie von
der App gewechselt.

## Interaktion

Die App schreibt: die Editor-Felder (Titel, Notizen,
URL, Liste, Priorität, Fälligkeit), neue Tickets und Löschungen. Nicht bearbeitbar in der
App bleiben nur die Felder, die EventKit nicht öffentlich anbietet (Tags, Flags,
Unteraufgaben, Personen) sowie Wiederholungsregeln — dafür gibt es den Sprung nach
Reminders.

| Geste | Wirkung |
|---|---|
| **Drag & Drop** zwischen Spalten | Spaltenwechsel (siehe Datenmodell) |
| **Einfacher Klick** auf eine Karte | öffnet den **Karten-Editor** direkt auf dem Board |
| **Rechtsklick** | Kontextmenü: Bearbeiten, In Erinnerungen öffnen, Verschieben nach, Umbenennen, Löschen |
| **„+" im Backlog** | Neues Ticket anlegen und sofort im Karten-Editor öffnen |

### Karten-Editor (`TicketEditSheet`)

Der Klick öffnet die Karte vergrößert und zentriert über dem abgeblendeten Board — dieselbe
Karte, näher herangeholt, kein separates Formularfenster. Editierbar: **Titel, Notizen
(mehrzeilig, Absätze bleiben erhalten), URL-Feld, Liste, Dringlichkeit, Fälligkeit** (mit
oder ohne Uhrzeit — ohne bleibt die Erinnerung ganztägig). Der
↗-Knopf springt zur Aufgabe in der Reminders-App, für alles, was der Editor bewusst
auslässt. Das Notizen-Feld zeigt die Notiz so, wie sie in Reminders steht — seit
13.08.2026 auch einen Hashtag darin, denn er ist Nutzertext wie jeder andere. Ein
Inhalts-Edit kann eine Karte nicht verschieben; die Spalte liegt außerhalb der Notiz.
Ein Listenwechsel bietet nur beschreibbare, nicht ausgeblendete Listen an.

**„Erfasst" als erste Fakten-Zeile** — Personal Kanbans eigenes Wort für den Akt, den das
„+" ausführt (Bensons Capture-Schritt: Arbeit aus dem Kopf aufs Board holen; „Angelegt"
wäre Dateisystem-Deutsch) — die einzige nicht editierbare Angabe im Editor und
der einzige Ort, an dem das Erstellungsdatum überhaupt erscheint. Sie existiert, weil die
offenen Spalten seit Juli 2026 **nach Alter sortieren**: Die Position einer Karte trägt
damit eine Regel, die das Board sonst nirgends ausspricht, und Kanbans *„make policies
explicit"* verlangt, dass so eine Regel auffindbar ist (dieselbe Begründung wie beim
WIP-Limit im Spaltenzähler). **An der Spitze des Rasters**, weil die Zone ihre Zeilen von
der stabilsten zur flüchtigsten Eigenschaft ordnet — und das Erstellungsdatum ändert sich
nie; ganz oben liegt es zudem maximal weit von „Fälligkeit", sodass die zwei Daten der
Karte nie als gestapeltes Paar gelesen werden können. Der Wert steht als **nackter
Sekundär-Text ohne Bedienelement-Rahmen** — die Stille sagt „Tatsache, kein Regler"; das
Muster ist Finders eigenes Info-Panel („Erstellt: …" zwischen editierbaren Feldern). Eine
Fußnoten-Variante unter dem Raster wurde gebaut und verworfen: Sie führte eine neue Form
ein, wo das vorhandene Raster die Angabe tragen kann. **Auf der Karte selbst erscheint das
Datum nicht** — dort sagen Verweildauer-Chip und Sortier-Position schon alles, und ein
drittes Datum würde die Regel „Kopf = Prozess, Fuß = Aufgaben-Fakten" brechen.

**Die Fakten-Zone ist ein Raster mit zwei Kanten** — Beschriftung links an der Kartenkante,
Bedienelement rechts, und **alle drei Bedienelemente in einer Breite** (180 pt), sodass auch
die linke Kante der Werte eine Linie bildet; „Erfasst" rückt seinen Wert um denselben
Textabstand ein, den ein Rahmen von innen setzt. Vorher trug jede Zeile ihre natürliche
Breite: eine lange für die Listen, ein Stummel für die vier Dringlichkeiten, ein dritter für
das Datum — vier Werte, vier Startpunkte. Das ist die klassische AppKit-Formularausrichtung
(Xcodes Inspektoren), nicht das Zeilenmuster der Systemeinstellungen: Deren ausgefranste
linke Kante trägt eine graue Zeilenfläche mit Trennlinien, die diese Karte bewusst nicht hat.
Die beiden Menüs sind deshalb **echte `NSPopUpButton`** (`FactPopUpButton`): SwiftUIs `Picker`
misst sich am längsten *Menüeintrag* und ignoriert jede angebotene Breite, ein `Menu` mit
eigenem Label verwirft das Label ganz. Lange Listennamen werden abgeschnitten statt das
Element zu dehnen — sonst bestimmt der Listenname das Layout der Karte.

**Der Editor hat keine Sichern-/Abbrechen-Knöpfe — die beiden Antworten liegen auf der
Tastatur, in denselben Worten wie beim Umbenennen: Return übernimmt, Escape verwirft.** Ein
Klick aufs Board zählt als Return (die Notiz wird zurück an die Wand gehängt, mit dem, was
draufsteht). Geschrieben wird erst beim Schließen und nur, wenn sich wirklich etwas geändert
hat — eine Karte nur anzuschauen ist ein Lesevorgang, kein Schreibvorgang, sonst würde jeder
Blick die Verweildauer zurücksetzen. Escape wirft die Änderungen dieser Sitzung weg; das ist
gefahrlos, weil bis dahin nichts geschrieben wurde. Im mehrzeiligen Notizfeld gehört Return
dem Feld (Notizen sind öfter Listen als Sätze) — von dort schließt **⌘Return**.

**Karten tragen keinen Tastaturfokus und keine Hover-Tooltips** — beides war kurz
implementiert und wurde als bewusste Entscheidung wieder entfernt (Begründung in
BACKLOG.md, Abschnitt „Explizit abgelehnt"). Karten werden mit der Maus bewegt; ein
Fokusrahmen betont Karten ohne Not, ein Hover-Text ist Dauerrauschen. VoiceOver ist davon
unberührt: Karten behalten Labels, Hints und alle Aktionen.

**Das URL-Feld benennt, was es nicht behalten kann** (10.08.2026). Steht dort etwas, das
keine Adresse sein kann — eine Adresse enthält kein Leerzeichen, Prosa immer eines —,
erscheint unter dem Feld „Wird nicht gesichert — eine Adresse hat keine Leerzeichen".
Solange getippt wird, nicht als Dialog und ohne etwas zu blockieren: Schließen bleibt
erlaubt, das Feld bearbeitbar. Vorher verschwand der Satz beim nächsten Öffnen
kommentarlos — genau die Fehlerklasse, die dieses Projekt am höchsten gewichtet. Ein
leeres Feld ist kein Einwand: Die Adresse zu löschen ist eine normale Änderung. Feld und
Schreibvorgang teilen sich dieselbe Regel (`TicketURL`), damit sie nicht wieder
auseinanderlaufen können.

**Eine schreibgeschützte Liste sagt es beim Öffnen, nicht beim Schließen** (10.08.2026).
Sitzt die Karte in einer Liste, die dieser Mac nur lesen darf (abonniert, oder ohne
Schreibrecht geteilt), sind alle Felder gesperrt und die Zeile „Liste" trägt den Zusatz
„(nur lesbar)". Vorher nahm der Editor die ganze Eingabe entgegen und erst der
Schließen-Vorgang meldete „Nicht gesichert" — das ganze Tippen verloren für eine Tatsache,
die im Moment des Öffnens feststand. Der ↗-Sprung nach Reminders bleibt offen: Er ist der
Weg, der dort tatsächlich weiterführt.

**Umbenennen** (Kontextmenü, für die schnelle Ein-Zeilen-Korrektur ohne Editor) startet
immer beim *gespeicherten* Titel, nicht bei dem, was die Karte anzeigt (die Karte blendet
URLs aus, siehe unten). Ein unverändert gelassenes oder leer gemachtes Feld schreibt
nichts. Escape verwirft, Return und ein Klick daneben übernehmen.

**Ticket anlegen = Karten-Editor.** Das „+" im Backlog legt das Ticket an (Standardliste
bzw. erste eingeschlossene Liste) und öffnet sofort den Karten-Editor mit dem Cursor im
Titel — Name, Notizen, Datum und alles Weitere entstehen an einem Ort, ohne zweiten
Schritt. **Der Cursor sitzt vom ersten Bild an**, ohne Lücke, in die getippte Zeichen
fallen könnten (10.08.2026 gemessen: ⌘N und sofortiges Tippen von 16 Zeichen — vorher kam
kein einziges an, danach alle). ⌘N ist ein Reflex, dem unmittelbar das Tippen folgt; der
Schutz, der sonst eine versehentliche Taste vom Titel fernhält, ist für eine gerade
angelegte Karte deshalb aus — dort gibt es keinen Text, den eine Taste beschädigen
könnte. **Return legt das Ticket an, Escape bricht die Anlage ab** und entfernt die
Erinnerung wieder, egal was schon in den Feldern stand — abgebrochen ist abgebrochen. Wird
der Editor ohne jede Eingabe geschlossen, entfernt die App das Ticket ebenfalls
rückstandslos; der ↗-Sprung nach Reminders zählt dabei als Behalten.

**Das Auf- und Zuklappen einer Spalte ist die langsamste Bewegung der App.** Es ist die
größte Layout-Änderung, die das Board machen kann — elf oder mehr Zeilen auf einmal — und
lief bis Juli 2026 auf der *schnellsten* Kurve: 0,2 s Ease-out, kürzer als ein einzelner
Kartenwechsel, und jede aufgedeckte Karte spielte zusätzlich ihre Ankunfts-Animation
(Scale-in). Fünfzehn Tickets, die in einer Fünftelsekunde gleichzeitig aufpoppen, lesen
sich als aufgerissene Spalte — viel Lärm für „hier ist, was ohnehin schon da war".

Jetzt: eine Feder ohne jeden Nachschwung über 0,36 s (`Board.foldAnimation`), und die
aufgedeckten Karten blenden nur ein, statt anzukommen. Je größer die Änderung, desto mehr
Zeit braucht das Auge — und es ist nichts *passiert*, also darf nichts schnappen. Bewegung
gibt die App für Ereignisse aus (siehe „Zwei Uhren"); eine Falte ist kein Ereignis, sondern
eine Offenlegung, und die rollt sich auf. Gilt für beide faltenden Spalten, Backlog wie
„Erledigt". Unter „Bewegung reduzieren" schaltet sie sich ganz ab.

**Die Falt-Zeile reist nicht — sie blendet.** Ihr Ruheplatz liegt unter dem Stapel,
also verschiebt ihn das Aufklappen um dessen volle Höhe. Das als Fahrt zu animieren
schickte einen kontrastreichen Textstreifen in einer Drittelsekunde über die halbe
Spalte — das schnellste bewegte Objekt des ganzen Boards, und ausgerechnet der Anker
des Auges (die eben geklickte Zeile) war es, das da raste. Ein Zwischenstand erhielt
ihre Identität während des Flugs (drehendes Chevron, überblendender Text); das machte
den Streifen ordentlicher, nicht ruhiger — und wurde verworfen.

Die Kurve ist ein **Ease-in-out über 0,5 s** und ausdrücklich **keine Feder.** Eine Feder
— auch kritisch gedämpft, auch mit `bounce: 0` — startet mit voller Geschwindigkeit und
bremst hinein: die Form von etwas, das *ankommt*. Auch bei längerer Dauer blieb das der
falsche Charakter, es las sich als etwas langsamer aufgerissene Spalte. Ease-in-out
beginnt aus der Ruhe, der Stapel setzt sich also in Bewegung, statt geworfen zu werden.
Es ist außerdem die einzige Kurve des Boards ohne physikalische Metapher — richtig für die
eine Geste, die nichts bewegt: Die Karten waren immer da. Zum Vergleich: 0,22 s für einen
Kartenwechsel, hier gut die zehnfache Strecke in gut der doppelten Zeit (nicht
proportional — das wären Sekunden).

Es gilt die Distanzregel der Plattform: **kurze Wege animieren, lange Wege blenden.**
Die zugeklappte und die aufgeklappte Zeile sind zwei Ansichten (`id(expanded)`): die
alte löst sich an ihrem Platz auf, die neue erscheint an ihrem, beide auf der Kurve der
Falte — nichts überquert dazwischen den Bildschirm. Die Karten blenden, die Zeile
blendet: eine leise Geste. Das Chevron zeigt je Zustand in seine Richtung (gedreht
statt ausgetauscht, damit beide Enden derselben Form angehören). Juli 2026, nach
zweifachem Nutzer-Feedback — der erste Fix hatte das falsche Element beruhigt.

**Wiederkehrende Aufgaben lassen sich nicht aus „Erledigt" zurückholen, solange die
Serie weiterläuft.** EventKit löst eine abgehakte Ausführung aus ihrer Serie und legt
die nächste sofort als eigene offene Erinnerung an. `isCompleted` wieder zu löschen
würde die Ausführung deshalb nicht zurückdrehen, sondern *neben* der laufenden Serie
wiederbeleben — dieselbe Aufgabe stünde zweimal auf dem Board. Die App sagt das
stattdessen und ändert nichts.

**Weckzeiten folgen dem Fälligkeitsdatum.** Wird ein Datum im Editor verschoben, wandert
der Alarm mit, der genau auf dem alten Datum lag; wird das Datum entfernt, geht er mit.
Bewusst eng: relative Alarme, Ortsalarme und alles, was der Nutzer auf eine andere Zeit
gestellt hat, bleiben unangetastet — sie tragen eine Absicht, die die App nicht erraten
kann.

**Löschen fragt nach.** Der Menüpunkt öffnet eine Rückfrage mit dem Namen des Tickets
(„… löschen?"); „Abbrechen" ist die vorbelegte Antwort und liegt auf Return **und**
Escape, „Löschen" braucht einen bewussten Klick. Dieselbe Rückfrage für jeden Weg ins
Löschen, also auch für die VoiceOver-Aktion — sie hängt am Store, nicht an der Maus
(gleiches Muster wie die WIP-Rückfrage). Undo und Redo fragen nicht: eine Entscheidung
wiederholen ist keine neue Entscheidung.

Bis Juli 2026 fragte die App nicht und verwies auf ⌘Z. Das Argument trug nicht, weil das
Netz ein Loch hat: Beim Wiederherstellen legt die App eine **neue** Erinnerung mit
demselben Inhalt an (Titel, Notizen, URL, Ort, Priorität, Datum, Wiederholung,
Erinnerungen, Erledigt-Status samt ursprünglichem Erledigt-Datum) — EventKit kennt kein
echtes Wiederherstellen. Was EventKit nicht herausgibt, kommt damit **nicht** zurück:
**Unteraufgaben, Anhänge, Reminders-Tags und -Flags**. Genau das sagt die Rückfrage.

Jede Schreib-Aktion der App — Verschieben, Umbenennen, Anlegen, Löschen — registriert ihr
Gegenteil beim Undo-Manager des Fensters und ist mit **⌘Z** widerrufbar, ⇧⌘Z stellt sie
wieder her. Die Erinnerung bekommt beim Wiederherstellen eine neue interne ID.

### Wiederkehrende Aufgaben beim Erledigen

Am 08.08.2026 gegen echtes EventKit gemessen (iCloud-Liste, wöchentliche Regel), nachdem
ein Ticket nach dem Erledigen in „Als Nächstes" stehen blieb:

- Eine wiederkehrende Erinnerung abzuhaken erledigt **nicht** den Datensatz, den das Board
  in der Hand hat. EventKit legt den erledigten Durchgang als **neue, abgelöste**
  Erinnerung ab (eigene ID, keine Wiederholungsregel mehr) und lässt die **Serie unter der
  bisherigen ID** weiterlaufen, nur mit dem nächsten Fälligkeitsdatum.
- Die Spalte wird dabei korrekt freigegeben: Die zurückkehrende Serie steht im
  **Backlog** — richtig, denn ihr nächster Durchgang wurde noch nicht gezogen. (Damals
  über das Entfernen des Status-Hashtags, seit 13.08.2026 über den eigenen Speicher; das
  Ergebnis ist dasselbe, und seither kann iCloud es auch nicht mehr zurückschreiben.)
- **Die ID wechselt also die Bedeutung.** Ab dem Erledigen zeigt sie auf den *nächsten*
  Durchgang. Alles, was vorher auf diese ID gebucht wurde, zielt danach auf Arbeit, die
  niemand begonnen hat — im Undo-Stapel gleich mehrfach: Das erste ⌘Z setzte den nächsten
  Durchgang auf „In Bearbeitung", das zweite auf „Als Nächstes". So kam eine Karte in eine
  Arbeitsspalte, ohne je gezogen worden zu sein, und zählte dort gegen das WIP-Limit. Der
  Zaun dagegen gilt unverändert: Er schützt vor einem falsch gezielten Zug, gleich wohin
  dieser Zug schreibt.

**Regel daraus:** Ist eine wiederkehrende Karte erledigt worden, werden **wiedergespielte**
Schreibvorgänge (Undo/Redo) über diese ID abgelehnt und erklärt („Nicht rückgängig
gemacht") statt ausgeführt. Der Eintrag bleibt dabei auf dem Stapel und wird von der
Erklärung verbraucht — ihn still zu verschlucken, ließe das *nächste* ⌘Z in eine Änderung
greifen, die der Nutzer behalten wollte.

**Maßgeblich ist die Reihenfolge, nicht ein Merker** (seit 10.08.2026): Abgelehnt wird ein
Eintrag, der **vor oder bei** der Erledigung entstanden ist. Was der Nutzer *danach* am
zurückgekehrten Durchgang tut — ziehen, umbenennen, im Editor ändern —, gehört ihm und ist
ganz normal widerrufbar. Vorher gab ein eigener Zug die ID pauschal frei, womit das
*zweite* ⌘Z einen Eintrag von vor der Erledigung erwischte und die nie gezogene Karte still
nach „In Bearbeitung" schrieb; und umgekehrt wurde eine gerade selbst gemachte
Editor-Änderung abgelehnt, während dieselbe Änderung inline widerrufbar blieb.

**Der Zaun sitzt an der einen Stelle, an der Undo-Einträge entstehen.** Damit gilt er für
Verschieben, Umbenennen, Anlegen, Löschen und Bearbeiten gleichermaßen — ⌘Z bedeutet auf
allen Wegen dasselbe, und ein künftiger Schreibpfad kann den Zaun nicht vergessen, weil es
nichts zu vergessen gibt. Vergisst er seinen Platz in der Reihenfolge, wird sein Eintrag
**abgelehnt**; die Regel fällt also zur sicheren Seite (`RecurringHandoff`).

Die Reihenfolge ist bewusst eine Ordnung und keine Uhr: Sie fragt „vorher oder nachher?",
nie „wie lange her?". Es gibt nichts zu kalibrieren, und sie übersteht Zeitumstellung,
Uhrabweichung und ein aus einem Backup zurückgespieltes Einstellungsfile — was eine
Zeitspanne alles nicht tut.

Ein *automatischer* Schreibvorgang — eine Echo-Antwort, die Hygiene — trägt keinen
Undo-Eintrag und damit keinen Platz in dieser Reihenfolge. Für ihn gilt weiterhin die
einfache Frage, ob die ID noch auf einen ungezogenen Durchgang zeigt; dort gibt ein
eigener Zug des Nutzers sie tatsächlich zurück.

Eine Ausnahme brauchte der Zaun zwischenzeitlich für die Freigabe eines verbrauchten
Pulls — sie ist seit dem Formwechsel gegenstandslos: Die Freigabe schreibt nur noch in den
eigenen Speicher und geht an EventKit gar nicht mehr vorbei.

Ebenfalls an dieser Stelle: Die Erledigt-Settle-Animation wird für wiederkehrende Karten
**nicht** mehr auf die gezogene ID gelegt — sie gehörte sonst der zurückkehrenden
Backlog-Karte. Der erledigte Durchgang ist ein eigener Datensatz und bekommt sie über
dieselbe Abgleich-Erkennung wie Arbeit, die auf einem anderen Gerät fertig wurde, also
innerhalb von `Board.settleDelay` — die Choreografie bleibt unverändert.

Das Gegenstück bleibt bestehen: Eine erledigte Ausführung aus „Erledigt" **heraus**zuziehen
lehnt die App weiterhin mit „Nicht zurückgeholt" ab, weil das die Aufgabe doppelt aufs
Board legen würde.

**Und dasselbe Urteil gilt, wenn der Klick woanders passiert ist** (11.08.2026): Wird ein
erledigter Durchgang außerhalb wieder aufgehakt — in der Erinnerungen-App, am iPhone, per
Skript —, entsteht genau der Zustand, den die App bei sich selbst verbietet: ein zweiter,
gleich aussehender Datensatz neben einer Serie, die den nächsten Durchgang längst trägt.
**Das Board zeichnet ihn nicht.** Die Serie vertritt ihn dort bereits.

Erkannt wird er wie jeder Durchgang — gleiche Liste, bitgenau dasselbe Anlegedatum, genau
eine passende lebende Serie (`RecurringSeriesMatch.revivedOccurrenceIDs`) —, nur dass er
offen statt erledigt ist. Gemessen am 11.08.2026: Das Wiederaufhaken ist die **einzige**
Operation, die einen offenen abgelösten Datensatz erzeugt; Umbenennen der Serie,
Verschieben ihrer Fälligkeit und das Erledigen selbst erzeugen keinen. Mehrdeutigkeit wird
angezeigt, nicht verborgen, wie überall sonst in dieser Regel.

**Der Datensatz bleibt unangetastet** — kein Schreibvorgang, kein Tag, kein
Erledigt-Status wird angefasst; in der Erinnerungen-App steht er unverändert und lässt
sich dort abhaken oder löschen. Verschwindet die Serie, ist er wieder eine gewöhnliche
Aufgabe und erscheint sofort. **Bewusste Abweichung vom Grundsatz „das Board zeigt, was in
den Daten steht":** Die Begründung steht in CONCEPT.md, „Ein wiederbelebter Durchgang ist
keine zweite Aufgabe" — wer diese Zeile für einen Fehler hält, lese sie zuerst.

**Erkannt wird ein Durchgang am Anlegedatum, nicht am Titel** (seit 10.08.2026): Der
abgelöste Durchgang trägt bitgenau das Anlegedatum seiner Serie — gemessen über den
App-Weg, über einen iCloud-Roundtrip und beim Abhaken auf dem iPhone — Messung, verworfene
Alternativen und Abbruchkriterium: CONCEPT.md, „Ein Durchgang und seine Serie: Identität
statt Ähnlichkeit“.
Eine gewöhnliche Aufgabe trägt ihr eigenes. Damit fällt beides weg, was die Titel-Regel
falsch machte: Eine einmalige Aufgabe, die zufällig genauso heißt wie eine Serie, **lässt
sich wieder zurückholen** (vorher nie, mit einer Begründung, die über diese Karte schlicht
nicht stimmte); und ein **Umbenennen der Serie** nach dem Erledigen setzt den Schutz nicht
mehr außer Kraft. Verglichen wird auf **Gleichheit, nie auf Nähe** — zwei in derselben
Sekunde angelegte Aufgaben trennen nur Mikrosekunden, ein Toleranzfenster machte sie
einander zu Durchgängen. Passt keine oder mehr als eine Serie, gilt „kein Beweis": Der Zug
ist dann erlaubt (`RecurringSeriesMatch`).

Dieselbe Identität trägt seit 10.08.2026 auch die **stille** Hälfte — die Pull-Freigabe
weiter unten, Bedingungen 2 und 3. Dort ist „kein Beweis" die andere Richtung: Die Karte
bleibt, wo sie steht. Live gegen echte iCloud-Daten geprüft, beide Richtungen: eine gleichnamige
fremde Aufgabe, angelegt und erledigt zwischen zwei Refreshes, ließ den Tag der gezogenen
Karte stehen; die Serie selbst extern abgehakt gab ihn binnen eines Syncs zurück.

**Extern abgehakt (09.08.2026 gegen echtes iCloud gemessen, nachdem eine wöchentliche
Karte nach jedem Abhaken erneut in „Als Nächstes" stand):** Wird eine gezogene
wiederkehrende Erinnerung außerhalb abgehakt — Erinnerungen-App, iPhone, Mitteilung, oder
von einer anderen Person in einer geteilten Liste —, rollt die Serie unter derselben ID
weiter. Der Eintrag des Boards zeigt danach auf den **nächsten**, nie gezogenen Durchgang,
und der stand damit in einer Arbeitsspalte, Woche für Woche. (Bis 13.08.2026 stand die
Spalte als Tag in den Notizen; das Fehlerbild ist dasselbe geblieben, nur der Ort nicht.)

**Regel daraus (`RecurringTagRelease`):** Der Pull wurde vom erledigten Durchgang
verbraucht — die App gibt ihn deshalb still zurück (Karte → Backlog), aber nur, wenn das
*beweisbar* ist. Seit 13.08.2026 ist die Regel ein **stehender Zustand, keine Kante
mehr**:

> Eine gezogene Serie, deren jüngster erledigter Durchgang **nach** dem letzten Pull
> dieser Serie an diesem Board erledigt wurde, trägt einen verbrauchten Pull. Er wird
> freigegeben — so oft, wie etwas ihn wiederherstellt.

Bis dahin prüfte die Regel nur in dem einen Refresh, der die frische Completion zum
ersten Mal sah („ID nie zuvor geladen"). Diese Form verlor eine echte Karte (gemessen
12.–13.08.2026, „Einkaufen"): Durchgang um 22:40 in der App erledigt, Tag sauber
entfernt — um 22:49 schob ein fremder Schreiber (der Kalender-Client aus der Messung vom
10.08.) den alten Stand mit `#next` auf die weitergerollte Serie zurück. Die App hatte
den sauberen Zwischenzustand nie gesehen, die Completion-ID galt fortan als bekannt, die
Kante war verbraucht — und keine Instanz stellte die Frage je wieder. Der nie gezogene
nächste Durchgang stand dauerhaft in „Als Nächstes". Ein Zustand kennt dieses Problem
nicht: Kaltstart, Schlaf-Lücke oder ein Stunden später zurückgeschobener Tag landen alle
in derselben Prüfung.

Alle Bedingungen müssen gelten, jeder Zweifel lässt den Tag stehen (ein stehen
gebliebener Tag kostet einen Zug, eine still zurückgeschobene gezogene Karte bräche das
Pull-Prinzip):

1. Die Serie ist offen, wiederkehrend und steht in einer Arbeitsspalte.
2. Eine erledigte Erinnerung derselben Liste trägt bitgenau das **Anlegedatum** der
   Serie — die Identität eines abgelösten Durchgangs (siehe „Erkannt wird ein Durchgang
   am Anlegedatum" oben). Bis 10.08.2026 stand hier der Titel: Eine auf einem anderen
   Gerät angelegte **und** erledigte gleichnamige Aufgabe konnte damit einer gezogenen
   Karte den Tag entziehen.
3. Genau **eine** lebende Serie der Liste trägt dieses Anlegedatum. Geprüft unter
   *allen* Serien der Liste, nicht nur den gezogenen — strenger, weil dies die einzige
   Regel ist, die eine Karte bewegt, ohne dass jemand hinsieht.
4. Der jüngste solche Durchgang wurde **nach** dem letzten an diesem Board
   registrierten Pull der Serie erledigt — und **nach** `activeSince`, dem ersten Lauf
   dieser Regelform. Ältere Completions sind keine Evidenz: Die Pulls, gegen die sie
   abzuwägen wären, wurden nie aufgezeichnet, und sie zu werten hätte beim Upgrade
   einmalig jede legitim gezogene wiederkehrende Karte boardweit zurückgestuft.
5. Der Nutzer hat die Serie im laufenden Refresh-Zyklus nicht selbst bewegt — eine Hand
   an der Karte schlägt jede Buchhaltung.

**Das Pull-Gedächtnis** (`RecurringTagRelease.Memory`, ein UserDefaults-Schlüssel
`tagReleaseMemory`): Jeder Zug einer Serie in eine Arbeitsspalte wird dauerhaft mit
Zeitpunkt vermerkt (höchstens 200, älteste zuerst verdrängt) — auch ein Replay über
⌘Z/⇧⌘Z, denn auch das schreibt dieses Board. Gestempelt wird **nie früher als eine
Sekunde nach der jüngsten Completion, die das Board bereits sieht**: Eine Completion,
die vor dem Pull da war, kann ihn damit nie überstimmen — auch dann nicht, wenn die Uhr
des erledigenden Geräts vorgeht. Die Gegenrichtung fällt zur sicheren Seite: Geht eine
Uhr so weit nach, dass eine echte spätere Completion vor dem Pull gestempelt ist, bleibt
die Karte stehen und kostet nichts. Das alte Gedächtnis der Kantenform (geladene IDs,
getaggte Spalten) wird beim Upgrade verworfen; `activeSince` beginnt dann jetzt.

Die Freigabe ist bewusst **nicht widerrufbar** und ohne Dialog: Es wird keine
Nutzer-Entscheidung zurückgenommen, und ein ⌘Z, das ungezogene Arbeit wieder zöge, ist
genau das, was `RecurringHandoff` auf der Replay-Seite verhindert. Seit dem Formwechsel
(13.08.2026) braucht sie auch keine Taktung mehr: Sie schreibt ausschließlich in den
eigenen Speicher, fasst also weder eine fremde Notiz an noch kann ein fremder Schreiber
ihr widersprechen.

**Verbleibende, akzeptierte Restlücke:** Ein zweiter Mac mit dieser App auf denselben
Listen führt seine eigenen Spalten. Pulls leben auf dem Board, auf dem sie gemacht
wurden; ein dort gemachter Pull ist hier unsichtbar. Wer Boards teilen will, teilt sie
über *eine* Maschine — der Preis dafür, dass die Spalte niemandem sonst zugänglich ist.
Festgehalten am 13.08.2026, abgewogen gegen den gemessenen Schaden der Geisterkarte.

Im selben Zug abgesichert: `move` schreibt `isCompleted` nur noch, wenn sich der Wert
tatsächlich ändert — ein seitlicher Zug hat auf einer laufenden Serie keine
Erledigt-Felder anzufassen. (Gemessen hat auch die alte, redundante Schreibung keine
Notizen verändert; die Absicherung ist Hygiene, nicht Fehlerbehebung.)

### Tastaturkürzel

| Kürzel | Wirkung |
|---|---|
| ⌘N | Neues Ticket im Backlog (derselbe Weg wie das „+") |
| ⌘F | Finden-Popover (Suche + Filter) |
| ⇧⌘F | Filter zurücksetzen |
| ⇧⌘R | Erinnerungen-App öffnen |
| ⌘R | Board aktualisieren |
| ⌘Z / ⇧⌘Z | letzte Board-Änderung rückgängig / wiederherstellen |
| ⌘, | Einstellungen |
| Return | im Karten-Editor: übernehmen und schließen (legt ein neues Ticket an) |
| ⌘Return | dasselbe aus dem Notizfeld heraus, wo Return die Zeile umbricht |
| Escape | im Karten-Editor: verwerfen und schließen (bricht eine Neuanlage ab) |

Jeder dieser Befehle steht auch im Menü „Board" — ein Kurzbefehl, den man nur durch
Überfahren eines Toolbar-Knopfs findet, ist keiner. ⌘N lag bis Juli 2026 auf
„Erinnerungen öffnen", während die einzige anlegende Geste der App („+") gar keinen
Kurzbefehl hatte: der Mac-Reflex erzeugte damit ausgerechnet das, was er nirgends
bedeutet. „Erinnerungen öffnen" ist auf ⇧⌘R gewandert.

**Bei geöffneter Karte ist die Toolbar deaktiviert.** Das Board tritt hinter die
hochgehaltene Karte zurück; ein Klick auf die Flamme legte die Statistik vorher *über*
den offenen Editor. Die Toolbar bleibt sichtbar und scharf — sie ist Chrome, kein Inhalt
— konkurriert aber nicht mit dem, was gerade in der Hand ist.

## Karten-Anzeige

Die Kartendichte richtet sich nach der Spalte — das ist der Fokus-Mechanismus des Boards:

| Spalte | Karte zeigt |
|---|---|
| Als Nächstes, In Bearbeitung | Titel, Prioritätsmarken, Notizen-Auszug (bis 3 Zeilen), Fälligkeits-Badge, Wiederholungs-Icon, Listenname, Verweildauer |
| Backlog | eine Zeile: Prioritätsmarken, Titel, Wiederholungs-Icon, Fälligkeits-Badge |
| Erledigt | nur der Titel, durchgestrichen |

- **Karten ohne Notiz zeigen „Keine Notizen"** statt einer leeren Zone — die
  Notizen-Zone gehört zur Ticket-Anatomie und steht immer, aber ein leerer Streifen
  zwischen zwei Trennlinien liest sich als Darstellungsfehler, nicht als „hier steht
  nichts". Reine Anzeige: in EventKit wird nichts geschrieben (Juli 2026)

- **Zwei Textstufen, je eine Bedeutung** (gilt für Board und Karten-Editor, siehe
  `BoardText`):
  - **primär** — was das Ticket *sagt*: Titel und Notiz, auf der Karte wie im
    geöffneten Ticket
  - **sekundär** — was es nur *beschreibt*: Fußzeilen-Fakten (Listenname,
    Verweildauer), Feld-Beschriftungen, Spaltenköpfe

  Die Trennung verläuft zwischen Inhalt und Beschriftung, nicht zwischen wichtig und
  unwichtig — deshalb behält die Notiz ihre Farbe, wenn man die Karte öffnet. Eine
  frühere Fassung setzte den Notizen-Auszug auf der Karte sekundär; derselbe Text
  wechselte dadurch beim Öffnen die Farbe und wirkte wie zwei verschiedene Dinge
  (Juli 2026, nach Nutzer-Feedback angeglichen). Auf der Karte führt der Titel
  weiterhin, getragen von Größe und Gewicht (15 pt semibold über 12 pt regular) —
  genau dem Paar, das die beiden auch im Editor trennt.

  „Keine Notizen", „Keine URL", „Kein Datum" sind **sekundär** — ein Platzhalter ist
  nicht, was das Ticket sagt, sondern die App, die sagt, dass da nichts ist. Das ist
  die Regel, keine Ausnahme davon, und kostet keine dritte Graustufe. Zwei verworfene
  Zwischenstände (Juli 2026): erst eine eigene tertiäre Stufe (eine Farbe zu viel),
  dann primär wie der Inhalt — dabei war „Keine Notizen" im Editor nicht mehr von einer
  echten Notiz zu unterscheiden und stand zwei Zeilen über „Dringlichkeit: Keine", das
  ein echter Wert ist. Das Suchfeld dämpft seinen Platzhalter ohnehin.
  Ausnahme: System-Controls (Picker im Editor) behalten ihre eigene Textfarbe

- **Erledigt-Titel in voller (primärer) Textfarbe, nicht gedämpft** — der Durchstrich
  markiert bereits „fertig"; eine zusätzlich sekundäre Farbe wäre ein zweites Signal für
  dieselbe Tatsache. Eine frühere Fassung dämpfte den Titel zusätzlich, wurde aber
  verworfen (Juli 2026)

- **Ein Raster, zwei Kartengrößen.** Eine Karte ist entweder **38 pt** hoch (Backlog,
  Erledigt) oder **152 pt** (Als Nächstes, In Bearbeitung) — die große ist **exakt das
  Vierfache** der kleinen. Beide Höhen sind fest, nicht Mindestmaß: „gleich groß" muss
  auch für das Ticket gelten, das am meisten zu sagen hat.

  Vorher ergaben sich beide Höhen aus dem Inhalt, und das ging schief: Eine
  Backlog-Zeile wurde einen Punkt höher, sobald sie ein Datums-Badge trug (37 → 38), und
  eine Karte der Arbeitsspalten schwankte je nach Titel- und Notizlänge zwischen 118 und
  133. Vier Spalten nebeneinander hatten damit vier Zeilenrhythmen, von denen keiner ein
  Vielfaches der anderen war — das Board wirkte leicht unrund, ohne dass man sagen konnte
  warum.

  Vier ist das kleinste Vielfache, das noch das vollste Ticket fasst, das die Anatomie
  zulässt (dreizeiliger Titel über dreizeiliger Notiz misst 141; drei Zeilen wären
  114). Der Rest ist Luft in der Notizen-Zone, wo die Karte sie ohnehin will. Gemessen
  am laufenden Board: Zeilenabstand Backlog/Erledigt 43 pt (38 + 5), Arbeitsspalten
  160 pt (152 + 8) — 152 ÷ 38 = 4,000 (Juli 2026)

- **Listenfarbe als Akzent:** `EKCalendar.color` als schmaler Streifen an der linken
  Kartenkante
- **Verweildauer:** ab 3 Tagen in derselben Spalte zeigt die Karte „N Tage" — gerechnet
  ab dem Zeitpunkt des Zugs aus dem eigenen Speicher; nur für Karten, die dieses Board nie
  bewegt hat, näherungsweise über `lastModifiedDate` (siehe oben)
- **Links werden auf der Karte immer ausgeblendet:** URL-artige Textteile werden vor der
  Anzeige aus Titel und Notizen entfernt. Das betrifft **nur die Karten-Darstellung** — in
  EventKit wird nichts zurückgeschrieben, auch nicht beim Umbenennen, und der Editor zeigt
  Notizen und URL-Feld ungefiltert
- **Hashtags in Notizen** werden angezeigt wie jedes andere Wort (seit 13.08.2026; vorher filterte die App ihr eigenes Steuerzeichen heraus)
- **Backlog klappt ab 15 Karten ein** („N weitere anzeigen")
- **Keine Tooltips auf Karten** (siehe Interaktion) — Tooltips gibt es nur am Chrome:
  Spaltenkopf (Zähler/Regeln) und „+"-Button

**Sortierung** in den offenen Spalten: Dringlichkeit (überfällig/heute zuerst) → Priorität →
frühestes Fälligkeitsdatum (Karten ohne Datum zuletzt) → **Erstellungsdatum (älteste
zuerst)** → Titel. Das Alter vor dem Titel, weil alphabetisch nie eine *Bedeutung* war,
sondern nur Stabilität herstellte: Bei gleicher Priorität und Fälligkeit geht die Karte
vor, die am längsten im Stapel wartet (FIFO — die faire Warteschlangen-Regel, und das,
was ein altes Ticket davor bewahrt, unter allem Später-Hinzugefügten begraben zu werden).
Bewusst das **Erstellungs**- und nicht das Änderungsdatum: Letzteres wird von jedem
Verschieben und jeder Bearbeitung neu gesetzt und würde die Spalte als Nebenwirkung des
Anfassens umsortieren. Der Titel bleibt das letzte Wort — für Karten ohne Erstellungsdatum
(EventKit garantiert es nicht) oder mit demselben —, damit die Reihenfolge zwischen zwei
Refreshes nie springt.
„Erledigt" sortiert nach Erledigt-Datum, neueste zuerst.

**Erledigt zeigt die letzten 7 Tage** — die Arbeit einer Woche als Nachweis, kein Archiv.
Liegen ältere erledigte Karten vor, steht **direkt unter der letzten Karte** „N ältere
anzeigen ˅" (dasselbe Muster wie beim Backlog): ein Klick holt **die letzten 30 Tage**
zurück. Dieselbe Zeile schließt den Blick zurück wieder („Ältere ausblenden ˄", im
Backlog „Weniger anzeigen") — sie sitzt dann am Ende der aufgeklappten Liste, wo man zu
Ende gelesen hat; ein Neustart klappt ohnehin wieder ein.
Bewusst begrenzt statt „alles laden" — eine Liste, die kurz genug zum Überfliegen
bleibt, braucht keine Datums-Überschriften, Gruppen oder eigene Archiv-Ansicht. Alles
Ältere liegt in der Reminders-App, dem eigentlichen Speicher; darauf weist der
Spalten-Tooltip im aufgeklappten Zustand hin. Die Zähler-Kapsel benennt immer die
angezeigte Menge und wächst beim Aufklappen mit; was sie ausblendet, meldet der Tooltip
(„N ältere Karten"). Im Backlog gilt dieselbe Regel mit anderem Schnitt: die Kapsel nennt
dort den ganzen Stapel, und der Falz liegt an der Reifelinie (siehe „Reifegrad statt
Sichtbarkeit").

Die Fold-Zeile ist eine **blanke Textzeile** (Body-Schriftgrad medium + Chevron, sekundär,
bei Hover primär), kein Glas-Button: Glas gehört dem Chrome, nie der Inhaltsebene — in der
Mulde wäre eine Glasplatte eine aufgesetzte Fläche im falschen Stockwerk. Sie steht **im
Inhalt, nicht am Spaltenfuß**: Die Lanes sind immer fensterhoch, und am Fuß hing die Zeile
bei kurzem Stapel hunderte Punkte unter der letzten Karte im toten Raum — dort las sie
sich als Fenster-Chrome statt als Fortsetzung der Liste (Usability-Feedback Juli 2026;
Position am Fuß nicht wieder vorschlagen). Aus demselben Chrome-Grund zeigen die
Spalten **keine Scrollbalken**: Der System-Overlay-Balken läge als einziges Element *über*
den Karten; das „da ist mehr"-Signal ist der Fade am unteren Spaltenrand, gescrollt wird
unverändert.

## Finden (Suche + Filter)

Ein einziges Bedienelement in der Toolbar (Lupe, ⌘F) enthält alles zum Finden:

| Element | Datenquelle |
|---|---|
| Suche | Titel + **ganze** Notiz + URL-Feld, ohne Groß-/Kleinschreibung und Diakritika, Wortreihenfolge egal |
| Dringlichkeit | `EKReminder.priority` (Hoch/Mittel/Niedrig/Keine) |
| Fälligkeit | `EKReminder.dueDateComponents` (Überfällig/Heute/Diese Woche/Ohne Datum) |
| Listen | `EKCalendar` der Karte, Mehrfachauswahl (ab zwei Listen im Board) |

Ist gefiltert, trägt das eingeklappte Lupensymbol die Anzahl aktiver Einschränkungen und die
Akzentfarbe — ein Board darf nie gefiltert sein, ohne das zu zeigen. Die Listen zählen dabei
als **eine** Einschränkung, egal wie viele abgewählt sind: das Abzeichen zählt Zeilen, nicht
Werte.

**Der Listen-Filter startet vollständig angehakt und wird abgewählt**, nicht aufgebaut — der
Normalzustand des Boards ist „alle", und ein Filter soll zeigen, was gilt, statt ausgefüllt
werden zu wollen (gespeichert wird deshalb nur, was *aus* ist; siehe `ListFilter`). Zur
Auswahl stehen genau die Listen, die die Einstellungen aufs Board lassen: **die
Einstellungen entscheiden dauerhaft, was dazugehört, diese Zeile kurzfristig, was man gerade
ansieht.** Wird eine Liste in den Einstellungen abgeschaltet oder verschwindet sie aus
Erinnerungen, fällt sie aus dem Filter heraus — sonst bliebe eine Einschränkung aktiv, die
nichts mehr anzeigt und nirgends mehr zurückzunehmen wäre. Die Zeile erscheint ab **zwei**
Listen im Board — und außerdem immer dann, wenn etwas abgewählt ist, egal wie wenige Listen
übrig sind: Sonst nähme das Abschalten der zweiten Liste in den Einstellungen die Zeile weg,
während ihr Filter die letzte verbliebene Liste weiter ausblendet. Alle Listen abwählen ist erlaubt
und endet im ehrlichen „Keine Treffer" statt in einer bevormundenden Sperre; zurück geht es
über „Alle anzeigen" im Menü (nur sichtbar, wenn es etwas zurückzunehmen gibt) oder „Alles
zurücksetzen". Die Zeile ist ein Menü mit Häkchen statt einer Spalte von Ankreuzfeldern: Das
Popover hat eine feste Zeilenzahl, eine Spalte würde mit jeder Liste in Erinnerungen wachsen.
Alle drei Filterzeilen tragen denselben Menü-Knopf — eine Zeile als `Picker` und eine als
`Menu` unterschieden sich in Chevron und Breite.

**Wiederkehrende Aufgaben im Backlog:** siehe „Reifegrad statt Sichtbarkeit" weiter unten.
Sie werden **nicht gefiltert** — es gibt dafür bewusst keine Filterzeile.

**Leeres Board:** Zeigt das Board gar nichts, sagt es warum — „Nichts zu tun" (nichts da),
„Keine Treffer" (Filter, mit Zurücksetzen-Link) oder „Keine Liste ausgewählt" (keine Quelle,
mit Link in die Einstellungen).

### Leere Spalte: der angedeutete Platz

Jede leere Spur zeigt an der Stelle, wo die nächste Karte läge, einen **gestrichelten
Karten-Umriss mit einem Satz darin** — genau so hoch wie eine echte Karte *dieser* Spalte
(38 pt bei Backlog/Erledigt, das Vierfache bei den Arbeitsspuren; „In Bearbeitung" übernimmt
die gemessene Höhe der obersten Karte aus „Als Nächstes", weil genau die dort landet).

| Spalte | Satz (Deutsch) | Satz (Englisch) |
|---|---|---|
| Backlog | Nichts im Kopf behalten | Get it out of your head |
| Als Nächstes | Wählen statt sammeln | Choose, don't collect |
| In Bearbeitung | Fertigwerden beginnt hier | Finishing starts here |
| Erledigt | Nur Fertiges zählt | Only finished counts |

Die Sätze sind **indirekte Appelle, keine Beschreibungen**: Der Platz sagt, was zu tun ist, nie
wofür die Spalte gedacht ist — ein Board, das seine eigenen Spalten erklärt, traut ihnen nicht.

**Vier verschiedene Satzbauten**, absichtlich: verneinter Infinitiv, Gegenüberstellung,
„X beginnt hier", „Nur X zählt". „Als Nächstes" und „In Bearbeitung" teilten sich zunächst das
„beginnt hier" — als Reim zwischen den beiden Spalten mit WIP-Limit gedacht, nebeneinander auf
dem Board aber schlicht derselbe Satz zweimal. Stattdessen bezieht sich jede Spalte auf eine
*Nachbarin*, ohne sie zu kopieren: „Als Nächstes" greift nach links (Backlog sammelt — also
hör auf zu sammeln und wähle), und „Erledigt" meidet das Wortfeld „fertig", das seine
Nachbarin besetzt, und sagt stattdessen Kanbans eigenes *stop starting, start finishing* in
einem Atemzug.

**Die englischen Sätze sind Transkreation, keine Übersetzung** — dieselben Regeln, in einer
Sprache neu erfüllt. Backlog hieß zunächst wörtlich „Don't hold it in your head"; damit trugen
die beiden *nebeneinanderliegenden* Spalten Backlog und „Als Nächstes" beide ein „don't",
also genau die Doppelung, die das Deutsche vermeidet. „Get it out of your head" löst das mit
einem positiven Imperativ und ist zugleich Bensons und Allens eigene Formulierung für den
Capture-Schritt. Auch das Englische bleibt damit unter 28 Zeichen und in vier verschiedenen
Satzbauten.

Alle Sätze bleiben unter **~28 Zeichen** und einzeilig (`lineLimit(1)`) — bei minimaler
Fensterbreite (`columnMinWidth` 280) ist das die Grenze, ab der ein Umbruch den 38-pt-Umriss
sprengen würde.

**Wann er erscheint:** Die beiden Spuren, die durch Ziehen gefüllt werden, laden nur ein, wenn
es auch etwas zu ziehen gibt — „In Bearbeitung" braucht etwas stromaufwärts, „Als Nächstes"
einen nicht leeren Backlog. Backlog und Erledigt füllen sich nicht durch Ziehen (sondern über
„+"/die Reminders-App bzw. durchs Abhaken), dort genügt die Leere als Anlass. Ist das **ganze**
Board leer, schweigen alle vier: dann spricht `EmptyBoardNotice` in der Mitte, und vier Geister
dahinter wären dieselbe Nachricht noch viermal.

### Reifegrad statt Sichtbarkeit

Eine **wiederkehrende Backlog-Karte, deren nächster Termin noch nicht erreicht ist**, sinkt
ans Ende der Spalte, und der Backlog-Falz schneidet genau an dieser Linie. Sie wird nie
ausgeblendet: ein Klick auf die Falz-Zeile („N noch nicht fällig") holt sie hervor, von dort
lässt sie sich wie jede andere Karte ziehen. Einmal in einer Arbeitsspur ist sie eine
getroffene Entscheidung und wird nicht mehr umsortiert.

Details:

- Betrifft **nur wiederkehrende Karten und nur Backlog**. Ein einmaliger Termin im Oktober ist
  eine bewusst gesetzte Verpflichtung; die Datumssortierung stellt ihn ohnehin hinten an.
- **Ohne Fälligkeitsdatum** gibt es keinen „nächsten Termin" — solche Karten bleiben unter den
  gewöhnlichen Optionen.
- Unterhalb der Reifelinie sortiert **allein das Datum**, nicht die Dringlichkeit: dort steht
  nichts zur Wahl für heute, und ein „!!!" in vier Monaten über einem „!" in einer Woche liest
  sich als gar keine Ordnung.
- Die Zähler-Kapsel nennt den **ganzen Stapel** (die Karten sind wirklich in der Spalte); der
  Spalten-Tooltip nennt die Aufteilung („N davon noch nicht fällig").
- Die Falz-Zeile **beschreibt immer ihren Inhalt, nie den Grund des Schnitts**: enthält der Falz
  ausschließlich noch nicht fällige Karten, benennt sie das („N noch nicht fällig"); ist auch
  nur eine fällige Karte dabei — weil der Stapel über das Kartenlimit gewachsen ist —
  fällt sie auf „N weitere anzeigen" zurück. Einen von zwei Gründen zu nennen wäre falscher als
  keinen: eine fällige, sofort ziehbare Karte darf nie unter dem Etikett „noch nicht fällig"
  liegen. Abgesichert durch `BacklogFoldTests`.

### Schalter „Noch nicht Fälliges einklappen"

In den Einstellungen unter **Backlog**; Standard **an**.

| Stellung | Der Falz klappt ein … |
|---|---|
| An (Standard) | noch nicht Fälliges **und** alles über dem Kartenlimit |
| Aus | nur, was über dem Kartenlimit liegt |

Die **Sortierung ist von beiden Stellungen unberührt** — noch nicht Fälliges sinkt immer ans
Spaltenende. Der Schalter entscheidet allein, ob der Falz an dieser Linie schneidet.

Das **Kartenlimit ist nicht abschaltbar**. Es hat keine Meinung über die Arbeit, sondern nur
über eine Spalte, die zur Wand wird — anders als die Reifelinie ist es keine Workflow-Frage.

**Warum an als Standard:** Backlog ist der Vorrat an Optionen, die das Board **jetzt** ziehen
könnte; eine Aufgabe, die in drei Wochen wiederkommt, ist keine davon. Ein Ruhezustand, der
zeigt, was tatsächlich ziehbar ist, ist sowohl der ruhigere als auch der Kanban-treuere.
**Warum es den Schalter trotzdem gibt:** der Backlog ist die Stelle, an der sich Arbeitsweisen
am stärksten unterscheiden — manche wollen den ganzen Vorrat sehen und selbst triagieren. Und
anders als bei der abgelösten Regel **verbirgt keine der beiden Stellungen etwas**: beide
klappen ein, beide benennen die Menge, beide sind einen Klick vom vollen Stapel entfernt.

**Warum nicht ausblenden (Entscheidung 27.07.2026, ersetzt die vorherige Regel):** Bis dahin
verschwanden diese Karten bis zur Fälligkeit ganz — Standard „Wenn fällig", umschaltbar in den
Einstellungen und in der Filterleiste. Das ist ein **Push-Konzept**: ein Terminplan, der
vorschreibt, wann etwas getan werden darf. Kanban begrenzt, wie viel *gleichzeitig in Arbeit*
ist (dafür gibt es die WIP-Limits), nicht, was angesehen werden darf. Praktisch blockierte die
Regel genau den Zug, für den das Board da ist: heute Kapazität haben und den Einkauf von
Mittwoch vorziehen. Die alte Begründung — eine Monatsaufgabe sei „Hintergrundrauschen" — trug
nicht: sie ist sehr wohl eine Entscheidung, nur eine schwächere, und schwächere Optionen
gehören nach unten, nicht weg. Mit gestrichen wurden dabei die Filterzeile „Wiederkehrende",
die Einstellung dazu und der Leer-Zustand „Nichts fällig". Der Schalter oben ersetzt die alte
Einstellung *nicht*: er wählt zwischen zwei Falz-Schnitten, die alte wählte zwischen Sehen und
Nicht-Sehen.

## WIP-Limits

- Konfigurierbar in den Einstellungen für „Als Nächstes" (Standard 5) und „In Bearbeitung"
  (Standard 3); 0 = kein Limit
- **Die Regel steht sichtbar unter den Steppern**, nicht mehr in einem Hover-Tipp am
  Abschnittstitel (10.08.2026): „Ist eine Spalte voll, fragt das Board vor der nächsten
  Karte nach. 0 heißt: kein Limit." Eine Regel, die nur beim Überfahren erscheint, ist
  keine explizite Regel — und „make policies explicit" ist die eine Kanban-Zusage, die
  dieses Board in Worten einlösen muss. Die Einstellungen sind der Ort, an dem das nichts
  kostet; das Board selbst bleibt wortlos. Der ersetzte Tipp („Finish before you stack")
  war eine Maxime — das Chrome benennt, es spornt nicht an (CONCEPT.md, „Ton der Texte")
- Das Limit läuft im Spaltenzähler mit (`1 / 3`), die Kapsel färbt sich beim Überschreiten
  teal
- **Nur „In Bearbeitung" fragt nach:** Wird das Limit dort überschritten, erscheint *nach*
  dem Ablegen ein Dialog („Weniger gleichzeitig, mehr fertig. Erst etwas abschließen?").
  Das Board blockt nichts — es lässt die Karte landen und bietet an, sie zurückzulegen. Die
  Frage stellt sich bei jeder Route (Drag & Drop, Kontextmenü, VoiceOver)
- Herleitung (Selbstverpflichtungs-Psychologie, „Reibung statt Verbot"): siehe CONCEPT.md,
  Abschnitt Motivation

## Motivation

- **Streak-Zähler in der Toolbar:** Flamme plus Zahl, rein lesend aus `completionDate`
  berechnet (Blickfenster: 400 Tage). Die Flamme füllt sich mit dem Tagesfortschritt.
  Sichtbar, sobald es überhaupt erledigte Aufgaben gibt; bei Serie 0 zeigt sie **nur die
  graue Flamme ohne Zahl** — eine „0" neben den Fensterknöpfen sieht kaputt aus und liest
  sich als Rüge, aber der Zugang zur Statistik darf nach einem Serienriss nicht verschwinden
  (siehe BACKLOG.md)
- **Statistik-Fenster** (Klick auf die Flamme, `StatsPopover`): zwei Ansichten über
  Textumschalter, damit ein Blick nie zur Navigation wird. Beide Register teilen dieselbe
  Silhouette — eine Hero-Zahl auf dem Glas, darunter eine Well mit Kennzahlen, darunter
  eine zweite Well —, sodass beim Umschalten die große Zahl ihre Bedeutung wechselt, nicht
  ihre Position:
  - **Beide Register immer exakt gleich hoch — feste Regel, nicht verhandelbar.** Das
    Popover nimmt die Höhe des höheren Registers (beide werden gelayoutet, das inaktive
    unsichtbar und inert per `ZStack`); Umschalten darf die Fenstergröße **nie** ändern.
    Zwei Ansichten, die einen Klick auseinanderliegen und beim Wechsel höher/niedriger
    springen, lesen sich als zwei verschiedene Fenster statt als *ein* Instrument mit zwei
    Seiten. Diese Regel wurde mehrfach versehentlich wieder entfernt — bei jeder Änderung
    an `StatsPopover` prüfen, dass sie erhalten bleibt.
  - **Jetzt:** Folge als Hero (Flamme + Zahl + optionale Belohnungszeile), heute erledigte
    Aufgaben, aktuelle Auslastung gegen das WIP-Limit, „Bis fertig"-Schätzung nach Little's
    Law (Bestand ÷ Tempo, bewusst als Schätzung beschriftet), 30-Tage-Verlauf als Balken in
    fester, großzügiger Höhe (das Diagramm ist die zweite Blickfläche des Registers)
  - **Rückblick:** Jahreszahl als Hero mit Siegel-Glyphe (`checkmark.seal`, den Regeln der
    Flamme folgend: Umriss/grau bei 0, gefüllt/orange sonst — beide Heroes öffnen mit
    Glyphe + Zahl + Einheit; der Meilenstein bei einer runden Zahl innerhalb der letzten
    7 Tage erscheint als Belohnungszeile darunter), dann längste Folge und die zwei
    **Personal-Kanban-Flusskennzahlen** — **Pro Woche** (Durchsatz, Ø letzte 30 Tage) und
    **Durchlaufzeit** (Median von „erfasst" bis „erledigt", nur einmalige Aufgaben, nur
    Erledigungen der letzten 30 Tage). Zusammen mit „In Bearbeitung" im anderen Register
    stehen damit alle drei Größen von Little's Law im Fenster — die Prognose ist
    nachrechenbar statt Orakel. **Little's Law wird in den Hover-Tipps beim Namen genannt**
    (an „Bis fertig", „Pro Woche" und „Durchlaufzeit"): das Chrome erklärt seine stillen
    Kanban-Regeln beim Überfahren, im Zeilen-Label wäre der Name Jargon. Darunter die
    Rangliste (bester Tag, stärkster Wochentag, häufigste Liste) über die ganze Historie,
    mit „Seit …"-Fußnote
  - **Durchlaufzeit bewusst gefenstert und ohne Wiederkehrer:** erledigte Instanzen
    wiederkehrender Erinnerungen tragen in EventKit das Anlegedatum der *Serie* (ggf. Jahre
    alt) und keine `hasRecurrenceRules` mehr — genau dieses geteilte Anlegedatum erkennt sie
    (`RecurringSeriesMatch`, seit 10.08.2026; vorher der Titel der noch offenen Serie). Und über die ganze Historie gemessen dominierten Backlog-Altlasten den
    Median (ehrlich, aber eine dauerhafte Anklage — Regel „belohnen, nie bestrafen"). Im
    30-Tage-Fenster beschreibt die Zahl das aktuelle Verhalten und verbessert sich mit ihm
  - Alles aus den Erinnerungen abgeleitet, die die App ohnehin lädt — keine zweite
    EventKit-Abfrage, keine eigene Speicherung. Der Meilenstein ist die eine bewusste
    Lockerung der „keine Badges"-Regel: nur ein Moment, nie dauerhaft (siehe CONCEPT.md)
- **Sensorisches Feedback beim Verschieben** (`MoveFeedback`, alles am einen `move()`-Pfad,
  damit Maus, Kontextmenü und VoiceOver gleich behandelt werden; sämtliche physischen
  Kanäle — auch der Affordanz-Tick beim Überfahren einer Ziel-Lane — wohnen in dieser einen
  Datei, nachdem ein älterer `Haptics`-Helfer am Drop-Pfad jede Landung doppelt klopfen
  ließ):
  - **Undo/Redo bleibt stumm:** Klang und Haptik gehören der Hand auf der Karte, nicht ⌘Z —
    ein rückgängig gemachtes Erledigen, das wie ein frisches klingt, feiert eine Korrektur.
    Die *visuellen* Settles bleiben auch bei Undo/Redo: Sie zeigen, wohin die Karte ging
    (Wegweiser), und Remote-Änderungen bekommen sie ebenso
  - **Haptik** bei jedem echten Spaltenwechsel (Trackpad; `.alignment`, beim Erledigen
    `.levelChange`) — das Einrasten der Karte unter dem Finger. Der Pull nach „In
    Bearbeitung" ist ein schneller **Doppel-Tick** (zweimal `.alignment`, 80 ms Abstand):
    Arbeitsbeginn hat mehr Puls als ein Ablage-Move, ohne den festeren Erledigt-Schlag
    zu borgen
  - **Leiser Klang beim Erledigen** — ein eigener, für die App synthetisierter Zweiklang
    (`CompletionChime.wav`: zwei weiche Glastöne, aufsteigende Quinte F#5→C#6). Bewusst
    **kein Systemklang**: jeder Klang aus /System/Library/Sounds dient irgendwo in macOS
    als Warn-/Hinweiston („Tink" wurde probiert und las sich als Warnung, nicht als
    Belohnung); Aufsteigen sagt „geschafft", ein einzelner Schlag sagt „schau her".
    Abschaltbar in den Einstellungen („Ton beim Erledigen", Standard: an). Nur beim
    Erledigen, nie bei anderen Moves: Fertigwerden ist der eine Moment, den Personal
    Kanban feiert. Fehlt die Ressource, bleibt es still — kein Rückfall auf Systemklänge
  - **Zwei Uhren:** Haptik und Klang antworten der *Hand* und feuern sofort beim Drop;
    die visuellen Settles antworten dem *Board* und warten `Board.settleDelay` (~240 ms =
    Transit + Marge), bis Reflow und Einfaden gelandet sind — erst ankommen, dann
    reagieren. Ohne diese Phase spielte das Wackeln mitten im Einfaden, eine Belohnung im
    Flug für eine Ankunft, die sichtbar noch nicht passiert war
  - **Settle-Animationen:** Erledigen = **nur der gezogene Durchstrich**: Die Karte legt
    sich ab, ein kurzer Atemzug (~0,3 s), dann zieht sich die Durchstreich-Linie in
    ~0,45 s (`easeInOut` — ein Stift setzt an, zieht durch und hebt ab; volle
    Geschwindigkeit aus dem Stand wäre ein Wisch) von links nach rechts über den Titel.
    Die Karte liegt dabei vollkommen still — ein Ereignis, eine Geste. Die Pause ist der
    Punkt: So macht es die Hand am echten Board (Karte ablegen, *dann* abhaken), und
    Vorfreude ist die halbe Belohnung; ein Strich, der schon während der Ankunft zeichnet,
    liest sich weder als Ankunft noch als Strich. Zwei frühere Begleiter wurden nach
    dieser Regel entfernt (Juli 2026): der grüne Blitz (eine Farbfläche *über* dem
    Papier — genau die Farbwäsche, die Karten auf diesem Board nie tragen) und der
    Squish, der ihn trug (sobald der Stift die Belohnung ist, war das Eindrücken davor
    nur Lärm vor der Geste). Der Strich ist die Abschlussgeste *im* Inhalt, dasselbe
    Zeichen, das die Karte ohnehin für immer trägt, nur beim Entstehen beobachtet.
    Technisch ist der Durchstrich erledigter Karten deshalb eine vom Board gezeichnete
    Linie (`CardView.strikeLine`), kein `Text.strikethrough` — auf ruhenden Karten von
    der Textauszeichnung nicht zu unterscheiden, bei „Bewegung reduzieren" steht er
    sofort vollständig; Pull nach
    „In Bearbeitung" = **kurzes Wackeln mit Pop**: die Karte platzt eine Spur zu groß
    herein (Scale-Pop ~1,08 nach *oben*) und eine locker gedämpfte Feder schwingt einen
    ~4°-Kipp ein paarmal durch die Null zurück — sie „zappelt vor Tatendrang" in ihren
    Slot, gedämpft in ~0,4 s (lauter als die frühere 2°-Version, aber weg, bevor es die
    Hand bremst). Pop bewusst nach *oben*: Erledigen ist der ruhige Stiftstrich,
    Anfangen platzt nach außen/oben — die zwei Belohnungen fühlen sich nie gleich an.
    Rotation trägt die Lesbarkeit: Es ist der eine Bewegungskanal, den das Board sonst
    nirgends nutzt (Karten skalieren, faden, verschieben sich — nichts kippt je), also kann
    das Wackeln nicht von der Einfüge-Transition der Lane geschluckt werden — zwei rein
    skalierungsbasierte Vorgänger gingen genau darin unter (eine Landung von oben mit
    Schatten wurde gebaut und als unpassend verworfen). „In Bearbeitung" und „Erledigt"
    sind deshalb von der generischen Einfüge-Transition der Lanes (Scale 0,93 + Fade)
    ausgenommen und faden nur: Wer ein eigenes Settle spielt, bekommt keinen zweiten Scale
    darunter — beim Pull zogen Einfüge-Scale (aufwärts) und Pop (abwärts) sogar
    gegeneinander. Technische Lehre dahinter (siehe
    `CardView.playSettleIfFlagged`): Start- und Zielwert einer Animation im selben
    Runloop-Tick zu setzen lässt SwiftUI beide zu einer Transaktion verschmelzen — der
    Startwert wird nie gerendert und es passiert sichtbar nichts; der Startzustand muss
    erst einen Frame stehen. Ohne Durchstrich — die Abschlussgeste bleibt dem
    Fertigwerden vorbehalten. Nur lokale Pulls
  - **Flammen-Nicken:** die Toolbar-Flamme macht bei jeder erledigten Aufgabe einen kleinen
    Bounce (auch wenn sich ihr Füllstand nicht ändert) — die kleinstmögliche Quittung, dass
    das Board es gesehen hat. Alles respektiert „Bewegung reduzieren"
- **Kein täglich wechselnder Motivationssatz** — war im ursprünglichen MVP vorgesehen und
  hat sich als unpraktikabel erwiesen (siehe BACKLOG.md)
- Ausdrücklich **keine** Punkte/Levels/Badges/Bestenlisten

## Design

- Liquid Glass auf der Chrome-Ebene (Fensterrücken, Toolbar, Popover); Spalten sind
  eingelassene Mulden, Karten deckendes Papier — siehe CONCEPT.md, Abschnitt Design-Anspruch
- **Immer-aktives Erscheinungsbild** — die App tritt nicht zurück, wenn das Fenster den
  Fokus verliert. Da das Board dauerhaft auf einem Zweitschirm offen und damit fast immer
  inaktiv ist, wird alles Glas über `WindowGlass`/`HUDGlassMaterial` mit `state = .active`
  gepinnt — auch die Scheibe hinter dem „+"-Knopf. Der Knopf nutzte kurzzeitig SwiftUIs
  natives `.glassEffect`, das sich aber nicht auf „aktiv" festhalten lässt und beim
  Fokusverlust aufhellte; damit war er das einzige Element, das in den Hintergrund trat.
  Regel: kein Element weicht zurück, nur weil das Fenster inaktiv ist — siehe CONCEPT.md,
  Design-Anspruch („Immer-aktiv")
- **Spalten füllen immer die volle Fensterhöhe** — bewusste Entscheidung, siehe BACKLOG.md
  („Explizit abgelehnt": Spalten enden mit dem Inhalt). Weniger Leerfläche = Fenster kleiner
  ziehen
- **Ein Titelmaß für alle Karten: 15pt** — Arbeitsspalten semibold, Backlog und Erledigt
  medium. Beim Verschieben ändert sich die Titelgröße dadurch nie; was sich ändert, ist der
  Detailgrad der Karte. Die 15 statt der früheren 14 für Lesbarkeit auf Distanz; der Rest
  der Skala bleibt unverändert (Spaltenkopf 13pt, sichtbar kleiner als beide Titel)
- Typografie/Abstände nach Apple HIG (SF Pro), Tokens in `DesignSystem.swift`
- Bewegung wird für Dinge ausgegeben, die *gerade passiert sind* (Karte rastet in „Erledigt"
  ein), nie für stehende Einladungen
- **Tempo des Boards:** Der Spaltenwechsel jeder Karte (Verlassen, Ankommen, Nachrücken)
  läuft über *eine* Kurve — `Board.cardMoveAnimation`, eine kurze, leicht federnde Spring
  (0,22 s). Da das die häufigste Bewegung ist, bestimmt dieser eine Wert, wie reaktiv sich
  das ganze Board anfühlt; die frühere flache 0,35-s-Spring ließ jeden Zug einen Takt hinter
  dem Drop wirken
- Erscheinungsbild: Nach System / Hell / Dunkel, in den Einstellungen wählbar
- Eigene Hover-Tooltips statt `.help(...)`, mit eigenen VoiceOver-Labels/Hints — nur am
  Chrome (Spaltenkopf, „+"-Button), nie auf Karten
- **Vibe-Referenz:** „Minimal Desk Setup" — die App als ruhiges, fast gegenständliches
  Objekt auf dem Screen statt auffällige Software

## Bekannte Einschränkungen (Apple-Plattform-Grenzen, kein Designfehler)

- Reminders-Tags, Flags und Unteraufgaben sind nicht über die öffentliche EventKit-API
  zugänglich — deshalb war die Spalte bis 13.08.2026 ein Hashtag in den Notizen
- Die Spalte ist in Reminders gar nicht sichtbar (seit 13.08.2026, siehe „Spalten =
  eigener Speicher der App"): Sie gehört diesem Board, nicht der Aufgabe. Vorher stand
  sie als Hashtag in den Notizen und war dort immerhin lesbar — der Preis dafür war, dass
  jedes andere Programm sie ändern konnte
- Der Deep-Link zum Bearbeiten-Popover nutzt ein undokumentiertes URL-Schema; fällt es weg,
  öffnet sich ersatzweise die Reminders-App selbst
- Ausgeschlossene Listen werden über `calendarIdentifier` gemerkt. Wird ein Konto entfernt
  und neu hinzugefügt, kann eine Liste mit neuer ID zurückkommen und wieder auf dem Board
  auftauchen — Gegenmittel ist ein Schalter in den Einstellungen
- Ein gelöschtes und per ⌘Z wiederhergestelltes Ticket ist technisch eine neue Erinnerung
  mit neuer interner ID
