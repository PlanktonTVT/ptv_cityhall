# ptv_cityhall

VORP/RedM Resource fuer ein Bürgermeistersystem mit Rathaeusern und Markthallen fuer mehrere Staedte.

## Features

- Bürgermeisteramt pro Stadt mit Amtszeit, Stadtkasse und getrennten Markthallen-Steuern fuer Waren/Waffen sowie Einkauf/Verkauf.
- Neun vorkonfigurierte Staedte mit eigenem Rathauspunkt, NPC, besonderem Rathaus-Blip, eigener Wahl, eigenem Bürgermeister und eigener Stadtkasse.
- Bürgerregister mit Antraegen, Bestaetigung durch Bürgermeister/Admin und Austragung aus der Stadt.
- Ingame-Wahlen mit Kandidaturphase, Abstimmphase, Einmal-Stimme pro Charakter und automatischem Wahlsieger.
- Zentrale Markthalle mit konfigurierbaren Reitern fuer Waren und Waffen, NPC und ruhigem Interaktionsfeld.
- Item-Escrow: Ware wird beim Einstellen aus dem Inventar genommen und beim Kauf an den Kaeufer gegeben.
- Steuereinnahmen aus Markthallenverkaeufen und Einstellgebuehren fliessen in die Stadtkasse.
- Offene Auszahlungen fuer offline/online Verkaeufer koennen in der Markthalle abgeholt werden.
- Bürgeranmeldung, Wahlen und Bürgermeisterverwaltung laufen direkt im Markthallenfenster.
- Bürgermeister/Admin kann Bürger verwalten, Bekanntmachungen senden und Auszahlungen aus der Stadtkasse machen.
- Bei aktiven Wahlen erhalten bestaetigte Bürger der jeweiligen Stadt stuendlich eine Notify-Meldung.
- Bürgermeister koennen bestaetigten Bürgern Jobs aus dem jeweiligen Stadtblock `Config.Towns[stadt].MayorJobs.Jobs` zuweisen.
- Discord-Webhooks koennen ueber `Config.Discord` fuer Wahlen, Bürgeraktionen, Jobs, Steuern und Stadtkasse aktiviert werden.

## Installation

1. Ordner `ptv_cityhall` in deinen RedM `resources` Ordner legen.
2. In `server.cfg` in dieser Reihenfolge sicherstellen:

```cfg
ensure oxmysql
ensure vorp_core
ensure vorp_inventory
ensure vorp_menu
ensure ptv_cityhall
```

3. Wenn `Config.AutoSetupDatabase = true` bleibt, legt die Resource die Tabellen beim Start selbst an.
   Alternativ `sql/install.sql` manuell in die Datenbank importieren.
4. `config.lua` anpassen: Stadtliste unter `Config.Towns`, Markthallen-/Rathaus-Koordinaten, Admin-Gruppen, Blip, Steuersatz-Limit und Wahlzeiten.

## Version und Updatechecker

- Diese Ausgabe ist als Version `1.0` gesetzt (`fxmanifest.lua` und `Config.Version`).
- Der Updatechecker schreibt beim Resource-Start in die CFX-Konsole.
- Der Updatechecker ist auf `https://api.github.com/repos/PlanktonTVT/ptv_cityhall/releases/latest` eingestellt.
- Der Download-Link zeigt auf `https://github.com/PlanktonTVT/ptv_cityhall/releases/latest`.
- Damit echte Updates erkannt werden, muss auf GitHub immer die neueste Release-Version als Release angelegt sein.
- Als Text reicht eine Datei, deren erste Zeile die neuste Version enthaelt, z. B. `1.0`.
- Als JSON werden Felder wie `version`, `latest`, `latestVersion` oder `tag_name` erkannt; optional auch `download`, `downloadUrl`, `url`, `html_url`, `changelog`, `notes` oder `body`.
- Manuell kann der Check in der CFX-Konsole mit `ptv_cityhall_updatecheck` gestartet werden.

## Nutzung

- Spieler oeffnen das Markthallenfenster an der Markthalle mit `G`.
- Im Markthallenfenster gibt es die Bereiche `Markt`, `Bürger`, `Wahlen` und fuer Bürgermeister/Admins `Verwaltung`.
- Admins koennen Wahlen im Bereich `Wahlen` starten oder beenden.
- Das Rathaus-/Bürgermeistermenue oeffnet man per Command:

```text
/buergermeister
```

- Admins oeffnen die Preisverwaltung der Markthalle per Command; Preisfelder sind nur aktiv, wenn `Config.Market.UseConfigPrices = false` ist:

```text
/markthalle_admin
```

- Admin-Command:

```text
/bm_admin
/bm_admin valentine
/bm_admin start [kandidatur_stunden] [wahl_stunden]
/bm_admin rhodes start [kandidatur_stunden] [wahl_stunden]
/bm_admin end
/bm_admin settax [waren_einkauf] [waren_verkauf] [waffen_einkauf] [waffen_verkauf]
/bm_admin treasury
```

Ohne Unterbefehl oeffnet `/bm_admin` das Adminfenster mit Verwaltung, Wahlen, Bürgerregister und Markthallenverwaltung.
Optional kann als erstes Argument ein Stadt-Key aus `Config.Towns` angegeben werden, z. B. `valentine`, `rhodes` oder `saintdenis`.
Die UI ist optisch an `ptv_welcomedelivery` angelehnt.
Scrollbar-Farben, Breite und Rundung werden direkt in `html/style.css` ueber die `--scrollbar-*` Variablen angepasst.

## Staedte und Rathauspunkte

- Die Resource legt beim Start alle Eintraege aus `Config.Towns` in `bm_towns` an.
- Vorkonfiguriert sind `blackwater`, `valentine`, `rhodes`, `saintdenis`, `strawberry`, `armadillo`, `tumbleweed`, `annesburg` und `vanhorn`.
- Jede Stadt hat eine eigene Wahl, einen eigenen Bürgermeister, eine eigene Stadtkasse, eigene Bürger und eigene Markthallenbestaende.
- Der Markthallen-/Rathaus-NPC wird je Stadt ueber `Config.Towns[stadt].MarketHall.Ped` gesetzt.
- Koordinaten koennen direkt als Tabelle geschrieben werden, z. B. `coords = { x = -255.47, y = 741.52, z = 118.17, h = 286.05 }`; `h` wird beim NPC als Blickrichtung genutzt.
- Die Interaktionsreichweite stellst du je Stadt mit `interactionDistance` ein.
- `hintDistance` legt je Stadt fest, ab wann der Client in die Naehe-Pruefung geht.
- Der besondere Rathaus-Blip wird je Stadt ueber `Config.Towns[stadt].Blip` angepasst; `Config.CityHallBlip` dient als Fallback.
- Fuer Blips koennen numerische RedM-Sprite-Hashes und `style` gesetzt werden; die Resource legt die Blips nach Clientstart mehrfach neu an, falls RedM beim ersten Versuch noch nicht bereit war.
- Commands wie `/buergermeister`, `/markthalle` und `/bm_admin` nutzen die naechste Stadt im Umkreis; direkt am NPC wird immer diese Stadt aktiv.
- Der alte wiederholte Notify-Hinweis wurde durch ein dauerhaftes Interaktionsfeld mit Hintergrund ersetzt, das nur in Reichweite sichtbar ist.
- Stadtkassen-Buchungen werden mit Klartext-Titeln angezeigt, z. B. `Kauft im Markt inkl. Steuer` statt `market_buy_tax`.

## Wahlablauf

1. Admin startet eine Wahl im Markthallenfenster oder per `/bm_admin start`.
2. Spieler reichen waehrend der Kandidaturphase ihr Wahlprogramm ein.
3. Danach beginnt automatisch die Abstimmphase.
4. Nach Ablauf wird der Sieger automatisch Bürgermeister.
5. Bei Gleichstand bleibt der aktuelle Bürgermeister im Amt, sofern `Config.Election.TieKeepsCurrentMayor = true` gesetzt ist.
6. Solange eine Wahl laeuft, sendet `Config.ElectionReminder` im Abstand von `IntervalMinutes` eine Notify-Meldung an aktive Bürger dieser Stadt.

## Bürgerregister

- Spieler koennen im Markthallenfenster einen Bürgerantrag fuer die aktive Stadt stellen.
- Der Bürgermeister/Admin sieht im Bereich `Verwaltung` offene Antraege und bestaetigte Bürger seiner Stadt.
- Die Anzeige nutzt bevorzugt Vor- und Nachname aus der VORP-Tabelle `characters`; falls das Schema abweicht, wird der gespeicherte Antragsname aus `bm_citizens` verwendet.
- Offene Antraege koennen bestaetigt oder abgelehnt werden.
- Bestaetigte Bürger koennen aus der Stadt entfernt werden.
- Bestaetigten Bürgern kann der Bürgermeister im Verwaltungsfenster per Dropdown einen Job zuweisen.
- Erlaubte Jobs werden pro Stadt in `Config.Towns[stadt].MayorJobs.Jobs` gepflegt, z. B. `{ label = 'Valentine Deputy', job = 'valentine_deputy', grade = 0 }`. `Config.MayorJobs` bleibt als Fallback erhalten.
- Die Jobzuweisung schreibt direkt in `characters.job`, `characters.joblable`/`characters.joblabel` und `characters.jobgrade`, je nachdem welche Spalten in deiner Datenbank existieren.
- Der Rang kann in der Config als `grade`, `jobgrade`, `jobGrade`, `job_grade` oder `rank` gesetzt werden; gespeichert wird er in `characters.jobgrade` beziehungsweise vorhandene Varianten.
- Wenn derselbe Job mehrfach mit verschiedenen Raengen in der Config steht, wird intern `job|rang` als eindeutige Auswahl verwendet.
- Bei online Spielern wird der aktive VORP-User bevorzugt ueber `Core.getUserByCharId` gefunden; die VORP-Setter laufen ohne unterdrueckte Events, der Character-Cache wird nachgezogen und danach der Player-Statebag aktualisiert, damit `/myjob` und andere Scripts den neuen Job ohne Relog abfragen koennen.
- Mit `Config.Citizenship.RequireApprovedForVoting` und `Config.Citizenship.RequireApprovedForCandidacy` kannst du festlegen, ob nur bestaetigte Bürger abstimmen oder kandidieren duerfen.

## Discord Webhook

- `Config.Discord.Enabled = true` aktiviert Webhooks.
- `Config.Discord.Webhook` muss deine Discord-Webhook-URL enthalten.
- Ueber `Config.Discord.Events` kannst du einzelne Meldungen aktivieren oder deaktivieren.
- Lager-Exports, Lagerentnahmen und Aktivieren/Deaktivieren von Marktguetern senden eigene Webhook-Events: `marketExport`, `marketWithdraw` und `marketToggle`.

## Markthalle

- Die erlaubten Markthallen-Items werden in `Config.Market.Categories` gepflegt.
- Standardmaessig gibt es die Reiter `Waren` und `Waffen`.
- Nur Items, die dort eingetragen sind, erscheinen im Markthallenfenster.
- Pro Item kannst du Label, Mindest-/Maximalmenge und Mindest-/Maximalpreis setzen.
- Pro Item kannst du `buyPrice`, `sellPrice` und `initialStock` setzen.
- Mit `Config.Market.UseConfigPrices = true` werden die `buyPrice`-/`sellPrice`-Werte aus der Config bei jedem Start und Oeffnen auf jede Markthalle uebernommen.
- Die Markthalle hat einen eigenen Bestand pro Stadt in `bm_market_stock`.
- Jede Stadt kann einzelne Waren/Waffen im Verwaltungsfenster per Häkchen aktivieren oder deaktivieren; deaktivierte Gueter werden in der Markthallenansicht ausgeblendet und koennen nicht gekauft, verkauft oder eingestellt werden.
- Bürgermeister/Admins sehen im Verwaltungsfenster ein Markthallenlager, koennen Bestand kostenlos entnehmen oder Bestand exportieren.
- Exports, Entnahmen und Aktivieren/Deaktivieren werden im Reiter `Logs` angezeigt und bei aktivem Discord-Webhook gepostet.
- Die Verwaltung ist in Unterregister aufgeteilt: `Verwaltung`, `Bürger`, `Exports` und `Logs`.
- Beim Export wird Bestand vernichtet und `Config.Market.ExportPercent` des Gesamtwerts der entnommenen Menge in die Stadtkasse gebucht.
- Normale Spieler koennen konfigurierte Waren und Waffen direkt im Fenster kaufen und verkaufen.
- Jede Zeile zeigt Markthallenbestand, deinen eigenen Inventarbestand, Einkaufspreis mit Einkaufsteuer, Verkaufspreis mit Verkaufsteuer und ein Mengenfeld.
- Hinter dem Mengenfeld gibt es je einen Button fuer Einkauf und Verkauf.
- Bürgermeister/Admin zahlen keine Einstellgebuehr, wenn `Config.Market.MayorNoListingFee = true` gesetzt ist.
- Bürgermeister/Admin koennen aktive Angebote aus der Markthalle entfernen. Die Ware geht direkt oder als Markthallen-Rueckgabe an den Verkaeufer zurueck.
- Wenn `Config.Market.UseConfigPrices = false` gesetzt ist, koennen nur Admins aus `users.group` Einkaufspreis und Verkaufspreis im separaten `/markthalle_admin` Fenster setzen.
- Die aktuellen Steuersaetze werden in der Markthalle und im Bürgermeisteramt angezeigt.
- Die Einkaufsteuer und Verkaufsteuer sind getrennt. Beide muessen mindestens 5% betragen, und die Verkaufsteuer muss mindestens 1 Prozentpunkt hoeher sein als die Einkaufsteuer.
- Nur Admins aus `users.group` koennen die Steuersaetze im separaten `/markthalle_admin` Fenster oder per `/bm_admin settax [waren_einkauf] [waren_verkauf] [waffen_einkauf] [waffen_verkauf]` setzen.
- Waren und Waffen haben jeweils einen einheitlichen Einkauf- und Verkaufsteuersatz fuer alle Items im Reiter.
- Beim Einstellen wird das Item direkt aus dem Inventar genommen.
- Beim Einkauf aus der Markthalle zahlt der Kaeufer Einkaufspreis plus Einkaufsteuer.
- Beim Verkauf an die Markthalle bekommt der Spieler Verkaufspreis abzueglich Verkaufsteuer.
- Beide Steuern werden der Stadtkasse gutgeschrieben.
- Auszahlungen und Warenrueckgaben koennen im Hauptmenue der Markthalle abgeholt werden.

Beispiel:

```lua
Config.Market.Categories = {
    goods = {
        label = 'Waren',
        items = {
            bread = { label = 'Brot', minAmount = 1, maxAmount = 25, minPrice = 0.10, maxPrice = 25.00, buyPrice = 2.00, sellPrice = 1.00, initialStock = 25 }
        }
    },
    weapons = {
        label = 'Waffen',
        items = {
            WEAPON_REVOLVER_CATTLEMAN = { label = 'Cattleman Revolver', minAmount = 1, maxAmount = 1, minPrice = 25.00, maxPrice = 1000.00, buyPrice = 250.00, sellPrice = 125.00, initialStock = 2 }
        }
    }
}
```

## Naechste Ausbaustufen

- Gesetzes-/Verordnungsbuch mit aktiven Erlassen pro Stadt.
- Haushaltskategorien statt freier Stadtkassen-Auszahlung.
- Wahlplakate, Wahlkampfspenden und oeffentliche Debatten.
