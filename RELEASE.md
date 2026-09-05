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
> und Marktrecherche (Quellen am Ende). Er ersetzte einen älteren Abschnitt
> „Veröffentlichung" vom 21.07., dessen Punkte hier aufgegangen sind — „private API
> entfernen" ist seit `4f83347` erledigt. Der zugehörige Branch wurde am 14.08.2026
> gelöscht.

---

## Statusübersicht

| # | Phase | Aufwand | Status |
|---|---|---|---|
| 0 | Apple Developer Program + App Store Connect | S (wartezeitgetrieben) | ☐ offen — **blockiert inzwischen weit mehr als den Store, siehe unten** |
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

**Der Hebel ist seit dem 14.08.2026 größer als beim Aufstellen dieses Plans.** Phase 0 ist
nicht mehr nur die Eintrittskarte zum Store, sondern die Voraussetzung für jede Funktion,
die ein Entitlement braucht. Gemessen, damit es nicht erneut geprüft wird:

| Vorhaben | Ohne Developer Program |
|---|---|
| Gerätesynchronisation (`NSUbiquitousKeyValueStore`) | **unmöglich** — der Prozess wird beim Start per SIGKILL beendet |
| App-Group-Container, und damit Widget, Live Activity, App Intents | macOS *erlaubt* es, aber Xcode verweigert den Build ohne Provisioning Profile |
| Signing, TestFlight, Einreichung | unmöglich (Phasen 2, 4, 5) |

Die Grundlagen für die Synchronisation liegen fertig in `main` (BACKLOG.md,
„Gerätesynchronisation über iCloud") — es fehlt ausschließlich die Übertragung, und die
hängt an diesem Punkt.

- [ ] Anmeldung als Einzelperson auf developer.apple.com (99 $/Jahr; Identitätsprüfung
      dauert 1–3 Tage — deshalb Schritt 1)
- [ ] Nach Freischaltung: **Small Business Program** beantragen → 15 % statt 30 % Provision
- [ ] App in App Store Connect anlegen; **Namensverfügbarkeit „Glass Kanban" prüfen**
      (falls belegt, früh Alternativen entscheiden, z. B. „GlassKanban — Reminders Board")

## Phase 1 — Lokalisierung DE + EN (der einzige harte technische Blocker)

Erledigt am 07.08.2026: Englisch ist Entwicklungssprache (Quell-Literale im Code),
Deutsch vollwertige Lokalisierung in `Localizable.xcstrings`/`InfoPlist.xcstrings`;
`project.yml` trägt `developmentLanguage: en` und `CFBundleLocalizations: [en, de]`. Das
gebaute Verhalten steht in SPEC.md („App"), die Arbeitsregeln für den Katalog samt der
beiden Fehlerbilder, aus denen `scripts/check-localization.py` entstand, in CLAUDE.md
(„Localizable.xcstrings").

Verifiziert 07./08.08.2026: Suite grün; Katalog skriptgeprüft (Vollständigkeit,
Übersetzung, Plurale); beide Sprachen live durchgeklickt ohne Abschneidung oder
Umbruch; Standardmenüs folgen der Sprache; Datums- und Zahlenformate folgen der
Systemregion (Plattformverhalten, kein Fehler).

**Noch offen:** VoiceOver-Stichprobe in beiden Sprachen an einer Karte und einem
Spaltenkopf (dort sitzen die aus Fragmenten zu ganzen Sätzen umgebauten Labels).

## Phase 2 — Signing & Distribution (nach Phase 0, parallel zu 1 vorbereitbar)

- [ ] project.yml: `DEVELOPMENT_TEAM` eintragen, `CODE_SIGN_STYLE: Automatic` für
      Release (Debug kann auf der lokalen Identity bleiben); Bundle-ID
      `com.davidtrogemann.GlassKanban` in App Store Connect registrieren
- [ ] **TCC-Folge einplanen:** Neue Signatur-Identität → macOS fragt die
      Reminders-Berechtigung einmal neu ab (einmalig; warum bisher selbstsigniert,
      erklärt der Kommentar an `CODE_SIGN_IDENTITY` in project.yml)
- [ ] Archive/Upload über Xcode Organizer (`*.xcarchive` steht bereits in `.gitignore`)
- [ ] Hardened Runtime **nicht** anfassen — für den MAS zählt die Sandbox (✓),
      Hardened Runtime gehört zu Notarisierung/Direktvertrieb
- [ ] **Deep-Link entfernen:** undokumentiertes Schema
      `x-apple-reminderkit://REMCDReminder/…` (ReminderDeepLink.swift, geöffnet in
      RemindersStore) → für 1.0 raus, der In-App-Editor deckt Bearbeiten ab, Fallback
      `openRemindersApp()` bleibt. Review-Risiko damit null statt „vermutlich okay".
      Das Systemeinstellungs-Schema in ContentView bleibt (verbreitet, geringes
      Risiko). README-Abschnitt „Hinweise" dazu anpassen.
      **Es ist genau eine Stelle** — seit dem 14.08.2026. Bis dahin gab es eine zweite,
      die hier nicht verzeichnet war: `EmptyBoardNotice` öffnete die Erinnerungen-App
      über dasselbe Schema und hätte es nach dieser Aufräumung weiter mit ausgeliefert.
      Sie ruft jetzt `openRemindersApp()` auf, das denselben Zweck über dokumentierte API
      erfüllt. **Vor dem Abhaken dieses Punktes `grep -rn "x-apple-reminderkit"` laufen
      lassen**, nicht der Aufzählung vertrauen

**Verifikation Phase 2:** Archive-Build aus dem Store-Profil startet, Berechtigung
wird neu erteilt, alle Kernflüsse laufen sandboxed.

## Phase 3 — Store-Auftritt & Pflichtseiten

- [ ] Minimale Website (GitHub Pages reicht): Produktseite, **Datenschutzerklärung**
      („verarbeitet ausschließlich lokal, keine Datenerhebung" — deckungsgleich mit
      dem Privacy-Manifest), Support-Kontakt. Privacy-Policy- und Support-URL sind
      Pflichtfelder in App Store Connect
- [x] Demo-Datensatz als eigene Reminders-Liste bauen — 05.09.2026, siehe `social/linkedin/konzept.md` 2.1 und `seed-demo-reminders.swift` v2 (glaubwürdige, freundliche
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
- [ ] **Migration der Spalten (13.08.2026) bei einem Tester beobachten:** Beim ersten Start
      die Alt-Tags übernehmen lassen und prüfen, dass (a) jede Karte in ihrer Spalte steht,
      (b) die Tags danach aus den Notizen verschwunden sind, (c) sonst kein Notiztext
      angefasst wurde. Auf dem Entwicklungsrechner am 13./14.08.2026 so gemessen.
      **Bewusst an die Beta delegiert:** Es steht kein zweiter Mac zur Verfügung
      (Stand 14.08.2026), ein Tester ist also der einzige Weg zu diesem Nachweis
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
| 26.07.2026 | **Tag-Format wird englisch** (`#next`/`#inprogress`), deutsche Tags werden Legacy — *überholt 13.08.2026: es gibt keine Tags mehr, nur die einmalige Migration liest sie* | Tags sind sichtbares Datenformat in den Notizen internationaler Kunden |
| 26.07.2026 | Deep-Link `x-apple-reminderkit://` wird für 1.0 **entfernt** | Undokumentiertes Schema = Review-Risiko; In-App-Editor macht ihn verzichtbar, Fallback bleibt |
| 26.07.2026 | CI ist **kein Launch-Blocker** | Solo-Entwickler mit lokaler Suite; optional nach Launch (macOS-26-Runner-Lage dann prüfen) |

## Bewusst nicht in 1.0

Setapp (Intel-Binary nötig; nach MAS-Launch prüfen) · Direktvertrieb/Notarisierung/
Sparkle · weitere Sprachen (1.1) · iOS-App (eigene Ausbaustufe, BACKLOG.md) · CI.

## Zeitrahmen

Der Sieben-Wochen-Plan vom 26.07.2026 ist am 14.08.2026 **ersatzlos entfernt** worden: Er
sah Phase 0 in Woche 1 und die Einreichung in Woche 7 vor, während in Woche 3 tatsächlich
Phase 1 fertig und Phase 0 nicht angestoßen war. Ein Plan, der die Wirklichkeit nicht mehr
beschreibt, wird nicht ehrlicher, wenn man ihn stehen lässt — er wird nur zur Ausrede.

Es gibt keinen Ersatzplan. Die Reihenfolge ergibt sich aus der Statusübersicht oben, und
das Tempo aus dem, was ein Hobbyprojekt hergibt. Der einzige Punkt mit echter Wartezeit
bleibt Phase 0 (Identitätsprüfung 1–3 Tage) — und der ist deshalb zuerst dran.

## Quellen (Recherche 26.07.2026)

- [GoodTask Preise](https://goodtaskapp.com/) · [GoodTask Board-View](https://www.macstories.net/ios/goodtask-6-4-brings-kanban-style-board-view-for-reminders-lists-and-smart-lists/)
- [Indie-Kanban-Pricing](https://goodguyapps.com/blog/best-kanban-app-mac-2026/) · [Mac-Productivity-Markt 2026](https://rize.io/blog/best-mac-productivity-apps-2026)
- [Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/) · [RevenueCat-Guide](https://www.revenuecat.com/blog/engineering/small-business-program)
- [Setapp Revenue-Modell](https://docs.setapp.com/docs/setapp-membership-revenue) · [Setapp App-Anforderungen](https://docs.setapp.com/docs/preparing-your-application-for-setapp)
- [MAS-Screenshot-Spezifikationen](https://screenshotbro.app/blog/mac-app-store-screenshot-sizes) · [Launch-Checkliste](https://www.applaunchflow.com/blog/app-launch-checklist-2026)
- [Notarisierung nur außerhalb des MAS](https://keylight.dev/blog/launch-mac-app-outside-app-store/)
