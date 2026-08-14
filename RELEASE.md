# Glass Kanban — Release-Fahrplan zum Mac App Store

Dieses Dokument ist der **lebende Arbeitsstand** auf dem Weg vom persönlichen Werkzeug
zur verkäuflichen App: Erledigtes wird abgehakt und datiert, Entscheidungen wandern in
den Entscheidungslog unten, und was sich als Ist-Verhalten der App niederschlägt, zieht
nach der Umsetzung wie immer nach SPEC.md um. BACKLOG.md verweist hierher; es gibt nur
diese eine Wahrheit zum Release.

**Arbeitsweise:** Jede Arbeitssitzung am Release beginnt mit einem Blick auf die
Statusübersicht. Ein Punkt gilt erst als erledigt, wenn seine Verifikation (unten je
Phase) gelaufen ist — nicht, wenn der Code geschrieben ist.

> Herkunft: Plan vom 26.07.2026, erarbeitet aus zwei vollständigen Repo-Audits
> (Projektkonfiguration, Entitlements, Privacy, Lokalisierungs-Umfang, Store-Risiken)
> und Marktrecherche (Quellen am Ende). Ersetzt den Abschnitt „Veröffentlichung" vom
> Branch `feature/backlog-release-readiness` (21.07.), der damit obsolet ist — dessen
> Punkt „private API entfernen" ist seit `4f83347` erledigt, die übrigen Punkte sind
> hier aufgegangen.

---

## Statusübersicht

| # | Phase | Aufwand | Status |
|---|---|---|---|
| 0 | Apple Developer Program + App Store Connect | S (wartezeitgetrieben) | ☐ offen |
| 1 | Lokalisierung DE + EN (String Catalog) | **L — der Brocken** | ☑ erledigt 07.08.2026 (bis auf VoiceOver-Stichprobe) |
| 2 | Signing & Distribution | M | ☐ offen — braucht Phase 0 |
| 3 | Store-Auftritt, Website, Screenshots | M | ☐ offen |
| 4 | TestFlight-Beta & Härtung | M | ☐ offen — braucht 1+2 |
| 5 | Einreichung & Launch | S | ☐ offen — braucht alles |

**Bereits erledigt (vor diesem Plan, verifiziert im Audit 26.07.):** App Sandbox +
Kalender-Entitlement, PrivacyInfo.xcprivacy (UserDefaults/CA92.1 plus die eigene
Datei `columns.json` im Container — nicht deklarationspflichtig), Purpose-String
mit Schreibzugriff-Begründung, App-Kategorie, Versionierung 1.0.0/1,
Export-Compliance-Key, Copyright, keine private API/Reflection (seit `4f83347`),
Login-Item nur opt-in, kein Netzwerkcode, keine Dependencies.

---

## Phase 0 — Apple Developer Program (zuerst anstoßen, Rest läuft parallel)

- [ ] Anmeldung als Einzelperson auf developer.apple.com (99 $/Jahr; Identitätsprüfung
      dauert 1–3 Tage — deshalb Schritt 1)
- [ ] Nach Freischaltung: **Small Business Program** beantragen → 15 % statt 30 % Provision
- [ ] App in App Store Connect anlegen; **Namensverfügbarkeit „Glass Kanban" prüfen**
      (falls belegt, früh Alternativen entscheiden, z. B. „GlassKanban — Reminders Board")

## Phase 1 — Lokalisierung DE + EN (der einzige harte technische Blocker)

Ist-Zustand (Audit): keinerlei Lokalisierungs-Infrastruktur; ~214 deutsche Literale in
16 Dateien (StatsPopover 31, CardView 31, TicketEditSheet 28, Models 25,
RemindersStore 22, ColumnView 19, BoardView 14, Rest kleiner), davon 17 mit
Interpolation; `CFBundleDevelopmentRegion: de` in project.yml.

**Architektur:** Englisch wird Entwicklungssprache (Quell-Literale im Code →
englisch), Deutsch wird vollwertige Lokalisierung im String Catalog. Begründung: Die
Fallback-Sprache für alle nicht übersetzten Märkte muss Englisch sein.

- [x] `Localizable.xcstrings` + `InfoPlist.xcstrings` angelegt; project.yml:
      `developmentLanguage: en`, `CFBundleDevelopmentRegion: en`,
      `CFBundleLocalizations: [en, de]` (07.08.2026 — Projekt wird von XcodeGen
      generiert, Änderungen nur in project.yml)
- [x] Alle 16 Dateien migriert (07.08.2026); Nicht-View-Strings (Fehlertitel in
      RemindersStore, Anzeigenamen in Models) explizit über `String(localized:)`,
      View-Captions über `LocalizedStringKey`-Parameter (`fieldCaption`, `factRow`,
      `filterRow`, `row`)
- [x] Deutsche Übersetzungen im Katalog — 158 Einträge, die heutigen Texte sind die
      Übersetzung (07.08.2026)
- [x] `GermanPlural` (Models.swift) ersatzlos aufgelöst → echte
      `variations.plural`-Einträge im Katalog für die sieben Strings, die es
      grammatisch brauchen (Karten/Tage/Aufgaben/Listen/Streak-Sätze); die übrigen
      interpolierten Strings sind strukturell nie Singular oder inhaltlich invariant
      (07.08.2026)
- [x] Tests umgestellt: `GermanPluralTests` entfernt, `StatusTaggerTests` auf
      `#next`/`#inprogress` als Kanonik + deutsche Formen als Legacy umgeschrieben;
      volle Suite grün bis auf zwei vorbestehende, unabhängige `BacklogFoldTests`
      (Datumsfixtur, an anderer Stelle zur Behebung vorgemerkt) (07.08.2026)
- [x] **Überholt am 13.08.2026:** Die Spalte steht seither nicht mehr in den Notizen,
      sondern in `columns.json` (SPEC.md, „Spalten = eigener Speicher der App"). Die
      Tag-Formen unten sind nur noch Lesestoff der einmaligen Migration — der Punkt
      bleibt als Historie stehen.
- [x] **Tag-Migration:** kanonisch `#next`/`#inprogress`; `#alsnächstes`/
      `#inbearbeitung` (+ Umlaut-/Kurzvarianten) in der Legacy-Migrationsliste in
      StatusTagger.swift (07.08.2026)
- [x] SPEC.md nachgezogen: Hashtag-Tabelle, Lese-/Schreibregeln, Migrationstabelle
      (07.08.2026)

**Verifikation Phase 1 — abgeschlossen 07.08.2026:**

- Build und Testsuite grün (188 Tests, `xcodebuild … test`, derivedDataPath
  außerhalb iCloud)
- **Katalog skriptgeprüft**, nicht per Augenmaß — inzwischen versioniert als
  `scripts/check-localization.py`: Vollständigkeit gegen jede
  `String(localized:)`/`LocalizedStringKey`-Stelle, `en`+`de` im Zustand
  `translated`, und **Pluralregel für jeden Zähler**. Der erste Durchgang fand
  vier fehlende Schlüssel (`Notes`, `Refresh`, `Yesterday` und eine
  Anführungszeichen-Abweichung, gerade `"` gegen typografische `“ ”`).
- **Nachträglich beim Review der englischen Texte gefunden (08.08.2026):** Der
  erste Prüflauf prüfte nur *Vollständigkeit*, nicht *Korrektheit* — und dabei
  waren beim Auflösen von `GermanPlural` **fünf Pluralregeln verloren
  gegangen**. „1 Aufgaben gerade in Bearbeitung", „Folge: 1 Tage" und drei
  weitere waren zurück, also ein Fehlerbild, das im Juli 2026 schon einmal behoben
  hatte; die Streak-Pille stand beim Review selbst auf 1. Behoben durch echte
  `variations.plural` in beiden Sprachen (bzw. einen zahl-neutral formulierten
  Satz), und die Plural-Prüfung ist seither Teil des Skripts. **Lehre:
  Vollständigkeit sagt nichts über Korrektheit** — eine Prüfung, die nur zählt,
  ob ein Schlüssel existiert, übersieht, ob er das Richtige sagt.
- **Beide Sprachen live durchgeklickt** (`-AppleLanguages (en)`/`(de)`): Board,
  Karten-Editor, Finden-Popover, Statistik in beiden Registern, Einstellungen in
  beiden Reitern, Board-Menü. Keine Textabschneidung, kein Umbruch, kein
  gesprengtes Layout — auch nicht an den drei Fakten-Bedienelementen mit fester
  180-pt-Breite, an den einzeiligen Leer-Sätzen oder an der Einstellungs-Fußnote.
  Beide Statistik-Register bleiben gleich hoch (SPEC-Regel gehalten).
- **Standard-Menüs folgen der Sprache** (Bearbeiten/Darstellung/Fenster/Hilfe
  gegen Edit/View/Window/Help) — `CFBundleLocalizations` wirkt wie gewollt.
- **Sprache und Region sind sauber getrennt:** Datums- und Zahlenformate folgen
  weiterhin der Systemregion (`1,8 Tage` auch in englischer Oberfläche),
  Wochentagsnamen der Sprache (`Montag`/`Monday`). Das ist das
  Plattformverhalten, kein Fehler.
- **Tag-Konvergenz beobachtet:** Das Board stand über mehrere App-Neustarts
  hinweg unverändert in denselben Spalten (3/5 „Als Nächstes", 0/3 „In
  Bearbeitung") — die Migration hat die Status erhalten, und es läuft keine
  Schreibschleife. Der literale Notiztext in der Erinnerungen-App wurde nicht
  inspiziert; die Konvergenz selbst ist unit-getestet.

**Noch offen:** VoiceOver-Stichprobe in beiden Sprachen an einer Karte und einem
Spaltenkopf (dort sitzen die aus Fragmenten zu ganzen Sätzen umgebauten Labels).

## Phase 2 — Signing & Distribution (nach Phase 0, parallel zu 1 vorbereitbar)

- [ ] project.yml: `DEVELOPMENT_TEAM` eintragen, `CODE_SIGN_STYLE: Automatic` für
      Release (Debug kann auf der lokalen Identity bleiben); Bundle-ID
      `com.davidtrogemann.GlassKanban` in App Store Connect registrieren
- [ ] **TCC-Folge einplanen:** Neue Signatur-Identität → macOS fragt die
      Reminders-Berechtigung einmal neu ab (einmalig; warum bisher selbstsigniert,
      erklärt der Kommentar in project.yml:56–58)
- [ ] Archive/Upload über Xcode Organizer; `.gitignore` um `*.xcarchive` ergänzen
- [ ] Hardened Runtime **nicht** anfassen — für den MAS zählt die Sandbox (✓),
      Hardened Runtime gehört zu Notarisierung/Direktvertrieb
- [ ] **Deep-Link entfernen:** undokumentiertes Schema
      `x-apple-reminderkit://REMCDReminder/…` (ReminderDeepLink.swift, geöffnet in
      RemindersStore) → für 1.0 raus, der In-App-Editor deckt Bearbeiten ab, Fallback
      `openRemindersApp()` bleibt. Review-Risiko damit null statt „vermutlich okay".
      Das Systemeinstellungs-Schema in ContentView bleibt (verbreitet, geringes
      Risiko). README-Abschnitt „Hinweise" dazu anpassen

**Verifikation Phase 2:** Archive-Build aus dem Store-Profil startet, Berechtigung
wird neu erteilt, alle Kernflüsse laufen sandboxed.

## Phase 3 — Store-Auftritt & Pflichtseiten

- [ ] Minimale Website (GitHub Pages reicht): Produktseite, **Datenschutzerklärung**
      („verarbeitet ausschließlich lokal, keine Datenerhebung" — deckungsgleich mit
      dem Privacy-Manifest), Support-Kontakt. Privacy-Policy- und Support-URL sind
      Pflichtfelder in App Store Connect
- [ ] Demo-Datensatz als eigene Reminders-Liste bauen (glaubwürdige, freundliche
      Beispiel-Tickets für Screenshots und Review)
- [ ] Screenshots EN + DE, je 4–6, 2880×1800 PNG: Board, Karten-Editor,
      Statistik-Fenster, Dunkelmodus
- [ ] Listing-Texte EN + DE: Kurzbeschreibung, Feature-Liste, Keywords (kanban,
      reminders, board, tasks, personal kanban, wip limit …); Nutrition-Label
      „Data Not Collected"
- [ ] Preis anlegen: **9,99 € Einführungspreis**, Zielpreis 14,99 € nach Etablierung
- [ ] Review-Notizen vorformulieren: warum Vollzugriff auf Erinnerungen
      (Kernfunktion), kein Konto/Netz, Hinweis auf Demo-Liste

## Phase 4 — TestFlight-Beta & Härtung

- [ ] TestFlight für macOS einrichten; 5–10 Tester (Freunde/Familie + 2–3 Fremde,
      z. B. über r/macapps)
- [ ] Gezielt testen, was nie mit Echtdaten lief: **wiederkehrende Erinnerungen beim
      Abhaken** (inkl. Alarm-Mitführung, SPEC.md „Weckzeiten folgen dem Fälligkeitsdatum",
      und Wiederkehrer-Ablehnung, SPEC.md „Wiederkehrende Aufgaben lassen sich nicht aus
      Erledigt zurückholen"), Drag & Drop mit WIP-Rückfrage, englische UI vollständig. Das
      externe Abhaken gezogener Wiederkehrer ist seit 09.08.2026 gemessen und abgedeckt
      (`RecurringTagRelease`, SPEC.md „Extern abgehakt") — in der Beta bleibt zu
      bestätigen, dass die Freigabe im Alltag zuverlässig greift. Der frühere Punkt
      „auch auf fremden Boards" ist seit dem Formwechsel vom 13.08.2026 gegenstandslos:
      Die Spalte liegt je Mac in der eigenen `columns.json`, ein fremdes Board hat gar
      keinen Zustand freizugeben
- [ ] **Migration der Spalten (13.08.2026) auf einem zweiten Rechner beobachten:** Beim
      ersten Start die Alt-Tags übernehmen lassen und prüfen, dass (a) jede Karte in ihrer
      Spalte steht, (b) die Tags danach aus den Notizen verschwunden sind, (c) sonst kein
      Notiztext angefasst wurde. Auf dem Entwicklungsrechner am 13./14.08.2026 so gemessen
- [ ] Mindestens ein Tester mit englischem System, einer mit wiederkehrenden
      Erinnerungen samt Alarmen
- [ ] Kriterium für Einreichung: eine crash-freie Beta-Woche

## Phase 5 — Einreichung & Launch

- [ ] Einreichen mit Review-Notizen; mit einer Ablehnungsrunde rechnen (üblich)
- [ ] Launch-Kommunikation klein und ehrlich: Product Hunt, r/macapps,
      MacStories-Tipp, deutsche Mac-Blogs/Podcasts; Presseseite auf der Website
- [ ] Nach Launch: Reviews beantworten, Crash-Reports in App Store Connect beobachten

---

## Entscheidungslog

| Datum | Entscheidung | Begründung |
|---|---|---|
| 26.07.2026 | **Einmalkauf 9,99–14,99 €**, kein Abo, kein Freemium | Passt zur Positionierung (lokal, kein Konto); Markt: GoodTask 39,99 $ einmalig, Indie-Kanban ~15 $; „kein Abo" ist in der Nische ein Verkaufsargument |
| 26.07.2026 | Vertrieb **nur Mac App Store** für 1.0 | Zahlungsabwicklung/Updates/Vertrauen inklusive; Setapp erst nach Launch prüfen (verlangt Intel-Binary); Direktvertrieb wäre eigener Aufwandsblock |
| 26.07.2026 | Sprachen 1.0: **Deutsch + Englisch**, Englisch als Entwicklungssprache | Internationaler Markt trägt die Nische; Fallback für alle übrigen Länder muss Englisch sein |
| 26.07.2026 | **Tag-Format wird englisch** (`#next`/`#inprogress`), deutsche Tags werden Legacy | Tags sind sichtbares Datenformat in den Notizen internationaler Kunden; Migrationsmechanismus existiert und ist getestet |
| 26.07.2026 | Deep-Link `x-apple-reminderkit://` wird für 1.0 **entfernt** | Undokumentiertes Schema = Review-Risiko; In-App-Editor macht ihn verzichtbar, Fallback bleibt |
| 26.07.2026 | CI ist **kein Launch-Blocker** | Solo-Entwickler mit lokaler Suite; optional nach Launch (macOS-26-Runner-Lage dann prüfen) |

## Bewusst nicht in 1.0

Setapp (Intel-Binary nötig; nach MAS-Launch prüfen) · Direktvertrieb/Notarisierung/
Sparkle · weitere Sprachen (1.1) · iOS-App (eigene Ausbaustufe, BACKLOG.md) · CI.

## Grober Zeitrahmen (Hobby-Tempo)

| Woche | Inhalt |
|---|---|
| 1 | Phase 0 anstoßen; Lokalisierungs-Infrastruktur + erste Dateien |
| 2–3 | Lokalisierung fertig inkl. Tests und Tag-Migration |
| 4 | Signing, Deep-Link-Entfernung, Website, Screenshots, Listing |
| 5–6 | TestFlight-Beta, Härtung |
| 7 | Einreichung; Puffer für die Review-Runde |

## Quellen (Recherche 26.07.2026)

- [GoodTask Preise](https://goodtaskapp.com/) · [GoodTask Board-View](https://www.macstories.net/ios/goodtask-6-4-brings-kanban-style-board-view-for-reminders-lists-and-smart-lists/)
- [Indie-Kanban-Pricing](https://goodguyapps.com/blog/best-kanban-app-mac-2026/) · [Mac-Productivity-Markt 2026](https://rize.io/blog/best-mac-productivity-apps-2026)
- [Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/) · [RevenueCat-Guide](https://www.revenuecat.com/blog/engineering/small-business-program)
- [Setapp Revenue-Modell](https://docs.setapp.com/docs/setapp-membership-revenue) · [Setapp App-Anforderungen](https://docs.setapp.com/docs/preparing-your-application-for-setapp)
- [MAS-Screenshot-Spezifikationen](https://screenshotbro.app/blog/mac-app-store-screenshot-sizes) · [Launch-Checkliste](https://www.applaunchflow.com/blog/app-launch-checklist-2026)
- [Notarisierung nur außerhalb des MAS](https://keylight.dev/blog/launch-mac-app-outside-app-store/)
