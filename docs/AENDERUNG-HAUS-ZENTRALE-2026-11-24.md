# Änderung: Smart-Home-Datenerfassung auf CT 105 und Grafana-Dashboard „Jaylab Haus-Zentrale“ auf CT 102

## Ergebnis und Umfang

Am 24./25. November 2026 wurden im Rahmen der beauftragten Umsetzung des Entwurfs [2026-11-24-haus-zentrale-dashboard-design.md](superpowers/specs/2026-11-24-haus-zentrale-dashboard-design.md) und des Umsetzungsplans [2026-11-24-haus-zentrale-dashboard.md](superpowers/plans/2026-11-24-haus-zentrale-dashboard.md) die Node-RED-Datenerfassung auf `proxmox`, CT 105 (`nodered`, `192.168.40.223`), erweitert sowie das neue zentrale Grafana-Dashboard **„Jaylab Haus-Zentrale“** (`uid: jaylab-haus-zentrale`) auf `proxmox`, CT 102 (`grafana`, `192.168.40.248`, `Grafana Enterprise 13.3.1`), über die offizielle Grafana-HTTP-API bereitgestellt.

- **Node-RED auf CT 105 (`flows.json`, `118` → `148` Elemente):** Ergänzung der zwei fehlenden Heizkörperthermostate (`HT-EG-Schlafzimmer` `...748B`, `HT-Ankleidezimmer` `...46BB`) in `temperature` (`11` Fühler) und `valveTappetState` (`10` TRVs), Entfernung des doppelten `Tür Hauseingang`-Nodes im Alt-Tab `Fensterkontakt` unter strikter Beibehaltung der `6` Alt-Kontakte im Measurement `ShutterContact` sowie drei neue Tabs (`Steckdosen & Geräte`, `Raumklima (Soll)`, `Sicherheit & Gesundheit`) für die sechs neuen Measurements `powerMeter`, `applianceState`, `roomClimate`, `securityStatus`, `deviceHealth` und `contactStatus` in InfluxDB Cloud (`shcbucket`).
- **Grafana-Dashboard auf CT 102 (`jaylab-haus-zentrale`, Stand `v2`):** Einheitliche Übersicht über alle `25` physischen SHC-Geräte, `4` Smart-Steckdosen (`Waschmaschine`, `Creality`, `ZS Kompressor`, `Springer`), `9` Raumklimaregler, `9` Tür-/Fensterkontakte und `6` Aqara-Wettersensoren in `5` Rows (`23` Daten-Panels, `28` Panel-Einträge gesamt; Rows 3–5 standardmäßig eingeklappt).
- **Bestandsschutz und Namenskonvention:** Alle fünf bestehenden Dashboards (`_ts0ZCT4k`, `mttazdTnz`, `unEDfmJVk`, `kgz9x6J4z`, `YjZPR_A7k`) sowie das Library Panel `wbQMs6J4k` blieben zu 100 % unverändert. Für `hdm:HomeMaticIP:3014F711A00004953859DEF1` gilt durchgängig der kanonische Name **`Springer`** (`0` Vorkommen von `Ela-Wandheizung` im Dashboard; in Node-RED nur als Quellkommentar zur früheren SHC-Bezeichnung).
- **Ausfallwirkung:** Auf CT 105 beschränkte sich die Unterbrechung auf das kontrollierte Anhalten und Neustarten von `nodered.service` während des `flows.json`-Wechsels (einschließlich Vorab-PBS-Snapshot). Auf CT 102 erfolgte das Einspielen ohne Dienstneustart über `POST /grafana/api/dashboards/db`.

| Komponente | Zielsystem | Vorher | Nachher | Beleg / Ort |
| --- | --- | --- | --- | --- |
| Node-RED Flows | CT 105 (`192.168.40.223`) | `118` Nodes (`4355938d...`) | `148` Nodes (`b4a18a42...`) | `/home/jay/.node-red/projects/nodered-managed/flows.json` |
| Neue Measurements (`shcbucket`) | CT 105 → InfluxDB Cloud (`f7QzURA7k`) | nur `temperature`, `valveTappetState`, `humidity`, `ShutterContact` (`6`) | zusätzlich `powerMeter`, `applianceState`, `roomClimate`, `securityStatus`, `deviceHealth`, `contactStatus` (`9`); `temperature` `11/11`, `valveTappetState` `10/10` | Live-Query-Prüfung gegen `f7QzURA7k` |
| Dashboard `Jaylab Haus-Zentrale` | CT 102 (`192.168.40.248`) | nicht vorhanden (`HTTP 404`) | `uid: jaylab-haus-zentrale`, **`v2`**, `5` Rows, `23` Daten-Panels | `https://grafana.jaylab.org/grafana/d/jaylab-haus-zentrale/jaylab-haus-zentrale` |
| Alt-Dashboards & Library Panel | CT 102 (`Grafana Enterprise 13.3.1`) | `v40` / `v16` / `v6` / `v8` / `v5` / `v2` | exakt unverändert `v40` / `v16` / `v6` / `v8` / `v5` / `v2` | API-Abgleich gegen Vorabstand + `verify-dashboards.ps1` |

## Istzustand und Abhängigkeiten

- **CT 105 (`nodered`):** `proxmox` → `vmbr0` → `net0` (`eth0`, `192.168.40.223/24` sowie globale und lokale IPv6-Adressen; `onboot: 1`, `unprivileged: 1`, `nesting=1`, RootFS `local-lvm:vm-105-disk-0`). Laufzeitumgebung gemäß [AENDERUNG-NODERED-UPGRADE-2026-11-22.md](AENDERUNG-NODERED-UPGRADE-2026-11-22.md) und [AUTOMATISIERUNG-ZUGAENGE.md](AUTOMATISIERUNG-ZUGAENGE.md): Node.js `24.22.3` (`/usr/local/bin/node`), Node-RED `5.0.10`, `node-red-contrib-bosch-shc` `0.8.39`, aktives Projekt `/home/jay/.node-red/projects/nodered-managed/`, `contextStorage: null` (Standard-RAM-Kontext; `settings.js` und `flows_cred.json` unverändert).
- **CT 102 (`grafana`):** `proxmox` → `vmbr0` → `net0` (`eth0`, `192.168.40.248/24` sowie IPv6; `onboot: 1`, `startup: order=20,up=10`, RootFS `local-lvm:vm-102-disk-0`). Laufzeitumgebung gemäß [AENDERUNG-GRAFANA-UPGRADE-DASHBOARDS-2026-11-22.md](AENDERUNG-GRAFANA-UPGRADE-DASHBOARDS-2026-11-22.md): Ubuntu `24.04.5 LTS`, `Grafana Enterprise 13.3.1` (`commit: da3aa3ff574e7dbbf808c66b6daa744defed0441`), Unified Storage in SQLite, Datenquelle `InfluxDB` (`uid: f7QzURA7k`, Cloud-Buckets `shcbucket` und `zigbee2mqtt`).
- **Reverse Proxy und Authentisierung:** Caddy CT 131 terminiert `https://grafana.jaylab.org` und `https://nodered.jaylab.org` mit Authentik-OIDC (`https://login.jaylab.org`); die lokale API-Automatisierung verwendet die gespeicherten Zugangsdaten unter `.local/access/credentials/grafana.clixml` bzw. die bestehenden SSH-Profile unter `.local/access/ssh_config_wsl` auf `jaylab-proxmox`.
- **Kritische Abhängigkeiten und Schutzregeln:**
  - `shc-device`-Nodes interpretieren `boolean` (`PowerSwitch`, `PowerMeter`, `IntrusionDetectionControl`, `PresenceSimulationConfiguration`) und Zahlenwerte (`RoomClimateControl`) als Schreibbefehl (`putState`) — inklusive Rücksetzen von `PowerMeter.energyConsumption` auf `0`. Alle lesenden Poll-`inject`s senden daher strikt `payloadType: "str"` mit leerem String `payload: ""`.
  - Das geteilte Library Panel `wbQMs6J4k` im Alt-Dashboard `_ts0ZCT4k` filtert `ShutterContact` nicht nach `deviceId`; daher bleibt `ShutterContact` strikt auf den bisherigen `6` Alt-Kontakten, während alle `9` Kontakte getrennt in `contactStatus` erfaßt werden.
  - Der Aqara-Sensor `Tiefkeller` (`zigbee2mqtt/0x00158d00091a4176`) funkt derzeit länger als `24 h` nicht (`Alter=234,4 Std.`); die `Raum-Matrix` blendet seinen Live-Wert gemäß 24h-Frischeregel mit `–` aus, während Row 5 (`Aqara-Diagnose`) den letzten bekannten Wert (`11,48 °C`) und das Alter ausweist.

## Konkrete Änderung

### 1. CT 105: Deterministischer Flow-Patch und Zustandslogik (Node-RED)

Die zentrale Geräte- und Farbdefinition [devices.json](../scripts/haus-zentrale/devices.json), die reine Verarbeitungslogik [nodered_logic.js](../scripts/haus-zentrale/nodered_logic.js) und der idempotente Patcher [build_nodered_flows.js](../scripts/haus-zentrale/build_nodered_flows.js) wurden vorab lokal geprüft und über `.local/changes/2026-11-24-haus-zentrale/Deploy-NodeRedFlows.ps1` auf CT 105 ausgerollt:

1. **Alte Tabs minimalinvasiv ergänzt:**
   - Tab `Temperatur`: `HT-EG-Schlafzimmer` (`...748B`) und `HT-Ankleidezimmer` (`...46BB`) eingebunden; `join` auf `count: 11`, `timeout: 30` angepaßt.
   - Tab `Ventilstellung`: beide TRVs ergänzt; `join` auf `count: 10`, `timeout: 30` angepaßt.
   - Tab `Fensterkontakt`: doppeltes `Tür Hauseingang`-Node entfernt; alle `6` Alt-Kontakte in `ShutterContact` belassen und Poll-`inject`s auf `payload: ""` festgelegt.
2. **Drei neue Tabs ergänzt (alle Poll-`inject`s mit `payloadType: "str"`, `payload: ""`):**
   - `Steckdosen & Geräte`: pollt `PowerMeter` und `PowerSwitch` alle `60 s` plus Long-Poll für alle `4` Smart-Steckdosen (`Waschmaschine`, `Creality`, `ZS Kompressor`, `Springer`), schreibt `powerMeter` (überspringt `null`-Leistungs-/Energiewerte sauber) und führt den entprellten Zustandsautomaten `applianceState` (`Aus`/`Bereit`/`Läuft` bzw. `Druckt`/`Fertig`; Schwellwerte `Waschmaschine` `>= 10 W / 60 s`, `< 4 W / 300 s`; `Creality` `>= 15 W / 60 s`, `< 8 W / 300 s`; `doneAutoResetMin = 240`, `cycleEnergyWh >= 0`).
   - `Raumklima (Soll)`: erfaßt alle `9` `ROOM_CLIMATE_CONTROL`-Dienste (`setpoint`, `hasDemand`, `boostMode`, `ventilationMode`, `summerMode`, `operationMode`) in `roomClimate`.
   - `Sicherheit & Gesundheit`: erfaßt `securityStatus` (`intrusionDetectionSystem`, `presenceSimulationService`), `deviceHealth` (alle `25` physischen SHC-Geräte einschließlich `Springer` und `Außenkamera 3yes`, mit `faultCount`/`faultSummary`) sowie `contactStatus` (alle `9` Kontakte mit expliziter `UNAVAILABLE`-Kennzeichnung für `Garagentor` und `Tür Hauseingang`).
3. **Dateizustand CT 105 nach Aktivierung (24. November 2026, `21:16:07Z`):**
   - `/home/jay/.node-red/projects/nodered-managed/flows.json`: Eigentümer `jay:jay`, Modus `0644`, Größe `181547` Byte (`148` Nodes), SHA-256 `b4a18a42ff29cd78b58177d6fc361fd5087cc3357d07d50cafcdb11f9d434e0a` (gegenüber Vorabstand `68198` Byte, `118` Nodes, SHA-256 `4355938dc63a09cd17a2c2744a11bcc4bd52a000323ebbc75293c731090b904e`).
   - Hinweis aus der Skriptausführung: Beim ersten Aktivierungslauf löste eine PowerShell-Pipeline-Zeilenende-Abweichung (`\r\n` an `bash -s`) am Skriptende trotz aktiviertem Dienst automatisch `Rollback-NodeRedFlows.ps1` aus; beide Skripte wurden auf ASCII-Base64-Übertragung umgestellt, die Rücknahme vorab live mit Exit-Code `0` getestet und `Deploy-NodeRedFlows.ps1 -Mode ActivateOnly` danach fehlerfrei ausgeführt.

### 2. CT 102: Dashboard-Erzeugung, API-Rollout und Live-Korrektur (`Fenster & Türen`)

Das Dashboard-JSON wurde deterministisch mit [build_grafana_dashboard.ps1](../scripts/haus-zentrale/build_grafana_dashboard.ps1) nach `.local/changes/2026-11-24-haus-zentrale/candidate-dashboard.json` erzeugt und mittels `.local/changes/2026-11-24-haus-zentrale/Deploy-GrafanaDashboard.ps1` über `POST /grafana/api/dashboards/db` eingespielt:

- **Struktur (`uid: jaylab-haus-zentrale`, Standardfenster `now-24h..now`, Refresh `1m`):**
  - **Row 1 (`Auf einen Blick`, offen, `7` Panels):** `Waschmaschine — Status`, `Waschmaschine — 6h Leistung` (`4 W` / `10 W` Schwellen), `Creality (3D-Drucker)`, `Weitere Steckdosen (ZS Kompressor & Springer)`, `Fenster & Türen`, `Alarmsystem & Anwesenheit`, `Auffällige Geräte`.
  - **Row 2 (`Heizung & Raumklima`, offen, `4` Panels):** `Raum-Matrix (11 Klimaräume)` (spaltenweise Targets + `joinByField` auf `Raum`, `Raumthermostat` als Primärfühler in `E2 Wohn-/Eßzimmer`, Aqara-Bevorzugung `< 24 h` mit SHC-Fallback, `–` bei `> 24 h`-Funkstille reiner Aqara-Räume), `Temperatur-Verlauf`, `Ventilstellung`, `Luftfeuchtigkeit` (`40–60 %`-Komfortzone).
  - **Row 3 (`Energie & Verbraucher`, eingeklappt, `3` Panels):** `Leistungsverlauf (W)`, `Energieverbrauch je Zeitraum (kWh)`, `Verbraucher-Übersicht`.
  - **Row 4 (`Türen, Fenster & Wetter`, eingeklappt, `4` Panels):** `Tür- und Fenster-Verlauf` (`9/9` Kontakte A–Z), `Luftdruck (aktuell)`, `Luftdruck 3h-Tendenz`, `Luftdruck 7-Tage-Verlauf`.
  - **Row 5 (`Sensoren & Technik`, eingeklappt, `5` Panels):** `SHC-Gerätegesundheit` (`25` Geräte), `Aqara-Diagnose` (`6` Sensoren inkl. Alter in Std.), `Aqara Batteriespannung`, `Aqara Batterie in %`, `Aqara Funkqualität (LQI)` (jeweils `14d`).
- **Live-Fehlerfund und Nachbesserung (`v1` → `v2`):**
  - Bei der ersten Live-Abnahme von `v1` meldete das Row-1-Panel `Fenster & Türen` (`contactStatus`) fälschlich `0 offen (von 0 erreichbar)`. Ursache war, daß `$contactBaseFlux` in `stats` das Feld `deviceId` vor `union(tables: [anchor, stats]) |> reduce(...)` verwarf, wodurch InfluxDB zeilenidentische geschlossene Kontakte zusammenzog.
  - In [build_grafana_dashboard.ps1](../scripts/haus-zentrale/build_grafana_dashboard.ps1) wurde in `base` `|> sort(columns: ["name"])` ergänzt, im `anchor` `deviceId: "_none_"` und in `stats` `deviceId: r.deviceId` erhalten sowie die `reduce`-Reduktion für `openNames` und `unavailNames` mit `not exists`-Schutz abgesichert (`reduce()` verbraucht `deviceId`, so daß kein rohes `deviceId`-Feld im Ergebnis verbleibt).
  - Ergänzende Regressionstests wurden in [Test-HausZentraleDashboard.ps1](../scripts/haus-zentrale/tests/Test-HausZentraleDashboard.ps1) hinterlegt (erst fehlgeschlagen, nach Korrektur bestanden), der Kandidat neu erzeugt und als **`v2`** (`HTTP 200`, `status=success`, `uid=jaylab-haus-zentrale`) auf CT 102 aktiviert.

## Sicherung und Rücknahme

- **Unabhängiger Zugang:** Host `jaylab-proxmox` über WSL-SSH (`pct exec 105`, `pct restore 105`, `pct exec 102`) sowie Grafana-HTTP-API mit `.local/access/credentials/grafana.clixml` (unverändert gegenüber [BETRIEB.md](BETRIEB.md)).
- **Sicherungen für CT 105 (`nodered`):**
  - **PBS-Snapshot auf `proxmox-backupserver` (Namespace `containerbackup`):** `proxmox-backupserver:backup/ct/105/2026-11-24T21:12:42Z` (`3685564952` Byte, erstellt am 24. November 2026 vor Änderung über `vzdump 105 --storage proxmox-backupserver --mode snapshot --notes-template "pre-haus-zentrale-2026-11-24"`).
  - **Off-Container-Dateisicherung auf `proxmox`:** `/root/.local/jaylab/haus-zentrale-20261124/` (Verzeichnis `0700`, Dateien `0600`): `flows.json.original` (`68198` Byte, SHA-256 `4355938dc63a09cd17a2c2744a11bcc4bd52a000323ebbc75293c731090b904e`), `.sha256` und `flows.json.candidate` (`181547` Byte).
  - **Lokale Kopie (ohne `flows_cred.json`):** `.local/changes/2026-11-24-haus-zentrale/before/flows.original.json` und `.sha256`.
- **Sicherungen für CT 102 (`grafana`):**
  - **Vorab-API-Export (`capturedAtUtc: 2026-11-24T21:26:39Z`):** Alle fünf Bestandsdashboards und das Library Panel unter `.local/changes/2026-11-24-haus-zentrale/before-api/` (`_ts0ZCT4k.json` `v40`, `mttazdTnz.json` `v16`, `unEDfmJVk.json` `v6`, `kgz9x6J4z.json` `v8`, `YjZPR_A7k.json` `v5`, `wbQMs6J4k.json` `v2`) sowie Manifest `.local/changes/2026-11-24-haus-zentrale/before-api/pre-versions.json` (`target.exists: false`, `status: 404`).
- **Rücknahmeverfahren CT 105 (`flows.json` / vollständiger Container):**
  - *Schnelle Flow-Rücknahme (vor Aktivierung live gegen CT 105 mit Exit-Code `0` getestet):*
    ```powershell
    pwsh -NoProfile -File .local/changes/2026-11-24-haus-zentrale/Rollback-NodeRedFlows.ps1
    ```
    Hält `nodered.service` an, prüft SHA-256 von `/root/.local/jaylab/haus-zentrale-20261124/flows.json.original` gegen `.sha256` (`4355938d...`), schreibt mit `jay:jay` `0644` zurück und startet `nodered.service`.
  - *Vollständiges Container-Restore auf `jaylab-proxmox`:*
    ```bash
    pct stop 105
    pct restore 105 proxmox-backupserver:backup/ct/105/2026-11-24T21:12:42Z --storage local-lvm --force 1
    pct start 105
    ```
- **Rücknahmeverfahren CT 102 (`jaylab-haus-zentrale` spurlos entfernen):**
  ```powershell
  pwsh -NoProfile -File .local/changes/2026-11-24-haus-zentrale/Deploy-GrafanaDashboard.ps1 -Mode Rollback
  ```
  Entspricht `DELETE /grafana/api/dashboards/uid/jaylab-haus-zentrale` mit anschließender Gegenprüfung auf `HTTP 404` sowie Abgleich aller Alt-Dashboard-Versionen (`v40/v16/v6/v8/v5/v2`).
- **Erfolgskontrolle nach möglicher Rücknahme:** `Test-JaylabNodeRed.ps1` (`flowNodes: 118`), `Test-JaylabAutomation.ps1 -Service shc` sowie `.local/changes/2026-11-22-grafana/verify-dashboards.ps1`.

## Abnahme

| Quelle / Zone | Ziel / Dienst / IP-Version | Erwartet | Gemessen / Beleg |
| --- | --- | --- | --- |
| Windows lokal (Unit-/Generator-Tests) | `node --test scripts/haus-zentrale/tests/*.test.js` & [Test-HausZentraleDashboard.ps1](../scripts/haus-zentrale/tests/Test-HausZentraleDashboard.ps1) | Alle Tests bestanden, `0` Fehler | Bestanden (`BESTANDEN: Dashboard 'jaylab-haus-zentrale' mit 28 Panels in 5 Rows...`) |
| Windows lokal (Workspace-Prüfung) | [Test-Workspace.ps1](../scripts/Test-Workspace.ps1) | Inventar, Skills, relative Links und PowerShell-Syntax ohne Fehler | Bestanden (`0` Fehler, keine defekten Verweise) |
| `proxmox` (`pct exec 105`) | CT 105 `nodered.service` & Journal | `active`, `Node-RED v5.0.10`, `Node.js v24.22.3`, MQTT + SHC Long-Poll aktiv, keine `hz_*`-/`putState`-Fehler | Bestanden (`PID 2222`, `Started flows`, `MQTT Connected`, `Long polling SHC: 192.168.40.231`) |
| Windows → CT 105 / CT 107 / SHC | [Test-JaylabAutomation.ps1](../scripts/Test-JaylabAutomation.ps1) (`shc`, `nodered`, `mqtt-tls`) & [Test-JaylabNodeRed.ps1](../scripts/Test-JaylabNodeRed.ps1) | `shc` lesbar, `nodered` aktiv, `mqtt-tls` inkl. Negativtests bestanden, Node-RED-API `GET 200` (`148` Nodes) & anonyme/schreibende Zugriffe `401` | Bestanden (`EXIT 0`; `15` Räume, `38` Geräte, `166` Dienste, `8` Szenarien; `tlsVerified: true`, `authenticatedGet: 200`, `flowNodes: 148`, `anonymousGet/invalidTokenGet/writeDenied: 401`, `flowsUnchanged: true`) |
| CT 105 → InfluxDB Cloud (`f7QzURA7k`, `now-15m`) | `powerMeter`, `applianceState`, `roomClimate`, `securityStatus`, `deviceHealth`, `contactStatus`, `temperature`, `valveTappetState`, `ShutterContact` | Alle `6` neuen Measurements aktiv, `temperature` `11/11`, `valveTappetState` `10/10`, `ShutterContact` strikt `6` Alt-Kontakte | Bestanden (`powerMeter`: `4` inkl. `Springer`; `applianceState`: `2`; `roomClimate`: `9`; `securityStatus`: `3`; `deviceHealth`: `25`; `contactStatus`: `9`; `temperature`: `11/11`; `valveTappetState`: `10/10`; `ShutterContact`: strikt `6` Alt-Kontakte) |
| Windows → CT 102 (`Verify-HausZentrale.ps1`, 3× `/grafana/api/ds/query` auf `v2`) | Alle `23` Daten-Panels (inkl. eingeklappte Rows 3–5), `Raum-Matrix`, `Fenster & Türen`, kanonische Namen | `3×` identische Ergebnisse, `0` Query-Fehler, `0` rohe `deviceId`-Felder/-Labels, `0`× `Ela-Wandheizung`, `Springer` sichtbar | Bestanden (`VERIFY HAUS-ZENTRALE: ALL CHECKS PASSED`; `Fenster & Türen`: `0 offen (von 7 erreichbar)`, `Nicht erreichbar`: `2: Garagentor, Tür Hauseingang`; `Raum-Matrix` `11/11` inkl. `Keller / Tiefkeller` `Ist=–` / `Feuchte=–` bei `Alter=234,4 Std.`; Row 2 `16/10/6`; Row 3 `4/4/4`; Row 4 `9/9`, `984,1 hPa`, `-1,8 hPa`, `7d=5`; Row 5 `25/25`, `6/6`) |
| Windows → CT 102 (Bestandsschutz) | Alle `5` Alt-Dashboards + `wbQMs6J4k` + `verify-dashboards.ps1` + `ShutterContact` | Versionen identisch zum Vorabstand, `verify-dashboards.ps1` `PASS`, strikt `6` Alt-Kontakte | Bestanden (`_ts0ZCT4k v40`, `mttazdTnz v16`, `unEDfmJVk v6`, `kgz9x6J4z v8`, `YjZPR_A7k v5`, `wbQMs6J4k v2`; `ALL 3 RUNS IDENTICAL & NON-EMPTY (ZERO RAW DEVICE IDs IN BSHC): PASS`) |
| Windows → CT 102 (Negativtests ohne Auth-Header) | `GET /grafana/d/jaylab-haus-zentrale/...`, `GET /grafana/api/dashboards/uid/jaylab-haus-zentrale`, `POST /grafana/api/ds/query` | UI-Redirect `302` auf Login, API `401` | Bestanden (`GET UI -> 302` auf `/grafana/login?redirectTo=%2Fd%2Fjaylab-haus-zentrale%2Fjaylab-haus-zentrale`; `GET API -> 401`; `POST /api/ds/query -> 401`) |

## Abschluß

- **Aktivierungsstand und Persistenz:** Auf CT 105 läuft `nodered.service` produktiv mit der geänderten Projektdatei `flows.json` (`148` Nodes, `jay:jay 0644`); auf CT 102 ist das Dashboard `jaylab-haus-zentrale` in Version **`v2`** über den Unified Storage von `Grafana Enterprise 13.3.1` dauerhaft gespeichert. Alle fünf Bestandsdashboards und `wbQMs6J4k` stehen unverändert zur Verfügung.
- **Sicherung und aufgehobener Rücklauf:** Auf `proxmox-backupserver` liegt der Vorab-Snapshot von CT 105 (`proxmox-backupserver:backup/ct/105/2026-11-24T21:12:42Z`); die vollständigen Dateisicherungen und Vorab-API-Exporte liegen auf `proxmox` unter `/root/.local/jaylab/haus-zentrale-20261124/` (`0700`/`0600`) sowie lokal unter `.local/changes/2026-11-24-haus-zentrale/`. Während der Aktivierung waren keine vorläufigen Notfall-Zeitgeber aktiv.
- **Host-Hinweis / Restrisiken (außerhalb des Vorhaben-Umfangs):**
  - `vzdump 105` meldete auf `proxmox` eine bestehende LVM-Thin-Pool-Überprovisionierungswarnung (`Sum of all thin volume sizes (200.00 GiB)` auf `pve/data` gegenüber `16.00 GiB` Poolgröße). Dieser Hostzustand ist unabhängig von dieser Änderung und für die weitere Hostpflege vorzumerken.
  - Der Aqara-Sensor `Tiefkeller` liefert seit `234,4 Std.` (`> 24 h`) keine Meßwerte und wird wie vorgesehen in Row 1 (`Auffällige Geräte`) und Row 5 (`Aqara-Diagnose`: `11,48 °C`) markiert, in Row 2 (`Raum-Matrix`) ausgeblendet.
- **Offene Betreiberpunkte / nächste Schritte:**
  1. **Authentisierte Browser-Sichtprüfung:** `https://grafana.jaylab.org/grafana/d/jaylab-haus-zentrale/jaylab-haus-zentrale` in einer angemeldeten Sitzung öffnen, inklusive `F5`-Neuladen sowie Aufklappen und visueller Kontrolle der Rows 3–5 (`Energie & Verbraucher`, `Türen, Fenster & Wetter`, `Sensoren & Technik`).
  2. **Schwellwert-Nachkalibrierung (`applianceState`):** Nach dem ersten vollständigen realen Waschgang bzw. 3D-Druck die Startparameter im Konfigurationsobjekt auf CT 105 (`Waschmaschine`: `>= 10 W / 60 s`, `< 4 W / 300 s`; `Creality`: `>= 15 W / 60 s`, `< 8 W / 300 s`) gegen den aufgezeichneten `powerMeter`-Verlauf prüfen und bei Bedarf nachjustieren.
