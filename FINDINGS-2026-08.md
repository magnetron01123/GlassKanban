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

**Grenze, die bleibt:** Gegen einen dauerhaft aktiven Rückschieber gewinnt die App nicht —
sie hat keinen eigenen Speicher, aus dem sie eine andere Wahrheit behaupten könnte. Sie
beendet den Schreibsturm und zeigt, was in den Daten steht. Die Quelle gehört abgeklemmt.

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
