# Änderung: Node-RED und Plugins auf CT 105 aktualisiert

## Ergebnis und Umfang

Am 22. November 2026 wurden Node.js, Node-RED und alle ausstehenden
Erweiterungen einschließlich der Bosch-SHC-Anbindung auf `proxmox`, CT 105
(`nodered`), nach erfolgreicher Offline-Probe und Code-Kompatibilitätsprüfung
produktiv aktualisiert. Die Beauftragung umfaßte zunächst die vollständige
Prüfung und Fortsetzung der Aktualisierung unter Wahrung der bestehenden
Bosch-Kopplung und der vorhandenen Flows (`142` Elemente, SHA-256
`716598448266ff0141c40a99d8fc2fa7a34aa4a4913964f639f15aa2b817f4d1`) sowie
anschließend die ausdrücklich beauftragte Entfernung von `node-red-dashboard`
samt seiner `24` `ui_*`-Nodes (`118` verbleibende Elemente, SHA-256
`4355938dc63a09cd17a2c2744a11bcc4bd52a000323ebbc75293c731090b904e`). Die
Ausfallzeit beschränkte sich auf das Anhalten und Neustarten von
`nodered.service` in CT 105; eine andere Änderung am Repository
(`router/dnsmasq/hosts`) blieb unberührt.

| Komponente | Vorher | Nachher | Zielort |
| --- | --- | --- | --- |
| Node.js (Dienst / Login) | `18.19.0` | `24.22.3` | `/opt/node-v24.22.3` via `/usr/local/bin/{node,npm,npx}` |
| npm (Dienst / Login) | `9.2.0` | `11.19.1` | `/opt/node-v24.22.3` via `/usr/local/bin/npm` |
| Node-RED (global) | `3.0.2` | `5.0.10` | `/usr/local/lib/node_modules/node-red` |
| `node-red-contrib-bosch-shc` | `0.3.30` | `0.8.39` | `/home/jay/.node-red/node_modules/` |
| `bosch-smart-home-bridge` (Abhängigkeit) | `1.2.2` | `1.8.1` | `/home/jay/.node-red/node_modules/` |
| `node-red-contrib-influxdb` | `0.6.1` | `0.7.0` | `/home/jay/.node-red/node_modules/` |
| `node-red-contrib-influxdb-backup` | `0.1.0` | `1.0.0` | `/home/jay/.node-red/node_modules/` |
| `node-red-contrib-zigbee2mqtt` | `2.7.1` | `3.1.0` | `/home/jay/.node-red/node_modules/` |
| `node-red-dashboard` | `3.6.2` | `3.6.6` → entfernt | `/home/jay/.node-red/node_modules/` (abgekündigt, anschließend deinstalliert) |
| `node-red-node-pi-gpio` | `2.0.6` | `2.0.7` | `/home/jay/.node-red/node_modules/` |
| `node-red-node-serialport` | `1.0.1` | `2.0.3` | `/home/jay/.node-red/node_modules/` |
| `passport-openidconnect` | `0.1.1` | `0.1.2` | `/home/jay/.node-red/node_modules/` |

Unverändert blieben `node-red-contrib-play-audio` (`2.5.0`),
`node-red-node-ping` (`0.3.3`), `node-red-node-random` (`0.4.1`) und
`node-red-node-smooth` (`0.1.2`).

## Istzustand und Abhängigkeiten

- **Container-Pfad und Netz:** `proxmox` (`host`) → `vmbr0` → `net0` (`eth0`,
  MAC `82:ad:f4:05:ad:71`, `192.168.40.223/24` sowie globale und lokale
  IPv6-Adressen), CT 105 (`onboot: 1`, `unprivileged: 1`, `nesting=1`, RootFS
  `local-lvm:vm-105-disk-0`, 8 GB, kein zusätzlicher Mountpunkt).
- **Dienstausführung:** `nodered.service` läuft unter Benutzer `jay` mit
  `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`,
  `ExecStart=/usr/bin/env node-red-pi $NODE_OPTIONS $NODE_RED_OPTIONS`,
  `NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/ca-jaylab-local.crt`,
  lokalem HTTPS auf Port `1880` (`Jaylab Automation CA 2026`), Projekt
  `nodered-managed` und OIDC-Anbindung an Authentik (`https://login.jaylab.org`)
  über Caddy (`https://nodered.jaylab.org`).
- **Debian-Systempakete vs. `/usr/local/bin`:** Debians `nodejs`
  (`18.19.0+dfsg-6~deb12u2`) und `npm` (`9.2.0~ds1-1`) in `/usr/bin/` wurden
  unberührt gelassen, da rund 32 installierte `node-*`-Pakete davon abhängen.
  Login-Shells (`su -l root`, `su -l jay`) und `systemd` ziehen
  `/usr/local/bin` vor; nicht-interaktive `pct exec 105`-Aufrufe laufen
  jedoch mit `PATH=/sbin:/bin:/usr/sbin:/usr/bin`. Deshalb wurden auch die
  CT-105-Prüfbefehle in [Test-JaylabAutomation.ps1](../scripts/Test-JaylabAutomation.ps1)
  auf `/usr/local/bin/node` umgestellt.
- **Bereinigtes Paketduplikat:** Die veraltete Kopie unter
  `/home/jay/package.json`, `/home/jay/package-lock.json` und
  `/home/jay/node_modules/` (`bosch-shc` `0.3.30` / Bridge `1.2.2`) wurde
  entfernt; [Test-JaylabShc.js](../scripts/Test-JaylabShc.js) lädt die Bridge
  nun aus `/home/jay/.node-red/node_modules/bosch-smart-home-bridge`.
- **Code-Kompatibilitätsprüfung vor Aktivierung:** Die Quellvergleiche der
  genutzten Nodes (`shc-device.js`, `shc-fault.js`, `shc-scenario.js`,
  `shc-config.js`, `zigbee2mqtt` `in.js`/`server.js`/`bridge.js`, `influxdb.js`,
  `passport-openidconnect/lib` und Node-RED-5-`genericStrategy`/`ace`)
  ergaben keine inkompatiblen Schnittstellenänderungen für die vorhandenen Flows.
- **Einordnung früherer Nebenbefunde:**
  - Die Journal-Warnungen von `extractTemperature`, `extractValveTapperState`,
    `extractHumidity`, `getWindowEvent` und `convertPayLoadToMeasurement`
    stammen aus expliziten `node.warn(msg)`-Aufrufen in den bestehenden
    Funktionsnodes des Projekts.
  - Das scheinbare Stehenbleiben des in `/opt/zigbee2mqtt/data/database.db`
    gespeicherten `lastSeen`-Werts beim Sensortest (`0x00158d00091a463f`)
    erklärt sich durch `zigbee-herdsman` (`controller.js:160`), das
    `databaseSave()` nur stündlich (`3600000` ms) oder beim Herunterfahren auf
    Platte schreibt (letzte Dateischreibung auf CT 121:
    `2026-11-22 12:10:23 UTC` vor dem Sensortest um `12:45 UTC`).

## Vorab-Erprobung und konkrete Änderung

1. **Isolierte Vorab-Probe in CT 118 (bereits vor Produktivumstellung erfolgt):**
   - Sicherung `proxmox-backupserver:backup/ct/105/2026-11-22T12:11:01Z` nach
     CT 118 (`local-lvm`, ohne `net0`, `onboot: 0`) wiederhergestellt.
   - Dort Node.js `24.22.3`, Node-RED `5.0.10` und alle Zielpakete offline
     getestet (`142` Flow-Elemente über API, `/ui/`-Assets HTTP 200,
     `node-red-contrib-zigbee2mqtt` v3.1.0-Quelltests, Offline-Neubau von
     `@serialport/bindings-cpp@12.0.1` und `node-red-dashboard@3.6.6`).
   - Getrennte Lese- und Ereignisproben in CT 105 bestätigten vorab:
     Bosch-Bridge `1.8.1` + `shc-device` `0.8.39` verarbeiten reale
     Zustandsmeldungen; `node-red-contrib-zigbee2mqtt` `3.1.0` verarbeitet reale
     MQTT-Meldungen von `0x00158d00091a463f`; `node-red-contrib-influxdb`
     `0.7.0` übergibt synthetische Punkte aller sieben Ausgabe-/Batch-Nodes.
2. **Produktivaktualisierung auf CT 105 (`2026-11-22`):**
   - Frische PBS-Snapshot-Sicherung erstellt (`13:00:48Z`).
   - Node.js `v24.22.3` (zuvor gegen die Hersteller-SHA-256-Prüfsumme geprüft)
     aus `/root/.local/jaylab/nodered-upgrade-20261122/` über
     `/root/nodered-upgrade-stage` nach `/opt/node-v24.22.3` übertragen;
     Symlinks `/usr/local/bin/{node,npm,npx}` gesetzt.
   - `nodered` gestoppt, `node-red@5.0.10` global unter `/usr/local` und die
     acht Zielpakete unter `/home/jay/.node-red` vollständig `--offline`
     installiert.
   - `npm install-scripts ls` zeigte ausschließlich
     `@serialport/bindings-cpp@12.0.1` und `node-red-dashboard@3.6.6`; beide
     Skripte wurden ausdrücklich freigegeben und offline per `npm rebuild`
     ausgeführt (`fixgrid.js` meldete erwartungsgemäß das Nichtvorhandensein
     vier veralteter jQuery-Dateien; `node-gyp-build` baute erfolgreich).
   - Eigentümer von `node_modules`, `package.json` und `package-lock.json`
     unter `/home/jay/.node-red` auf `jay:jay` zurückgesetzt (Schlüssel- und
     Konfigurationsrechte unverändert), Duplikat unter `/home/jay/` sowie
     `/root/nodered-upgrade-stage` entfernt und `nodered` um
     `13:03:46 UTC` gestartet.
   - Lokale Prüfskripte [Test-JaylabShc.js](../scripts/Test-JaylabShc.js) und
     [Test-JaylabAutomation.ps1](../scripts/Test-JaylabAutomation.ps1) auf den
     aktuellen Pfad und `/usr/local/bin/node` angepaßt;
     [AUTOMATISIERUNG-ZUGAENGE.md](AUTOMATISIERUNG-ZUGAENGE.md) aktualisiert.
3. **Bereinigung und Entfernung von `node-red-dashboard` (`2026-11-22`):**
   - Nach Abschluß der Browserprüfung wurde eine weitere PBS-Snapshot-Sicherung
     (`proxmox-backupserver:backup/ct/105/2026-11-22T13:35:18Z`,
     `3547707535` Byte) des lauffähigen Node-RED-`5.0.10`-Standes erstellt.
   - Auf `proxmox` wurde das Vorbereitungsverzeichnis
     `/root/.local/jaylab/nodered-upgrade-20261122/` gelöscht
     (`staging_removed: ok`). Das Löschen des gestoppten Testcontainers
     CT 118 (`pct destroy 118 --purge`) wurde von der Werkzeugumgebung
     verworfen; CT 118 blieb daher unberührt (`stopped`, ohne `net0`,
     `onboot: 0`) für eine direkte Ausführung auf `proxmox`.
   - In CT 105 wurde `nodered` gestoppt. Aus
     `/home/jay/.node-red/projects/nodered-managed/flows.json` wurden vor der
     Deinstallation die `24` `ui_*`-Nodes (`1` `ui_base`, `4` `ui_tab`,
     `7` `ui_group`, `12` `ui_gauge`) und alle `12` darauf verweisenden
     Wire-Verknüpfungen entfernt (`142` → `118` Elemente, `0` Restverweise,
     neuer SHA-256
     `4355938dc63a09cd17a2c2744a11bcc4bd52a000323ebbc75293c731090b904e`);
     `flows_cred.json` und das Projekt-Git-Repository blieben ohne Commit/Push.
   - Anschließend wurde `node-red-dashboard` (`3.6.6`, `47` Pakete) offline
     deinstalliert, der `allowScripts`-Eintrag `node-red-dashboard@3.6.6` aus
     `/home/jay/.node-red/package.json` entfernt (es verbleibt nur
     `@serialport/bindings-cpp@12.0.1`), die Eigentümerschaft auf `jay:jay`
     gestellt und `nodered` um `13:37:30 UTC` neu gestartet. Beim ersten Start
     bereinigte Node-RED seine interne Modulregistrierung (`Removing modules
     from config`, `0` Treffer in `.config.nodes.json`).

## Sicherung und Rücknahme

- **Vorab-Sicherung (Probe):** `proxmox-backupserver:backup/ct/105/2026-11-22T12:11:01Z`
- **Produktivsicherung vor Upgrade auf `5.0.10` (`3.0.2`-Rückfallpunkt):**
  `proxmox-backupserver:backup/ct/105/2026-11-22T13:00:48Z` (`vzdump 105`,
  Snapshot-Modus, `3309104329` Byte).
- **Frische Produktivsicherung vor Dashboard-Rückbau (`5.0.10`-Stand mit Dashboard):**
  `proxmox-backupserver:backup/ct/105/2026-11-22T13:35:18Z` (`vzdump 105`,
  Snapshot-Modus, `3547707535` Byte; alle PBS-Sicherungen ohne clientseitige
  Verschlüsselung, Speicherzugang daher geschützt halten).
- **Unabhängiger Zugang:** Host `jaylab-proxmox` über SSH (`wsl.exe`) und
  `pct exec 105` bzw. `pct restore` bleiben vom Node-RED-Container unabhängig.
- **Konkreter Rücknahmebefehl auf `jaylab-proxmox` (bei Bedarf auf Stand vor Dashboard-Entfernung; für `3.0.2` stattdessen `2026-11-22T13:00:48Z`):**
  ```bash
  pct stop 105
  pct restore 105 proxmox-backupserver:backup/ct/105/2026-11-22T13:35:18Z --storage local-lvm --force 1
  pct start 105
  ```
  Vor einer Rücknahme sind seit `13:35:18 UTC` eingetretene Änderungen im
  Container zu berücksichtigen; anschließend `Test-JaylabNodeRed.ps1` sowie
  `Test-JaylabAutomation.ps1 -Service shc` und `-Service mqtt-tls` ausführen.

## Abnahme

| Quelle / Zone | Ziel / Dienst / IP-Version | Erwartet | Gemessen / Beleg |
| --- | --- | --- | --- |
| `proxmox` (`pct exec`) | CT 105 `nodered.service` / `/usr/local/bin/node` | `active`, `enabled`, Node `v24.22.3`, Node-RED `v5.0.10`, Bridge `1.8.1`, Serial-Binding lädt | Bestanden (`13:03:46 UTC` gestartet, `serial binding load: ok`, `1.8.1`) |
| `proxmox` (`pct exec`) | `journalctl -u nodered` & `flows.json` | Flows gestartet, SHC-Longpoll + MQTT verbunden, keine fehlenden Node-Typen, SHA-256 unverändert | Bestanden (`Started flows`, `MQTT Connected`, SHC-Poll `g6gddd9ce-54`, Hash identisch) |
| Windows → SSH → CT 105 (IPv4 TLS) | [Test-JaylabNodeRed.ps1](../scripts/Test-JaylabNodeRed.ps1) (`https://localhost:1880/flows`) | GET 200 mit `142` Nodes; anonym, falsches Token, POST mit `401` abgewiesen; Flows unverändert | Bestanden (`authenticatedGet: 200`, `flowNodes: 142`, drei Negativtests `401`, `flowsUnchanged: true`) |
| Windows → SSH → CT 105 | [Test-JaylabAutomation.ps1](../scripts/Test-JaylabAutomation.ps1) `-Service nodered` | `ActiveState=active`, `User=jay`, IPv4 `192.168.40.223/24` + IPv6 | Bestanden |
| Windows → SSH → CT 105 (`node 24`) | [Test-JaylabAutomation.ps1](../scripts/Test-JaylabAutomation.ps1) `-Service shc` (`192.168.40.231` IPv4) | Bestehende Zertifikatskopplung liest Info, Räume, Geräte, Dienste, Szenarien | Bestanden (`15` Räume, `38` Geräte, `166` Dienste, `8` Szenarien, alle `ok: true`) |
| Windows → SSH → CT 105 (`node 24`) | [Test-JaylabAutomation.ps1](../scripts/Test-JaylabAutomation.ps1) `-Service mqtt-tls` (`192.168.40.213:8883`) | `valid` verbunden, ohne Clientzertifikat / ohne Kennwort abgewiesen; plus Socket-Check | Bestanden (`valid: true`, Negativtests `false`, `ss` zeigt `ESTAB` zu `.213:8883`) |
| Windows → SSH → CT 121 | [Test-JaylabAutomation.ps1](../scripts/Test-JaylabAutomation.ps1) `-Service zigbee` (`13:31:26 UTC`) | Dienst, WebSocket, MQTT-TLS, serieller Stick und stündliche `database.db`-Speicherung aktiv | Bestanden (`v1.29.2`, `mqttTlsConnected: true`; `database.db` am `2026-11-22 13:10:23 UTC` auf `11325` Byte geschrieben, `lastSeenUtc` für `0x00158d00091a463f` auf `2026-11-22T12:56:01.603Z` vorgerückt) |
| CT 105 (IPv4 TLS) & Windows → Caddy | `https://localhost:1880/ui/`, `https://nodered.jaylab.org/ui/`, `/auth/login`, `/auth/strategy` | Dashboard HTTP 200; OIDC-Strategie liefert HTTP-302-Redirect auf `https://login.jaylab.org` | Bestanden (`/ui/` `200`, `/auth/login` `strategy`, `/auth/strategy` `302` auf Authentik) |
| Browser (Chrome) → `https://nodered.jaylab.org/` | Node-RED-Editor (`v5.0.10`), Tabs, Statusindikatoren, Debug-Seitenleiste (streng nur lesend) | Fehlerfreier Editor ohne fehlende/ungültige Nodes, grüne SHC-/Zigbee-Statusindikatoren | Bestanden (aktive Sitzung `ja`; `v5.0.10`, alle 7 Tabs / `118` Flow-Nodes / `17` Konfigurations-Nodes geladen, `unknownNodes: 0`, `invalidNodes: 0`, `shc-device` `Verbunden`, `zigbee2mqtt` `online`, `133` HTTP-Abrufe `200`/`304`, keine JS-Fehler; OIDC-Neuanmeldung wegen bestehender Sitzung nicht erneut durchlaufen) |
| Browser (Chrome) → `https://nodered.jaylab.org/ui/` | Dashboard-Gruppen (`DG`, `OG`) und `12` Gauges | Oberfläche lädt ohne schwere Fehler; etwaige bestehende Darstellungsbefunde erfassen | Geladen (HTTP `200`, Gruppen `Dachgeschoss` / `Obergeschoss` mit `12` Gauges sichtbar; alle `12` Gauges zeigen mangels `msg.payload`-Anbindung im bestehenden Flow leere Werte/`0`, `GET /ui/loading.html` meldet `404` sowie SVG-`<path>`-/SideNav-Konsolenfehler und `ngTouch`-Warnung) |
| CT 105 Live-Journal (~28 Min. bis `13:31:19 UTC`) | Produktive Bosch- & Zigbee2MQTT-Flows sowie InfluxDB-Ausgabe | Keine InfluxDB-Schreibfehler, keine SHC-/MQTT-Abbruchschleifen | Bestanden (`extractTemperature`, `extractValveTapperState`, `getWindowEvent`, `extractHumidity` und `convertPayLoadToMeasurement` von `13:07:09` bis `13:26:00 UTC` aktiv; keine Fehler/Reconnects, `ESTAB` zu `.213:8883` unter PID `5802`, `CT 118` `stopped`) |
| `proxmox` / CT 105 nach Dashboard-Entfernung (`13:37:30 UTC`) | `nodered.service`, `flows.json`, `npm list`, Socket `8883` | `active`, `118` Elemente (`4355938d...`), kein `node-red-dashboard`, Flows/SHC/MQTT gestartet | Bestanden (`Started flows`, `MQTT Connected`, SHC-Poll `g6gddd9ce-55`, `ESTAB` `.213:8883` unter PID `6013`, `.config.nodes.json` bereinigt) |
| Windows → SSH → CT 105 nach Dashboard-Entfernung | [Test-JaylabNodeRed.ps1](../scripts/Test-JaylabNodeRed.ps1), [Test-JaylabAutomation.ps1](../scripts/Test-JaylabAutomation.ps1) (`nodered`, `shc`, `mqtt-tls`) | API-GET `200` mit `118` Nodes, drei `401`-Negativtests, SHC & MQTT-TLS grün | Bestanden (`flowNodes: 118`, `flowsUnchanged: true`, SHC `15`/`38`/`166`/`8` `ok: true`, MQTT-TLS `valid: true` und Negativtests `false`) |
| CT 105 TLS & Windows → Caddy nach Dashboard-Entfernung | `https://localhost:1880/ui/`, `https://nodered.jaylab.org/ui/`, `/auth/strategy` | `/ui/` HTTP `404` (Negativprüfung), `/auth/strategy` weiterhin `302` auf Authentik | Bestanden (`/ui/` lokal und über Caddy `404`, `/auth/strategy` `302` auf `https://login.jaylab.org`) |
| Windows Workspace | [Test-Workspace.ps1](../scripts/Test-Workspace.ps1) | Inventar, Skills, Verweise, PS-Syntax ohne Fehler | Bestanden (`5` Skills, `0` Fehler) |

## Abschluß

- **Aktivierungsstand:** Produktiv aktiv auf CT 105 (`Node-RED 5.0.10`,
  `Node.js 24.22.3`, `11` Erweiterungspakete ohne `node-red-dashboard`, `118`
  Flow-Elemente, `onboot: 1`, `net0` unverändert). Das Host-Staging
  `/root/.local/jaylab/nodered-upgrade-20261122/` ist entfernt.
- **Sicherung:** Die PBS-Sicherungen
  `proxmox-backupserver:backup/ct/105/2026-11-22T13:00:48Z` (Stand vor
  Upgrade) und `proxmox-backupserver:backup/ct/105/2026-11-22T13:35:18Z`
  (Stand vor Dashboard-Entfernung) liegen auf dem externen PBS bereit.
- **Verbleibende offene Punkte / Restrisiken:**
  1. Der gestoppte Testcontainer **CT 118** (`nodered-upgrade-test`, `onboot: 0`,
     ohne `net0`, enthält Kopien der Original-Zugangsdaten) ließ sich über die
     Werkzeugumgebung (`pct destroy 118 --purge`) nicht löschen und ist vom
     Betreiber manuell auf `proxmox` mit `pct destroy 118 --purge` zu entfernen.
  2. Eine unauthentifizierte Browser-Neuanmeldung über Authentik einschließlich
     Rückleitung auf `/auth/strategy/callback/` wurde nicht erneut erzwungen, da
     das Browserprofil bereits als `ja` angemeldet war (der Redirect von
     `/auth/strategy` auf `https://login.jaylab.org` ist per `curl` geprüft).
  3. Schreibende/schaltende Aktor- und Szenario-Aktionen (z. B. Bosch-Szenarien
     `Alarm an`/`Alarm aus`) wurden bewußt nicht ausgelöst.
  4. Im Projekt-Repository `/home/jay/.node-red/projects/nodered-managed`
     liegen die Flow-Änderungen weiterhin als lokale Arbeitskopie ohne
     `git commit`/`push` vor; bei Bedarf kann eine künftige Oberfläche über
     einen gepflegten Nachfolger (z. B. `@flowfuse/node-red-dashboard`) neu
     aufgebaut werden.
