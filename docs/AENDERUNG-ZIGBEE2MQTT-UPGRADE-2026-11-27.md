# Änderung: Upgrade von CT 121 (Debian 12, Node.js 24 LTS, Zigbee2MQTT 2.14.3)

Stand: 27. November 2026.

## Umfang

In-Place-Upgrade von CT 121 (`zb2mqtt` auf `proxmox`) vom veralteten Stand
(Debian 12 Paketstand August 2024, Node.js `v19.9.0` EOL, Zigbee2MQTT `1.29.2`)
auf den aktuellen Stand:

- Debian 12 (`bookworm`): alle ausstehenden Paketupdates eingespielt (151 Pakete).
- Node.js: veraltete Quelle `node_19.x bullseye` entfernt, Node.js `v24.22.3`
  (NodeSource `node_24.x`) und `pnpm` via `corepack` eingerichtet.
- Zigbee2MQTT: auf Release **`2.14.3`** (`zigbee-herdsman 11.2.0`,
  `zigbee-herdsman-converters 26.125.0`, `zigbee2mqtt-windfront 2.15.1` /
  `zigbee2mqtt-frontend 0.9.21`) aktualisiert.

Das bestehende Zigbee-Netz, `network_key`, `database.db`,
`coordinator_backup.json`, alle zwölf Geräte sowie die MQTT-TLS-Anbindung
(`mqtts://mqtt.jaylab.local:8883`, `/root/ca.crt`, `/root/client.crt`,
`/root/client.key`) blieben vollständig erhalten.

## Sicherung und Rücknahme

Vor dem Upgrade lagen ein vom Betreiber erstelltes Proxmox-Backup sowie eine
zusätzliche Dateisicherung auf `proxmox` vor:

- `/root/.local/jaylab/zb2mqtt-upgrade-20261127T191320Z/zb2mqtt-before.tar.gz`
  (Verzeichnis `0700`, Archiv `0600`), enthält `/opt/zigbee2mqtt/data`,
  `/root/ca.crt`, `/root/client.crt`, `/root/client.key` und
  `/etc/systemd/system/zigbee2mqtt.service`.

Rücknahmeweg bei Bedarf: `systemctl stop zigbee2mqtt`, das Proxmox-Backup von
CT 121 zurückspielen oder das gesicherte Archiv zusammen mit dem vorherigen
Containerstand wiederherstellen.

## Durchgeführte Anpassungen

1. `zigbee2mqtt.service` gestoppt, Sicherung erstellt und Datenbestand gesichert.
2. Alte NodeSource-Konfiguration (`node_19.x`) entfernt und `apt-get full-upgrade`
   sowie Build-Werkzeuge (`git`, `curl`, `ca-certificates`, `gnupg`, `make`,
   `g++`, `python3`) auf Debian 12 aktualisiert.
3. Node.js `v24.22.3` installiert und `corepack enable` aktiviert.
4. `/opt/zigbee2mqtt` auf Tag `2.14.3` (Commit `3c841fdf`) gewechselt,
   gesicherten Ordner `data/` zurückgespielt, `pnpm install --frozen-lockfile`
   und `pnpm run build` ausgeführt.
5. In `/etc/systemd/system/zigbee2mqtt.service` `ExecStart=/usr/bin/node index.js`
   gesetzt und `systemctl daemon-reload` ausgeführt.
6. In `/opt/zigbee2mqtt/data/configuration.yaml` unter `serial:` explizit
   `adapter: zstack` ergänzt; Zigbee2MQTT 2.14.3 migrierte beim ersten Start die
   Konfiguration automatisch (Protokolle in
   `/opt/zigbee2mqtt/data/migration-1-to-2.log` bis `migration-4-to-5.log`,
   insbesondere Entfernung der veralteten statischen Option `permit_join`).

## Abnahme

| Prüfung | Ergebnis | Status |
|---|---|---|
| Debian 12 (`apt list --upgradable`) | 0 ausstehende Paketupdates | Bestanden |
| Node.js / Zigbee2MQTT | Node `v24.22.3`, Zigbee2MQTT `2.14.3`, `zigbee-herdsman 11.2.0` | Bestanden |
| `zigbee2mqtt.service` & Coordinator | `active`, `ZStack3x0` Revision `20210708` geöffnet, 12 Geräte geladen | Bestanden |
| MQTT-TLS | Verbunden mit `mqtts://mqtt.jaylab.local:8883` (`bridge/state` `online`) | Bestanden |
| Lokales Frontend (`http://127.0.0.1:8080/`) | HTTP 200 | Bestanden |
| HTTPS & WSS (`zb2mqtt.jaylab.org`) | HTTPS 200, `wss://zb2mqtt.jaylab.org/api` `Open` (53 Byte empfangen) | Bestanden |
| Automatisierung (`Test-JaylabAutomation.ps1 -Service zigbee`) | `version: 2.14.3`, HTTP 200, WebSocket `true`, MQTT-TLS `true`, 12 Geräte | Bestanden |
