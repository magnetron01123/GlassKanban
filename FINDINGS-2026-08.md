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

## Verworfen

- **Kaltstart-Raten über Zeitstempel** (Tag freigeben, wenn `completionDate` des
  Durchgangs nach der letzten Tag-Änderung liegt): Das Weiterrollen der Serie setzt
  selbst `lastModifiedDate` neu; es gibt keinen verlässlichen Zeugen. Ohne Beweis keine
  Kartenbewegung — Restlücke stattdessen in BACKLOG.md dokumentiert.
- **`eventStore.reset()` bei `EKEventStoreChanged`**: siehe H4.
