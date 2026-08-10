# Befunde vom 09. August 2026 — Wiederkehrer-Tag überlebt externes Abhaken

Ausgelöst von einem Nutzerbericht: Eine wiederkehrende Karte („Einkaufen", geteilte
Liste, wöchentlich) stand immer wieder in „Als Nächstes", obwohl sie ins Backlog gezogen
wurde. Diagnose headless gegen echtes iCloud (Scratch-Liste „GK-Diagnose", eigene
Prozesse pro Messpunkt = kalter EventKit-Cache), da die UI-Automatisierung der App in
dieser Session nicht freigegeben war.

**Status hinter jedem Befund:** wie in FINDINGS-2026-07 (`gemessen` / `gelesen` /
`offen`).

## Hypothesen und Ausgang

| # | Hypothese | Ausgang |
|---|---|---|
| H1 | `notes = nil` (Notizen nur aus Tag) persistiert nicht | **widerlegt, gemessen** — Nil-Schreibung hält sofort und nach 2,5 min iCloud-Roundtrip, mit und ohne begleitende `isCompleted`-Schreibung. Nebenbefund: EventKit liest die Nil-Schreibung als leeren String zurück; der Kommentar „EventKit prefers nil over an empty string" in `StatusTagger.rewrittenNotes` beschreibt also die Schreibrichtung, nicht den Rundlauf. Belassen — beide Formen lesen sich als „kein Tag". |
| H2 | Unbedingtes `isCompleted = false` bei seitlichen Zügen stört die Serie | **widerlegt als Ursache, gemessen** — keine Notiz-Nebenwirkung beobachtet. Trotzdem absichert: `move` schreibt `isCompleted` nur noch bei tatsächlicher Änderung (der Setter fasst auch `completionDate` an). |
| H3 | Externes Abhaken lässt den Tag auf der weiterlaufenden Serie stehen | **bestätigt, gemessen** — Abhaken per EventKit-Schreibung (wie Erinnerungen.app/iPhone): Serie rollt unter derselben ID weiter und behält `#next`, der abgelöste Durchgang trägt ihn ebenfalls. Deckt sich mit dem Befund am echten Ticket: „Einkaufen" zuletzt am 08.08. um 00:08 abgehakt (außerhalb der App), Serie trug den Tag weiter. Behoben durch `RecurringTagRelease` (Regel in SPEC.md, „Extern abgehakt"). |
| H4 | Veralteter EventKit-Cache in der App | **nicht ausgelöst** — alle Messungen mit frischen Prozessen konsistent; kein Anlass, `eventStore.reset()` einzuführen (würde die gehaltenen `openRecurringReminders` mitten im Flug invalidieren). |

## Verifikation der Behebung

- 13 neue reine Tests (`RecurringTagReleaseTests`), Gesamtsuite 208/208 grün.
- Live gegen die laufende App gemessen: getaggte Test-Serie extern abgehakt → die App
  gab den Tag innerhalb eines Refreshs zurück (Serie → Backlog), abgelöster Durchgang
  von der bestehenden Hygiene bereinigt, Zustand nach weiteren 10 s unverändert (kein
  Save-Loop).
- Der Alt-Tag auf „Einkaufen" (aus einem Abhaken bei geschlossener App — die
  dokumentierte Restlücke) wurde einmalig manuell entfernt.

## Nachtrag 10.08.2026: Der Fehler war nicht behoben — die Ursache lag außerhalb der App

Das Ticket kam weiter zurück, obwohl der Nutzer weder in der Erinnerungen-App gearbeitet
noch etwas abgehakt hatte. Erst eine Instrumentierung aller Schreibpfade
(`os.Logger`, temporär) brachte den Beweis:

| Zeit | Beobachtung |
|---|---|
| 08:35:17 | `move WROTE: "Einkaufen" next -> backlog feedback=true notesNow=(leer)` — der Zug des Nutzers, korrekt geschrieben |
| 09:30:24 | `#next` ist zurück; die App protokolliert **nur** `refresh SAW CHANGE: backlog -> next`, keinen eigenen Schreibvorgang |
| 09:30 (gleicher Moment) | vier **erledigte** Erinnerungen bekommen Legacy-Tags zurück (`#alsnächstes`, `#inbearbeitung`) — Schreibweisen, die die App seit dem 07.08.2026 nicht mehr erzeugen kann |
| 08:34 / 09:30 / 11:03 | die Hygiene schreibt dieselben vier Erinnerungen **dreimal** um; kein einziger Schreibvorgang hält |

**Befund:** Ein fremder Schreiber (Verdacht: eine selbstgebaute Brücke zwischen Reminders
und Home Assistant — dessen Listen laufen über `local_todo`, sprechen also nicht von sich
aus mit Apple Reminders) schiebt alle 30–55 Minuten einen Datenstand von vor dem 07.08.
zurück. Die IDs bleiben dabei stabil (über vier Vorfälle gemessen) — Voraussetzung dafür,
dass eine App-seitige Regel überhaupt greifen kann.

**Zweiter, schwererer Befund:** Die App kämpfte blind. Sie prüfte nie, ob ein
Schreibvorgang Bestand hatte, und schrieb bei jedem Sync erneut — zwölf Schreibzugriffe in
fremde Daten in drei Stunden.

### Behebung: eine Invariante statt weiterer Sonderfälle

`CorrectionLedger` — *jede Korrektur an Daten, die die App nicht selbst geändert hat,
geschieht einmal; kommt derselbe Zustand zurück, akzeptiert die App ihn.* Verglichen wird
**byte-genau** der ersetzte Notiztext, damit ein von Hand getippter Tag nicht mit einem
Echo verwechselt wird. Regel in SPEC.md, Herleitung und die verworfenen Alternativen in
CONCEPT.md und BACKLOG.md.

**Vor dem Bau adversarisch geprüft und daran korrigiert:** Ein erster Entwurf (Vergleich
auf Statusebene, Rückzug mit Backoff, Pull-Verfall über Fälligkeitssprünge) hätte
Nutzerentscheidungen vom iPhone verschluckt, zwei Macs in eine Endlosschleife geführt und
aufgeschobene Termine still aus der Arbeitsspalte geworfen. Er wurde vollständig verworfen.

**Verifikation, gegen echte Daten mit laufender App gemessen:**

- Sturm-Schutz: erledigte Erinnerung mit Legacy-Tag → einmal bereinigt; zweimal
  zurückgeschoben → die App ließ sie beide Male stehen (vorher: jeder Sync ein Schreibzugriff).
- Echo-Heilung: verdrängter Zustand kehrt zurück → genau einmal wiederhergestellt; erneut
  zurückgeschoben → akzeptiert. Ledger zeigt danach `answered = 1`.
- 237 Tests grün, davon 17 neue für die Regel und ihre Persistenz.

### Nachtrag desselben Tages: „einmal" war zu wenig

Die erste Fassung beantwortete jeden Zustand genau einmal und gab danach nach. Am realen
Board hieß das: Die Karte steht dauerhaft falsch, sobald ein fremdes Programm dagegenhält —
und damit wäre Glass Kanban neben Fantastical, der Erinnerungen-App oder einer
Automatisierungs-Brücke unbrauchbar. Zwei Korrekturen daran:

1. **Aus „einmal" wurde ein Takt.** Die Entscheidung wird wiederhergestellt, wann immer
   jemand sie rückgängig macht, höchstens einmal alle 10 Minuten je Karte. Der Sturm bleibt
   ausgeschlossen (eine Antwort je Takt statt eine je Refresh), der Widerspruch nicht.
2. **Der Täter der Verdrängung ist egal.** Ein Live-Test deckte auf, dass die Heilung nur
   die *eigenen* Züge des Boards kannte: Der Tag wurde per Skript entfernt (wie von einem
   iPhone), Fantastical schob ihn zurück — und nichts widersprach. Seither bucht der
   Refresh jeden Arbeits-Tag, der irgendwo verschwindet, als Verdrängung. Unbedenklich,
   weil eine Buchung nur zum *Entfernen* eines Tags verwendet werden kann.

Dazu kam ein **Wecker**: Korrekturen laufen nur beim Sync, und ein Zustand, der einfach
falsch bleibt, löst keinen aus — eine vom Takt aufgeschobene Antwort wäre sonst nie
gegeben worden. Auch das fiel erst im Live-Test auf, nicht im Entwurf.

**Verifikation gegen das echte Ticket, mit laufendem Fantastical:** Tag entfernt,
Rückschieber setzte ihn zurück, binnen eines Syncs wieder weg. Danach über 45 Minuten
stabil, obwohl Fantastical um 14:21, 14:22 und 14:37 Uhr weiter schrieb — die Antworten
kamen jeweils so schnell, dass der Tag zwischen zwei Messungen im Zehn-Sekunden-Takt nicht
sichtbar wurde.

**Grenze, die bleibt:** Die App verteidigt die Spaltenzuordnung, nicht die übrigen Daten.
Derselbe Rückschieber setzt auch Notiztexte und Fälligkeiten zurück; das bleibt ein Defekt
der fremden App und gehört dort behoben.

## Verworfen

- **Kaltstart-Raten über Zeitstempel** (Tag freigeben, wenn `completionDate` des
  Durchgangs nach der letzten Tag-Änderung liegt): Das Weiterrollen der Serie setzt
  selbst `lastModifiedDate` neu; es gibt keinen verlässlichen Zeugen. Ohne Beweis keine
  Kartenbewegung — die Restlücke wurde stattdessen anders geschlossen, siehe unten.
- **`eventStore.reset()` bei `EKEventStoreChanged`**: siehe H4.

## Nachtrag, gleicher Tag: Kaltstart-Restlücke geschlossen (`gemessen`)

Die zunächst akzeptierte Restlücke — Abhaken bei geschlossener App lässt den Tag stehen,
weil der „vorige Refresh" als Beweis fehlt — ist ohne Raten geschlossen: Der **Beweis
überlebt den Neustart**. `RecurringTagRelease.Memory` persistiert am Ende jedes Refreshs
die geladenen IDs und die getaggten Karten (ein UserDefaults-Schlüssel,
`tagReleaseMemory`, plist-nativ wie `wipLimits`/`excludedCalendarIDs`); der erste Refresh
nach einem Kaltstart wird damit geseedet, die reine Regel bleibt unverändert. Fehlender,
beschädigter oder fremder Speicher degradiert still zu leer → Verhalten wie zuvor
(fail closed; zugleich der Upgrade-Pfad).

Gemessen gegen echtes iCloud, App-Neustarts per `open`/`pkill`:

- **Positiv:** Serie mit `#next`, der App vor dem Beenden bekannt → extern abgehakt bei
  geschlossener App → Tag im **ersten Refresh nach dem Kaltstart** freigegeben.
- **Negativ:** Tag erst bei geschlossener App gesetzt, dann extern abgehakt → Tag bleibt
  nach dem Start stehen (kein Beweis, keine Freigabe).
- **Stabilität:** zweiter Neustart ohne neue Erledigung → keine weitere Freigabe, kein
  Save-Loop.

Dazu 9 neue reine Tests (`RecurringTagReleaseMemoryTests` + Kaltstart-Szenarien über die
bestehende API), Gesamtsuite grün. Verbleibende, kleinere Restlücke (Hand-getippter Tag
auf anderem Gerät nach externem Abhaken, ununterscheidbar vom überlebenden Tag) in
SPEC.md dokumentiert.

## Messung 10.08.2026: Woran man einen abgelösten Durchgang erkennt

Die Zuordnung „erledigter Durchgang → laufende Serie" lief bis dahin über **Titel + Liste**
und war damit in beide Richtungen falsch: Eine gewöhnliche Aufgabe, die genauso heißt wie
eine Serie, ließ sich nie aus „Erledigt" zurückholen, und ein Umbenennen der Serie nach dem
Erledigen setzte den Schutz komplett außer Kraft.

Die Alternative — das **Anlegedatum** — stand zwar schon im Repo (SPEC.md, Durchlaufzeit),
war aber nur als „alt" gemessen, nie als *exakte Gleichheit* und nie für den extern
abgehakten Weg. Verfahren wie gehabt: iCloud-Scratch-Liste „GK-Messung", eigener Prozess je
Messpunkt (kalter EventKit-Cache), `creationDate` als roher `Double` mit neun
Nachkommastellen — die Frage ist Bit-Gleichheit, nicht ob zwei formatierte Daten gleich
aussehen.

| # | Messpunkt | Ergebnis |
|---|---|---|
| M0 | Fünf Datensätze in **einem** Commit angelegt | Alle fünf `creationDate` verschieden (Abstände im Mikrosekundenbereich). Eine Kollision ist praktisch ausgeschlossen — `gemessen` |
| M1 | Serie über den App-Weg erledigt | Abgelöster Durchgang trägt `808083284.719828010`, die weiterlaufende Serie **denselben Wert bitgenau**. Die IDs unterscheiden sich (`72A4F8DE` vs. `083A8BB1`) — `gemessen` |
| M2 | Nach iCloud-Roundtrip erneut gelesen | Unverändert; keine Rundung, keine Neuvergabe — `gemessen` |
| M4 | Einmalige Aufgabe **mit byte-identischem Titel** erledigt | Behält ihre ID (keine Ablösung) und ihr **eigenes** Anlegedatum (`…719745040`). Damit ist sie von einem Durchgang unterscheidbar — `gemessen` |
| M5 | Serie **nach** dem Erledigen umbenannt | Titel laufen auseinander („Serie A neu" gegen „Serie A"), Anlegedaten bleiben gleich. Genau der Fall, in dem die Titel-Zuordnung versagt — `gemessen` |
| M3 | **Extern abgehakt (iPhone)** | Abgelöster Durchgang `808083284.719773054`, laufende Serie **derselbe Wert bitgenau**. Der Sync stempelt nichts um — `gemessen` |

**Nebenbefund:** `calendarItemExternalIdentifier` taugt nicht als Identität — die abgelöste
Kopie bekommt eine eigene (`72A4F8DE-…` gegen `083A8BB1-…`), und auf lokalen Listen ist das
Feld ohnehin leer (siehe `ReminderDeepLink`).

**Das vorab festgelegte Abbruchkriterium für M3 ist nicht eingetreten.** Wäre vom iPhone ein
frisches Anlegedatum gekommen, hätte der Rückfallplan gegriffen (Titel + Liste +
`Durchgang.angelegt <= Serie.angelegt`) und der Umbenennen-Fall wäre als Restlücke in SPEC
gewandert. Da alle sechs Punkte grün sind, wird die Zuordnung wie entworfen gebaut.

**Fazit:** Das Anlegedatum ist eine Identität, kein Indiz. Es wird auf **Gleichheit**
geprüft, nie auf Nähe — ein Toleranzfenster machte daraus wieder eine Ähnlichkeit, und zwei
kurz nacheinander angelegte Aufgaben würden einander zu Durchgängen erklären (siehe M0:
Mikrosekunden trennen sie). Mehrdeutigkeit fällt zu „kein Beweis": Der Zug aus „Erledigt"
ist dann erlaubt, der Tag bleibt stehen.

### Live-Prüfung der stillen Hälfte (10.08.2026, 22:30–22:38)

Die Tag-Freigabe ist die einzige Regel, die eine Karte bewegt, ohne dass jemand hinsieht —
Unit-Tests allein tragen sie deshalb nicht. Auf der Scratch-Liste, gegen echtes iCloud,
beide Richtungen gefahren:

| Schritt | Erwartet | Beobachtet |
| --- | --- | --- |
| Wochenserie „Waesche" mit `#next` angelegt | Karte in „Als Nächstes" | ✅ 4/5, Herkunft GK-Messung |
| Gleichnamige einmalige Aufgabe extern **angelegt und erledigt** | Tag bleibt | ✅ Erledigt 9→10, Serie unverändert in „Als Nächstes", `notes="#next"` |
| Serie selbst extern abgehakt | Tag binnen eines Syncs weg | ✅ abgelöste Kopie mit dem Anlegedatum der Serie (808086833.731228), danach `notes=""` auf beiden, Karte im Backlog (12→13) |

Die zweite Zeile ist der Fall, den die Titel-Regel falsch entschied: Sie hätte der
gezogenen Karte den Tag entzogen und sie still ins Backlog geschoben.
