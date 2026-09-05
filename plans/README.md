# Pläne — Bauanleitungen für Vorhaben

Eine Datei pro Vorhaben, geschrieben **nach** der Entscheidung und **vor** dem Bauen. Sie
ist für eine eigene Session gedacht, auch mit einem kleineren Modell: Wer sie liest, soll
das Vorhaben umsetzen können, ohne diese Entscheidung noch einmal zu führen.

## Was ein Plan ist — und was nicht

- **Plan:** Schrittfolge, betroffene Dateien, Code-Skizzen, Befehle, Messpunkte,
  Abnahmekriterien, Doku-Pflichten. Konkret genug, dass jeder Schritt einzeln geprüft
  werden kann.
- **Nicht der Plan:** das Warum (steht in BACKLOG.md/CONCEPT.md, der Plan verweist
  darauf) und das gebaute Verhalten (das steht danach in SPEC.md).

## Lebensdauer

1. **Anlegen**, sobald eine Idee in BACKLOG.md entschieden ist. Der BACKLOG-Eintrag
   bekommt einen Verweis auf den Plan.
2. **Abhaken** während des Bauens — die Kästchen im Plan sind der Arbeitsstand. Messungen
   werden **im Plan** protokolliert (Datum, Ergebnis), nicht nur im Kopf.
3. **Löschen**, wenn das Vorhaben in `main` ist: Das Verhalten steht dann in SPEC.md
   (und README.md, wenn nutzersichtbar), der BACKLOG-Eintrag ist als umgesetzt markiert,
   CLAUDE.md kennt die neuen Dateien. Git behält die Geschichte des Plans.

Ein Plan, der länger als das Vorhaben lebt, ist Drift — dieselbe Regel wie für Branches
(CLAUDE.md, „Branches nicht liegen lassen").

## Aufbau eines Plans

```
# <Vorhaben> — Bauplan (<Datum>)
Zuerst lesen        — welche Abschnitte welcher Dokumente, in dieser Reihenfolge
Ziel / Nicht-Ziel   — in je drei Sätzen
Schritt 0: Messen   — was vor der ersten Codezeile geprüft wird, mit Entscheidungsweiche
Schritte 1…n        — je: Dateien, Skizze, Prüfung, Kästchen
Doku-Pflichten      — welche Datei welchen Absatz bekommt
Abnahme             — was der Nutzer selbst prüft, was der Lauf hinterlassen muss
Messprotokoll       — leer angelegt, während des Bauens gefüllt
```

Hinweis zum Doku-Wächter: `scripts/doc-guard.sh` zählt nur die `.md`-Dateien im
Projektstamm. Eine Änderung hier befriedigt ihn absichtlich nicht — ein Plan ist kein
Verhaltensnachweis, SPEC.md ist es.
