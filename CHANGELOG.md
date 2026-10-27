# Changelog

## Unreleased
- **Reichsfenster (HRE) kompakt:** Kurfürsten in drei Spalten (Flagge → Stimme), Mitglieder, deine Stimmen,
  Autorität und Rückhalt als Kacheln. Beschlossene und spätere Reformen stehen je in einer Kachel (Details im
  Tooltip), nur die nächste Reform wird ausgeschrieben. Etwa 40 % kürzer.
- **Drei Speicherplätze:** „Speichern“ im Menü bietet drei Plätze, „Laden“ zeigt dazu den Autosave, jeweils mit
  Nation und Datum. Das Startmenü hat „Laden“, sobald ein Platz belegt ist. Der Autosave überschreibt keine
  manuellen Stände mehr.
- **Berater mit Stufen ⭐:** Berater starten auf Stufe 1 und lassen sich bis Stufe 3 fördern (Kosten: 1,5× bzw. 3×
  Ernennungskosten in ihrer Punkteart). Jede Stufe steigert ihre Vorteile um 50 %, Nachteile bleiben gleich. Gewöhnliche
  Berater gehen nach 20+ Dienstjahren irgendwann in den Ruhestand; ein Schüler übernimmt eine Stufe tiefer. Ein Klick
  auf „Fördern“ im Hof zeigt Stufe, Dienstzeit und die nächste Stufe. Die KI fördert gelegentlich.
- **Karte nach Süden und Osten erweitert (67 neue Provinzen):** Anatolien, Kaukasus, Levante, Ägypten und die
  ganze nordafrikanische Küste bis Marokko, dazu Kreta, Zypern und Rhodos. 15 neue Länder im Stand von 1444:
  Karaman, Candar, Dulkadir, Trapezunt, Aq Qoyunlu, Qara Qoyunlu (Täbris), Georgien, Schirwan, Tscherkessien,
  Mamluken, Hafsiden (Tunis), Tlemcen, Marokko, Zypern und die Johanniter auf Rhodos. Die Osmanen besitzen jetzt
  auch Westanatolien. Neue Märkte in Alexandria, Tunis und Täbris; Taurus, Kaukasus und Atlas auf der Karte.
- **Browser-Version (neu):** Jedes Release enthält jetzt `RiseOfEU-web.zip`, das Spiel läuft damit direkt im
  Browser, auch eingebettet in andere Seiten. Spielstände bleiben im Browser gespeichert.

## v0.9.1 – 2026-10-27
- **Weitere Fenster entschlackt:** Kartenmodi und Rangliste stehen in zwei Spalten (Details im Tooltip), offene
  Missionen zeigen nur ihre Bedingungen (Belohnung im Tooltip, die ersten fünf sichtbar), lange Diplomatiegruppen
  starten zugeklappt, Kurfürsten zeigen kurz „BOH → HAB“.
- **18 Ereignisse zu Großprojekten, Hoffesten und Heiraten:** Berühmte Baumeister und Steinfunde beschleunigen
  deine Baustelle, jedes fertige Großprojekt bringt ein eigenes Ereignis (Domweihe, Kadetten der Kriegsakademie,
  Hochbetrieb an der Börse ...). Nach einem Hoffest gibt es Duelle, Dichter und plaudernde Gesandte, und
  verschwägerte Höfe schicken Geschenke oder bitten um Hilfe.
- **Friedensfenster kompakt:** Kacheln für Kriegspunkte, Forderung und Integrationskosten. Die besetzten Provinzen
  stehen nach Besitzer sortiert als Kacheln im Raster (antippen = auswählen), die Aktionen in zwei Spalten.
- **Neues Startmenü:** Schwierigkeit als vier Knöpfe (Erklärung im Tooltip), Nationen im Raster. Antippen zeigt
  den Nationalgeist, gestartet wird mit „Los geht's“. Alles passt ohne Scrollen auf einen Bildschirm. Das Menü im
  Spiel ist ebenfalls kompakter.
- **Klügere Kriegserklärungen:** Die KI rechnet nur noch Verbündete ein, die wirklich mitkämpfen (früher zählten auch Freunde des Gegners), und zieht bei historischen Kriegsereignissen nur in aussichtsreiche Kriege. Die KI verliert nur noch etwa 4 % statt 13 % ihrer Angriffskriege; es gibt etwas weniger Kriege, Revolten und Bankrotte.
- **💡 Ratgeber (neu):** Ein neuer Reiter links zeigt mit einer Zahl, wie viel gerade zu tun ist: drohende
  Aufstände, Schulden, Koalitionen, erfüllte Missionen, lohnender Frieden, Technologie und Regierung, freie Händler,
  Gold für Gebäude, sich stauende Macht, freie Missionare und das Hoffest. Jeder Eintrag führt direkt dorthin.
- **Zeitalter-Ziele 🏆 (neu):** Jedes der vier Zeitalter (Renaissance, Entdeckungen, Reformation, Absolutismus) hat
  drei Ziele, etwa 10 Technologien, eine Kompanie auf Stufe 3, 90 % Glaubenseinheit oder alle Staatsreformen. Ein
  Ziel zählt nur in seinem Zeitalter und gibt dauerhaft einen Bonus. Zwei von drei bringen den Triumph des Zeitalters
  (z. B. Renaissancefürst: +0,5 Verwaltung/Monat). Der 🏆-Knopf im Technologie-Fenster zeigt Fortschritt und
  Belohnungen. Die KI verfolgt die Ziele ebenfalls.
- **Noch weniger Scrollen:** Armee-, Kriegs- und Reichsfenster zeigen ihre Werte als Kacheln, Befehle stehen im
  Raster. Das Armeefenster passt jetzt auf einen Bildschirm. Im Reichsfenster sind erledigte und spätere Reformen
  einzeilig (Details im Tooltip), nur die nächste Reform steht ausführlich da. Die Chronik zeigt die
  neuesten zehn Einträge mit Jahreszahl, ältere lassen sich aufklappen.

## v0.9.0 – 2026-10-27
- Die KI gibt überschüssiges Gold im Frieden für Missionare, Hoffeste (gegen Kriegsmüdigkeit) und Großprojekte aus, statt es zu horten.
- Technologiebaum noch kompakter: Jeder Reiter zeigt nur seine eigenen Nationaltechs. Erforschbare stehen oben,
  gesperrte unter dem Baum, sodass die nächsten drei Stufen ohne Scrollen sichtbar sind.
- **Kirchenpolitik wirkt auf den Glauben:** Toleranz senkt die Unruhe durch Andersgläubige um 75 % (die allgemeine
  Unruhe-Senkung halbiert sich dafür). Glaubenseifer lässt Missionare und die natürliche Bekehrung 50 % schneller
  arbeiten, macht Andersgläubige aber unruhiger. Neuer Berater: Hofprediger (schnellere Bekehrung, weniger Glaubensunruhe).
- **Kompaktere Menüs:** Weniger Scrollen. Provinz, Nation, fremde Länder und Waren zeigen ihre Werte jetzt als
  Kacheln im Raster (Details im Tooltip), Aktionen stehen in zwei Spalten. Diplomatie, Missionen, Meilensteine,
  Großprojekte, Verlauf, Rangliste (Top 10) und weitere Handelsmärkte lassen sich mit ▼/▶ ein- und ausklappen.
  Das Diplomatiefenster ist von gut sechs Bildschirmhöhen auf eine halbe geschrumpft.
- **Weniger Scrollen in Regierung und Technologie:** Die Regierung hat vier Reiter (💰 Haushalt, 🎓 Hof, 📜 Recht,
  👥 Stände); ein goldener Reiter zeigt, dass dort etwas zu tun ist. Der Technologiebaum zeigt nur die nächsten drei
  Stufen (Rest per Knopf), erforschte Nationaltechs verschwinden. Die Gesamtwirkung steckt jeweils hinter „📈 Gesamt“.
- **Reichsreformen 👑:** Das Heilige Römische Reich sammelt kaiserliche Autorität (mehr Mitglieder = schneller,
  Kriege zwischen Mitgliedern bremsen). Der Kaiser verabschiedet damit fünf Reformen nacheinander, vom Reichstag
  bis zum Ewigen Landfrieden, wenn mehr als die Hälfte der Kurfürsten hinter ihm steht. Alle Mitglieder bekommen
  Boni, der Kaiser zusätzlich eigene. Nach dem Ewigen Landfrieden dürfen Mitglieder einander nicht mehr angreifen.
  Alles im Reichsfenster (👑 Reich).
- **18 Ereignisse zu Reformation und Gegenreformation (1517–1620):** Nachricht aus Wittenberg, lutherische Prediger,
  Bauernkrieg, Bibelübersetzung, Klosterauflösung, Bildersturm, Jesuiten, Konzil von Trient, Augsburger
  Religionsfriede, Religionsgespräche, Union und Liga, dazu ein eigener Patriarch für orthodoxe und eine Medrese für
  sunnitische Länder. Viele Optionen holen abgefallene Provinzen zum Staatsglauben zurück.
- **Schwierigkeitsgrade:** Im Startmenü wählbar (Leicht, Normal, Schwer, Sehr schwer). Normal ist etwas leichter als bisher: +10 % Einkommen, +5 % Kampfkraft, −0,5 Unruhe für dich, und die KI greift dich seltener an. Leicht gibt mehr Boni und eine friedlichere KI, Schwer entspricht der alten Balance, Sehr schwer gibt der KI Einkommens-, Kampf- und Mannstärke-Boni und macht sie aggressiver. Alte Spielstände laden als Schwer.
- **Späte Wirtschaft gedämpft:** Einkommensboni (Admin-Tech, Einkommen) addieren sich jetzt zu Steuer-, Produktions- und Handelsboni, statt sie zu vervielfachen. Armeen werden mit jeder Militär-Tech 8 % teurer (Anwerben und Unterhalt). England hatte um 1600 vorher ~330 Gold/Monat bei 30 Ausgaben.
- Die KI nutzt Durchmarschrecht und garantiert kleine befreundete Nachbarn.

## v0.8.9 – 2026-10-26
- **45 neue Ereignisse zu den neuen Systemen:** Knappheit und Überangebot auf den Märkten, Monopole, Messen und
  Streit mit Handelspartnern, Silberadern, Weinjahrgänge, Heringszüge, Weberstreiks; Ereignisse zu Marktplätzen,
  Manufakturen, Kasernen, Festungen und Gerichtshöfen; Häfen (Piraten, Schiffbauer, Hafenbrand, Kaufleute wollen
  einen Hafen), Straßen (Wegelagerer, Postdienst, adlige Wegzölle, Schlammwege), Kredite (drängende Bankiers,
  drohender Staatsbankrott, Bürger lösen Schulden ab), Söldner (Meuterei, Plünderung, Landsknechte), erschöpfte
  Truppen und die Haushaltsregler (Feste, Steuerverweigerer, Akademien, verrostete Rüstungen).
- **20 Wirtschaftsmissionen:** Je zwei für jede spielbare Nation, z. B. Englands Tuchmanufakturen und Häfen,
  Böhmens Silber, Russlands Pelzhandel und Straßen, Brügges Messen.
- Ereignisse können jetzt Gebäudestufen schenken, Kredite erlassen, die Moral heben oder Söldner sofort
  bereitstellen.
- **Großprojekte 🏛️ (neu):** Sieben Bauwerke für die Hauptstadt im Nationsfenster: Kathedrale, Gesandtenhof, Arsenal,
  Universität, Börse, Kriegsakademie, Prunkpalast. Jedes braucht eine Technologiestufe, kostet viel Gold (mehr, je
  entwickelter dein Reich) und baut 3 bis 6 Jahre. Fertig gibt es dauerhafte Boni (z. B. Technologie −8 %,
  +3 Truppenlimit, +5 % Kampfkraft). Immer nur ein Großprojekt zugleich.
- **Hoffest 👑:** Für vier Monatseinnahmen (mindestens 50 Gold) +10 ⭐ Prestige und −2 Kriegsmüdigkeit, alle 5 Jahre.
  Damit hat Gold auch im reichen Spätspiel einen Nutzen.

## v0.8.8 – 2026-10-26
- **Glaube ⛪ (neu):** Jedes Land hat einen Staatsglauben (katholisch, orthodox, sunnitisch, ab 1517 protestantisch),
  jede Provinz den Glauben ihrer Bevölkerung. Provinzen mit anderem Glauben als ihr Herrscher haben +1 Unruhe und
  nehmen den Herrscherglauben langsam von selbst an. Mit einem ⛪ Missionar (Gold, 24 Monate, höchstens 2 zugleich)
  geht es schneller. Eroberungen bringen also Glaubensfragen mit.
- **Reformation:** Ab 1517 breitet sich der Protestantismus von Sachsen durch das Heilige Römische Reich aus. Länder,
  deren Bevölkerung mehrheitlich konvertiert ist, wechseln den Staatsglauben. Du kannst ab 40 % Anteil im
  Nationsfenster wechseln (20 ⭐ Prestige): +15 Beziehung zu Glaubensbrüdern, −15 zu den alten.
- Neuer Kartenmodus **Glaube** (gestreift = anderer Glaube als der Herrscher). Der diplomatische Kartenmodus zeigt
  jetzt auch Garantien, Ehen und Durchmarschrecht.
- **Wissensverbreitung:** Eine Technologie wird billiger, je mehr andere Nationen sie schon kennen (bis −30 %).
  Pioniere zahlen den vollen Preis, Nachzügler holen auf. Das Detailfenster zeigt den Rabatt.
- Die KI nutzt jetzt königliche Heiraten (mit befreundeten Nachbarn, höchstens 2) und stellt Generäle für ihre größte Armee ein.
- **Gebäude lohnen sich wieder:** Bauen kostet die Hälfte, höhere Stufen steigen flacher im Preis. Eine Werkstatt
  amortisiert sich jetzt in rund 35 statt 70 Jahren. Die KI baut entsprechend mehr.

## v0.8.7 – 2026-10-26
- **Durchmarschrecht 🚶 (neu):** Im Fenster eines anderen Landes für 10 🕊️ erbitten. Deine Armeen dürfen dann durch
  dessen Land ziehen, etwa um einen Feind dahinter zu erreichen. Freunde (Beziehung ab 0) sagen ja, Verbündete
  deines Kriegsgegners nein. Fällt die Beziehung unter −25 oder kommt es zum Krieg, endet das Recht, Truppen dort
  kehren heim.
- **Unabhängigkeit garantieren 🛡️ (neu):** Für 25 🕊️ (höchstens 3): Wer dem Schützling den Krieg erklärt, hat dich
  automatisch als Gegner, +15 Beziehung. Greifst du ihn selbst an, ist die Garantie gebrochen.
- Diplomatie-Liste zeigt 🚶 und 🛡️, „Kein Weg dorthin" erklärt jetzt das Durchmarschrecht.

## v0.8.6 – 2026-10-26
- **Separatfrieden 🏳️:** Bist du in einem Krieg nur Verbündeter, kannst du im Kriegsfenster aussteigen:
  Waffenstillstand mit allen Gegnern, besetzte Provinzen gehen zurück, der Kriegsführer ist verärgert.
- **Kampfkraft im Kriegsfenster:** Jeder Krieg zeigt die Stärke der Armeen beider Seiten (Regimenter × Kampfwert ×
  Moral), grün wenn du vorne liegst.
- Kriegsmüde Verbündete schließen Separatfrieden, erschöpfte KI beendet Kriege früher (deutlich weniger Aufstände).
- **Staatsreformen 🏛️ (neu):** Vier Reformstufen im Regierungs-Screen (Herrschaftsgrundlage ab 1444, Verwaltung ab
  1480, Heerwesen ab 1520, Staatsidee ab 1570) mit je drei Wahlmöglichkeiten, alle mit Vor- und Nachteilen. Kostet
  Verwaltungspunkte (100, 150, 200, 250), ein Wechsel ist nur alle 25 Jahre möglich. Die KI reformiert ebenfalls.
- **Moral in Technik und Regierung:** Exerzierreglement (+5 % max. Moral), Stehendes Heer als Technik und als Gesetz
  (je +10 %), Magazinsystem und Landesaufgebot beschleunigen die Moral-Erholung, Söldnerheere senken die max. Moral
  um 5 %. Neuer Berater Drillmeister, der Generalquartiermeister hilft jetzt auch bei der Erholung.

## v0.8.5 – 2026-10-26
- **Generäle ⭐ (neu, Militär-Macht):** Im Armeefenster für 40 ⚔️ einen General anwerben. Er hat 1 bis 3 Sterne
  (bessere Militärtechnik, bessere Offiziere), jeder Stern gibt +6 % Kampfkraft. Generäle können in Schlachten
  fallen, nach Niederlagen eher. Beim Vereinen bleibt der bessere General. Armeen mit General tragen auf der Karte
  einen Stern.
- Diplomatie-Liste: 👑 markiert Häuser, mit denen du verheiratet bist.

## v0.8.4 – 2026-10-26
- **Königliche Heirat 👑 (neu, Diplo):** Im Fenster einer anderen Nation für 40 🕊️, wenn die Beziehung mindestens
  +20 ist. Die Beziehung steigt um 25 und fällt danach nie unter +25. Ist der Partner klein (höchstens 4
  Provinzen) und du mindestens doppelt so stark, kann er beim nächsten Thronwechsel per Personalunion dein Vasall
  werden. Höchstens 3 Ehen je Haus. Ein Krieg gegen den Partner beendet die Ehe.
- **Warnung bei erschöpften Armeen:** Fällt die Moral einer deiner Armeen nach einer Schlacht unter 30 %, steht im
  Protokoll, wo sie steht und was hilft (Drill oder Rückzug).

## v0.8.3 – 2026-10-26
- **Neuer Kartenmodus "Bauten":** zeigt, wie gut jede Provinz ausgebaut ist (dunkel = nichts, gold = viel),
  Baustellen bläulich, fremde Provinzen dunkler.
- **Bauen-Reiter zeigt den Ertrag:** Jedes Gebäude nennt, wie viel Steuer und Produktion die nächste Stufe hier
  bringt ("≈ +0,4/Monat", inklusive der +1 Entwicklung, ohne Handel).
- **Meldung bei Kernland:** Wird eine eroberte Provinz zu Kernland (Zeit abgelaufen oder integriert), steht das
  im Protokoll.
- Festungs- und Hafen-Symbole auf der Karte erst bei starkem Zoom, damit die Küsten nicht zugepflastert sind.

## v0.8.2 – 2026-10-26
- **Diplo- und Militär-Macht haben neue Verwendungen** (bisher fast nur Technologie):
  - 🔥 **Drill** (Armeefenster, ⚔️): Moral der Armee sofort auf das Maximum, auf eigenem oder verbündetem Gebiet.
  - 👥 **Rekrutierung** (Nation-Fenster, 30 ⚔️): sofort bis zu 30 % der maximalen Mannschaften, danach 2 Jahre Pause.
  - 🤝 **Integrieren** (Provinzfenster, 25 🕊️): eine eroberte Provinz wird 2 Jahre schneller zu Kernland.
  - 😠 **Ruf verbessern** (Nation-Fenster, 30 🕊️): −5 aggressive Expansion.
- **Neue Übersicht "Macht einsetzen"** im Nation-Fenster: Kriegsmüdigkeit senken, Ruf, Rekrutierung und ein
  Hinweis, wo es die anderen Aktionen gibt (Entwickeln, Unterdrücken, Integrieren, Drill, Diplomatie).
- Die KI nutzt überschüssige Macht ebenfalls dafür (Tech hat Vorrang).

## v0.8.1 – 2026-10-26
- **Straßennetz auf der Karte:** Nachbarprovinzen mit Straßen sind durch einen Weg verbunden, je höher die Stufe,
  desto breiter. Festungen 🏰 und Häfen ⚓ stehen beim Hineinzoomen neben dem Provinznamen.
- **Karten-Tooltip:** Zeigt jetzt auch Entwicklung und alle Gebäude mit Stufe.
- **Straßen beschleunigen Märsche:** Zwischen zwei eigenen Provinzen mit Straßen schafft eine Armee pro Stufe mit
  25 % Chance einen zweiten Schritt im selben Monat.
- **Straßen-Balance:** Straßen kosten 55 statt 35 Gold und geben keine Entwicklung mehr. Die KI hatte über billige
  Straßen massenhaft Entwicklung gekauft, das führte zu größeren Armeen, längeren Kriegen und fast doppelt so vielen
  Aufständen. Die KI baut Straßen außerdem nicht mehr in frisch eroberten Provinzen, dort braucht sie Gerichtshöfe.
- Neues, klareres Straßen-Symbol 🛤.

## v0.8.0 – 2026-10-26
- **Armee-Moral (neu):** Jede Armee hat Moral bis zu einem Maximum (100 %, Boni können es erhöhen). Sie steigt jeden
  Monat, im eigenen und verbündeten Land schneller, mit Straßen noch schneller, im Feindesland langsam. Eine
  gewonnene Schlacht kostet 15 %, eine verlorene 50 %. Bei 0 % kämpft eine Armee nur noch mit 40 % Kraft. Neue
  Truppen starten bei 60 %. Ein farbiger Balken unter jeder Armee auf der Karte zeigt die Moral (grün, gelb, rot),
  das Armeefenster nennt Wert und Erholung. Die KI zieht erschöpfte Armeen zur Erholung zurück.
- **Straßen 🛤 (neu, Infrastruktur):** Bis Stufe 3, je Stufe 25 % schnellere Moral-Erholung in der Provinz, +10 %
  Handelsmacht, +5 % Produktion.
- **Wachstum sichtbar:** Wächst eine deiner Provinzen (Entwickeln, fertiges Gebäude), schwebt "+1 🏘️" über ihr auf
  und ihr Rand leuchtet kurz. Verluste erscheinen rot.
- **Haushalt 💰 (neu, wie in EU5):** Vier Schieberegler ganz oben im Regierungs-Screen (auch per Knopf aus der
  Wirtschaftsübersicht): Steuerdruck, Hofhaltung, Militärbudget und Forschung, je 5 Stufen, die Mitte ist neutral.
  Mehr Steuern bringen Gold, aber Unruhe und verärgerte Bürger. Ein prächtiger Hof kostet Gold, bringt aber Ansehen
  und einen zufriedenen Adel. Das Militärbudget hebt Kampfkraft und Moral-Erholung, kostet aber Unterhalt. Forschung
  kostet Gold und verbilligt Technologien. Die KI spart, wenn sie knapp bei Kasse ist.
- **Weniger Friedensangebote:** Lehnst du ein Angebot ab, fragt der Gegner frühestens nach 2 Jahren wieder, außer
  der Krieg hat sich deutlich zu seinen Gunsten gedreht (+15 Kriegspunkte).
- **Neue Pixel-Art-Oberfläche:** Alle blauen Menüs sind ersetzt durch eigene Panels im Stil der Icons: Eichenrahmen
  mit Messing-Eckbeschlägen und Nieten, Holzknöpfe mit 4 Zuständen, Titelleiste, Karten für Berater, Stände und
  Techs (grün = erforscht/treu, gold = verfügbar/national, rot = zornig), Tooltips, Balken, Scrollbalken und Slider.
  Generator `tools/art/ui_kit.py` (Varianten `eisen`, `holz`, `krone`), Theme in `scripts/ui/ui_theme.gd`.
- **Buffs und Nerfs auf einen Blick:** Vorteile grün mit Pfeil nach oben, Nachteile rot mit Pfeil nach unten, nach
  Bedeutung statt Vorzeichen (−10 % Baukosten ist grün, +AE ist rot). Gilt für Techs, Regierung, Nationalgeist und
  jetzt auch für Event-Optionen.
- **Neu: "Alle Boni und Mali"** (Nation-Panel): jeder Modifikator mit Gesamtwert, gruppiert nach Wirtschaft, Militär,
  Staat und Stände, und woher er kommt (Nationalgeist, Technologie, Regierung, Gebäude, Güter, Rang, Pakte).
- Startmenü zeigt Nationalgeister als farbige Boni.

## v0.7.4 – 2026-10-26
- **Neuer Name: Rise of EU.** Spiel, Fenster, App und Downloads heißen jetzt so (`RiseOfEU.apk`, `RiseOfEU.exe`),
  das Repo heißt `EyaLinus/rise-of-eu`. Die Android-Paket-ID bleibt gleich, damit das Update die alte App ersetzt
  und Spielstände erhalten bleiben. Unter Windows werden Spielstand und Einstellungen einmalig aus dem alten
  Ordner übernommen.
- **Regierungs-Events (Tech-Thread, PR #17):** 20 neue Events, die an Gesetze, Techs und Stände anknüpfen.

## v0.7.3 – 2026-10-25
- **Provinzfenster in Reitern:** Provinz (Werte mit Erklärungen), Bauen (Gebäude) und Militär (Rekrutieren, Söldner,
  Armeen). Viel weniger Scrollen auf dem Handy.
- **Neue Tipps** beim ersten Mal: Gebäude und Autobau, keine Mannschaften (Söldner), Handel und Handelsabkommen.
  Der Schulden-Tipp nennt jetzt Kredite.
- **4 neue Meilensteine:** Seefahrernation (5 Hafenstufen), Handelsnetz (2 Abkommen), Handelsimperium (15 Gold
  Handel/Monat), Baumeister des Reiches (60 Gebäudestufen, −10 % Baukosten).
- Meldungen unten stehen immer über der Karte und verdecken das Seitenpanel nicht mehr. "Markt beruhigt" erscheint nur
  noch, wenn du das Gut selbst herstellst.

## v0.7.2 – 2026-10-25
- **Handelsabkommen (neu):** Im Länderfenster für 30 🕊️ abschließen. Beide Reiche erhalten +6 % Handelseinnahmen,
  höchstens 3 Abkommen. Die KI nimmt an ab Beziehung 25 oder als Verbündeter, Krieg beendet das Abkommen.
- **Söldner (neu):** Im Provinzfenster 3 Regimenter sofort und ohne Mannschaften, für das doppelte Gold, einmal pro
  Jahr. Die KI wirbt Söldner an, wenn ihr im Krieg die Mannschaften ausgehen.
- **Wirtschafts-Panel** in drei Reiter geteilt (Kasse, Handel, Güter), deutlich weniger Scrollen.
- **Hinweis-Punkt** am Wirtschafts-Tab: Kasse im Minus, freier Händler, Kredit tilgbar oder genug Gold für ein Gebäude.
  Langes Drücken auf den Tab zeigt den Grund.
- **Flüssiger auf dem Handy:** Die höchste Geschwindigkeit rechnet nur so viele Monate pro Bild, wie das Gerät schafft,
  statt zu ruckeln. Die KI sucht Bauprojekte nur noch, wenn sie sich überhaupt eins leisten kann.

## v0.7.1 – 2026-10-25
- **Touch-Bedienung:** In allen Listen und Fenstern kann man jetzt überall scrollen, auch wenn der Finger auf einem
  Button startet (ab 14 px Bewegung wird gescrollt statt geklickt). Regler bleiben normal ziehbar.
- **Tooltips auf dem Handy:** Lange auf einen Button oder Wert drücken zeigt die Erklärung. Die Kopfleiste zeigt live
  Einnahmen-Aufschlüsselung, Punkte pro Monat, Mannschafts-Maximum und Koalitionsgrenze.
- **Autobau:** Im Wirtschafts-Panel einschaltbar. Baut automatisch das lohnendste Gebäude, solange die Kasse danach
  nicht unter die eingestellte Mindestkasse fällt (in 25er- und 100er-Schritten).
- **Hafen ⚓:** Neues Gebäude für 86 Küstenprovinzen (bis Stufe 3): +3 Handelsmacht, +25 % Handelsmacht, +10 %
  Produktion der Provinz und +2 % Handelseinnahmen im ganzen Reich je Stufe.
- **Kredite (neu):** Sofort ein Jahreseinkommen leihen (mind. 50), 5 % Zinsen plus 1 % für jeden weiteren Kredit,
  höchstens 5. Tilgen jederzeit. Die KI nutzt Kredite im Krieg.
- **Marktschocks (neu):** Ab und zu wird ein Gut für 3–6 Jahre knapp (Preis ×1,4) oder im Überfluss (×0,7).
  Im Wirtschafts-Panel mit ⚠️ markiert.
- **Lesbarkeit:** Größere Provinz- und Ländernamen auf dem Handy, kräftigere Umrandung, Meldungen unten mit
  dunklem Hintergrund.
- **Tech- und Regierungs-Thread (PR #14):** Technologiebaum besser lesbar (Effekte in jeder Zelle, erledigte Reihen
  eingeklappt, Tooltips), Investitionsregler für Handelskompanien (Stufe 1–5) und Stände (Adel, Klerus, Bürger)
  mit Zufriedenheit, Zugeständnissen und Krisen-Events im Regierungsbildschirm.

## v0.7.0 – 2026-10-25
- **Wirtschaft:** Jede Provinz stellt ein Gut her (12 Güter, z. B. Getreide, Wein, Tuch, Eisen, Silber). Die Preise
  ändern sich jedes Jahr mit Angebot und Nachfrage. Wer am meisten von einem Gut herstellt (mind. 20 % der Welt),
  bekommt dessen Bonus. Einkommen = Steuern + Güter + Handel; das neue Panel 💰 Wirtschaft zeigt alles.
- **Handel:** 13 Märkte (London, Paris, Flandern, Hamburg, Venedig, Konstantinopel, …). Deine Handelsmacht im
  Einzugsgebiet bestimmt deinen Anteil. Händler (1–5) steigern sie, automatisch oder per Hand.
- **Gebäude (Ausbau):** Marktplatz, Werkstatt, Manufaktur, Gutshof, Kaserne, Festung, Gerichtshof, mit Stufen.
  Gold geht jetzt in Gebäude statt in "Bauen". Jede fertige Stufe bringt +1 Entwicklung.
- **Entwicklung wirkt:** mehr Steuern, Güter, Handelsmacht, Mannschaften und Bauplätze je Stufe.
- **Technologie und Regierung (eigener Thread):** Technologiebaum mit 81 Techs in 9 Zweigen und 30 Spezial-Techs
  für die Großmächte. Regierungsbildschirm mit Beratern, Handelskompanien und Gesetzen, deren Optionen gleichzeitig
  Vor- und Nachteile bringen.
- **Armeeführung:** Pro Armee und als Standard für alle wählbar: ⚔️ Angriff, 🛡️ Verteidigen (nur eigenes und
  verbündetes Land) oder ✋ Manuell. Schnellbefehle Belagern, Angreifen, Befreien und Zur Hauptstadt.
  Armeeliste im Kriege-Panel. Eigene Armee gewählt und Feindarmee antippen bedeutet Angriff. "Alle meine Armeen
  hierher" im Provinzpanel.
- **Kartenmodi:** Auswahl-Panel statt Durchklicken, neu sind Güter, Handel und Krieg. Ländernamen stehen in der
  Mitte des Reichs und wachsen mit seiner Größe.
- **Progression:** Rang Herzogtum, Königreich (150 Entwicklung) und Imperium (400 Entwicklung) mit Boni.
  13 Meilensteine mit Belohnungen (Missionen-Panel).
- **Grafik (Art-Thread):** Pixel-Art statt Emojis, Flaggen im Text, ein Bild zu jedem Event, Hover-Infos auf der
  Karte.
- Tests und CI sind schneller: keine 200-Jahre-Läufe mehr in der CI (UI-Rauchtest 25 Jahre).
- Balance (2 × 16 Partien): Ø 17–18 Nationen ausgelöscht, Großmächte überleben zu 97–98 %, weniger Bankrotte.

## v0.6.1 – 2026-10-25
- **Content (PR #9):** Osmanen, Polen und Burgund haben jetzt je 10 Missionen und 11–12 eigene Events, also so viel
  wie die Großmächte. Polen erhält zusätzlich +1 Diplomatie/Monat, Burgund +10 % Einkommen.
- Balance (2 × 32 Partien): Ø 20 Nationen ausgelöscht, Großmächte überleben zu 97 %, Böhmen zu 81 %,
  weniger Bankrott-Monate.

## v0.6.0 – 2026-10-25
- **Neue spielbare Nationen:** Osmanen, Polen und Burgund (im Startmenü unter "Weitere Nationen"). Sie haben
  noch weniger Missionen und Events als die 7 Großmächte; das wird nachgezogen. Neues Daten-Flag `major` trennt
  die Großmacht-Regeln von "spielbar", die KI-Balance bleibt dadurch unverändert.
- **Karte neu gemalt:** Gelände (Meerestiefe, Küstenlinien, Schummerung, Gebirge), klarere Grenzen zwischen
  Nationen, neue Armee-Marker in Nationsfarbe mit Regimentszahl und Marschpfeil, kompakt beim Herauszoomen.
- **Entwicklung ohne harte Grenze bei 30:** Ab 25 steigen die Kosten für Entwickeln und Bauen um 8 % je Stufe,
  Obergrenze 99.
- **Mobile Bedienung:** Langes Drücken zeigt Provinz-Infos, Doppeltipp zoomt, Wischen mit Schwung, größere
  Touch-Flächen (Buttons, Tabs, Armeen), "◀ Zurück" in Panels (auch per Android-Zurück-Taste). Nach einem
  Marschbefehl ist die Armee abgewählt, damit kein Tipp versehentlich umleitet.
- **Content (PR #5, #7, #8):** Italien und Skandinavien, Britische Inseln, Iberien, Osteuropa, Balkan, deutsche
  Kleinstaaten und späte Events. Jetzt 258 Events und 122 Missionen, jede der 50 Nationen hat eigene Events.
- Balance (2 × 32 Partien): Ø 19,6–20,6 Nationen ausgelöscht, Großmächte überleben zu 96–97 %, Osmanen,
  Polen und Burgund zu 97–100 %.

## v0.5.2 – 2026-10-25
- **Content (PR #4):** Missionen für Osmanen, Polen und Burgund, Reichsevents für alle HRE-Mitglieder und den Kaiser.
- Balance: Habsburg erbt Böhmen seltener (Böhmen überlebt jetzt in ~70–90 % der KI-Partien).
- Bugfix: Rundungsrest bei der AE-Abnahme verfälschte Spielstände minimal.
- Qualität: neuer UI-Rauchtest (`tools/ui_smoke.gd`) spielt jede Großmacht 200 Jahre und öffnet dabei alle Panels
  und Popups; läuft in der CI. Ergebnis: 0 Skriptfehler.

## v0.5.1 – 2026-10-25
- **Sound:** kurze, prozedural erzeugte Effekte (Klick, Event, Krieg, Schlacht, Frieden, Erfolg), im Menü abschaltbar.
  Erzeugt von `tools/gen_sfx.py`, keine fremden Assets.
- **Frieden:** Knopf "✨ Beste Auswahl" wählt die wertvollsten Provinzen für deine Kriegspunkte.
- **Content (PR #3):** Ideen, Boni und Herrscher für alle 43 Kleinstaaten, historische Kleinstaaten-Events
  (z. B. Osmanen gegen Byzanz, Union von Lublin) und Events zu Unruhe, Kriegsmüdigkeit, Vasallen und Kaiserwahl.
- Neue Event-Bedingungen `hre` und `emperor`.
- Balance (2 × 32 Partien): Ø 19–20 Nationen ausgelöscht, Großmächte überleben zu 97 %.

## v0.5.0 – 2026-10-25
- **Kaiserwahl im HRE:** 7 Kurfürsten (Böhmen, Kurpfalz, Sachsen, Brandenburg, Köln, Bayern, Österreich) wählen,
  wenn der Herrscher des Kaisers stirbt. Stimmen folgen Beziehungen, Bündnissen, Prestige und Größe; der Kaiser
  erhält +1 🕊️/Monat. Neues Panel "👑 Reich" (Diplomatie) zeigt, wie jeder Kurfürst gerade stimmen würde.
- **Content (PR #2 aus dem Content-Thread):** 152 Events (Ketten für alle 7 Großmächte, allgemeine und
  Kleinstaaten-Events), 9–10 Missionen je Großmacht. Die böhmische Erbfolge an Habsburg ist seltener geworden
  (Böhmen überlebt jetzt in ~75–80 % der Partien statt ~50 %).
- **Spielstatistik:** Verlaufsdiagramm (Entwicklung und Rang) im Nation-Panel und am Spielende, dazu eine Bilanz
  (Schlachten, Kriege, Missionen, bester Rang).
- **Einsteiger-Tipps:** kurze, einmalige Hinweise genau dann, wenn sie relevant werden (Krieg, Besetzung, Unruhe,
  AE, Technologie, Mission, Schulden). Im Menü abschaltbar.
- Neue Event-Bedingungen: `we_min`, `is_vassal`, `has_vassal`, `unrest_min`.
- Bugfix: Der Kaiser wurde nicht im Spielstand gespeichert.
- Balance (32 Partien): Ø 21 Nationen ausgelöscht, größte Nation Ø 15 %, Großmächte überleben zu 96 %.

## v0.4.0 – 2026-10-24
- **Kriegsmüdigkeit:** steigt im Krieg und mit jeder verlorenen Schlacht, sinkt im Frieden. Erschöpfte KI-Gegner
  nehmen Frieden leichter an, erschöpfte KI erklärt keine neuen Kriege. "Volk beruhigen" senkt sie (🕊️).
- **Unruhe light:** Frisch eroberte, nicht integrierte Provinzen sind unruhig, Kriegsmüdigkeit verstärkt das.
  Ab 5 droht ein Aufstand: Die Provinz fällt an ihren früheren Besitzer zurück (wenn er angrenzt) oder wird
  geplündert. Gegenmittel: Garnison, "Unruhe unterdrücken" (⚔️), Zeit. Neuer Kartenmodus "Unruhe".
- **Vasallen sagen sich los,** wenn sie stark werden oder ihren Lehnsherrn hassen.
- **Komfort:** Hinweis-Punkte an den Tabs (Technologie leistbar, Aufstand droht, Mission erfüllt, Annexion
  möglich, Frieden mit Gewinn möglich), Rangliste der Mächte, Tooltips an der Ressourcenleiste,
  Tastenkürzel am PC (Leertaste, 1–5, Esc).
- Content-Leitfaden `docs/CONTENT_GUIDE.md`, neuer Event-Effekt `we`.
- Balance (2 × 32 Partien): Ø 23–24 Nationen ausgelöscht, größte Nation Ø 16 %, Großmächte überleben zu 92–93 %,
  Ø 68–70 Kriege, ~30 Aufstände und ~6 Unabhängigkeitserklärungen pro Partie.

## v0.3.0 – 2026-10-24
- **Vasallen:** Neue Friedensoption "⛓️ Vasallisieren" gegen den gegnerischen Kriegsführer (kostet 60 % des Preises
  seines gesamten Landes, halbe AE, keine Admin-Kosten). Vasallen zahlen 20 % ihres Einkommens als Tribut,
  kämpfen in deinen Kriegen, werden von dir verteidigt und dürfen weder Krieg erklären noch Bündnisse schließen.
- **Diplomatische Annexion** nach 15 Jahren: kostet 12 🕊️ und 5 📜 pro Entwicklung und etwas AE.
- KI vasallisiert besiegte Kleinstaaten (≤ 2 Provinzen) statt sie aufzuteilen und annektiert nur gelegentlich.
- **25 neue Events:** jetzt 10 pro Großmacht, darunter Vasallen-Events (Rjasan, Nowgorod, Navarra, Irland, Bayern)
  und Ketten (Ludwig XI. → Erbe Burgunds, Rudolf II. → Majestätsbrief). Neuer Event-Effekt `vassal`.
- **Pixel-Art:** Icons, Armee-Marker und Flaggen für alle 50 Nationen (Emoji bleibt Fallback).
- Kriegserklärungs-Dialog zeigt alle Verteidiger (Verbündete, Lehnsherr, Kaiser, Schutzmacht) und deren Stärke.
- Nationenlisten zeigen Flaggen; lange Buttontexte werden gekürzt statt das Panel zu sprengen.
- Balance (2 × 32 Partien): Ø 24–25 Nationen ausgelöscht, größte Nation Ø 16 %, Großmächte überleben zu 91–95 %,
  Ø 62–64 Kriege (weniger als vorher, weil Vasallen keine Kriege erklären), ~25 Vasallisierungen, ~20 Annexionen.

## v0.2.0 – 2026-10-24
- Gleichgewicht der Mächte: Greift jemand einen Kleinstaat (≤ 3 Provinzen) an, springt der stärkste nicht befreundete
  Nachbar als Schutzmacht ein. Ausgelöschte Nationen bis 1644 sinken von Ø 29 auf Ø 23 (historisch ~20).
- Balance Runde 4 (64 Partien): Ø 85 Kriege, größte Nation Ø 16 % der Entwicklung, Großmächte überleben zu 94 %.
- UI-Größe einstellbar (85–140 %, Android startet bei 120 %), auch im Startmenü.
- Herrschernamen mit Ordnungszahl für die 7 Großmächte.
- Icon-Registry: Pixel-Art-PNGs ersetzen Emojis automatisch (`assets/art/icons/`).
- `tools/sim.gd --bot TAG`: aggressiver Stand-in-Spieler zum Testen von AE/Koalitionen.
- CI bricht überholte Läufe ab.

## v0.1.0 – 2026-10-24
- Erste spielbare Version: 7 Großmächte, 43 KI-Nationen, 161 Provinzen, 1444–1644.
- Gold + Admin/Dip/Mil, Technologie, Entwickeln/Bauen, Rekrutieren, Bündnisse, Ansprüche.
- Krieg: Armeen, Schlachten, Belagerungen, Kriegspunkte, Friedensverhandlungen, Kriegs-Timeout nach 12 Jahren.
- Aggressive Expansion mit Koalitionen; Heiliges Römisches Reich mit Kaiser als Verteidiger.
- 42 nationale und 12 allgemeine Events mit je 3 Optionen, 42 Missionen.
- Touch-taugliche UI mit Emoji-Platzhaltern, Autosave.
- Kartenmodi (politisch, diplomatisch, Entwicklung), Popups bei Kriegserklärung/Ruf zu den Waffen/Koalition,
  Schalter "alle Armeen KI/manuell".
- Headless-Balance: 3 Runden mit insgesamt ~300 KI-Partien à 200 Jahre. Endstand (16 Partien): Ø 29 von 50 Nationen
  ausgelöscht (meist Kleinstaaten, historisch ~20), größte Nation Ø 16 % der Gesamtentwicklung (max. 22 %),
  Großmächte überleben zu 94 % (Böhmen wird oft historisch von Österreich geerbt), Ø 96 Kriege, 13 Koalitionskriege,
  8 % der Kriege enden per Timeout. Bericht: `tools/balance_report.md`.
- Strukturelle Balance-Fixes: Eroberung kostet Admin, KI plant nur bezahlbare Armeen, Hauptstädte kosten doppelte
  Kriegspunkte/AE, Provinzen gehen nur an angrenzende Sieger, HRE-Kaiser verteidigt Reichsmitglieder,
  KI annektiert keine Großmacht-Hauptstadt.
