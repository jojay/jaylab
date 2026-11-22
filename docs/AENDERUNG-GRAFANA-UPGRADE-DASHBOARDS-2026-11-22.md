# Änderung: Grafana-CT-Upgrade (Ubuntu 24.04.5 LTS / Grafana 13.3.1) sowie Überarbeitung der Dashboards „Aqara Batterie Status“, „BSHC-Aqara-Dashboard“ und „BSHC-Dashboard“

## Ergebnis und Umfang

Am 22. November 2026 wurden auf `proxmox`, CT 102 (`grafana`, `192.168.40.248`),
nach einem anwendungskonsistenten PBS-Vollbackup und gesonderter Dateisicherung
alle ausstehenden Betriebssystempakete innerhalb von Ubuntu `24.04 LTS` sowie
`grafana-enterprise` von `12.4.2` auf **`13.3.1`** aktualisiert. Bestehende
TLS-Zertifikate (`/etc/grafana/grafana-backend-2026.pem`), `grafana.ini`
(Unterpfad `/grafana/`, Authentik-OIDC `Jaylab SSO (LAN)`), Datenquellen,
Benutzer und Dashboards blieben unverändert erhalten.

Anschließend wurden über die Grafana-HTTP-API (unter Erweiterung von
[Set-JaylabCredential.ps1](../scripts/Set-JaylabCredential.ps1) um den
Dienstbezeichner `grafana`) das Library Panel `Tür und Fenster Status`
(`wbQMs6J4k`, v1 → v2) sowie die Dashboards `Aqara Batterie Status`
(`unEDfmJVk`, v4 → v5), `BSHC-Aqara-Dashboard` (`_ts0ZCT4k`, v38 → v39) und
`BSHC-Dashboard` (`mttazdTnz`, v14 → v15) überarbeitet:

- Alle betroffenen Flux-Abfragen im Bucket `shcbucket` wurden von den nicht
  vorhandenen Tags `room` und `topic` auf eindeutige `deviceId`-Filterung
  umgestellt, wodurch `Ventilstellung`, die SHC-Reihen in Temperatur und
  Luftfeuchtigkeit, alle 12 Gauges und das untere Verlaufs-Panel (ID 17) wieder
  vollständige Daten einschließlich der vorhandenen 30-Tage-Historie liefern.
- Alle Zeitreihen-Panels über sämtliche drei Dashboards verwenden dieselbe
  `deviceId`-Zuordnung auf kanonische Gerätenamen (keine rohen
  `hdm:HomeMaticIP:...`-Kennungen oder `deviceId`-Labels mehr), feste
  Hex-Farbcodes, zusammenhängende Flux-Abfragen sowie eine tabellarische
  Legende unterhalb der Graphen in unveränderlicher alphabetisch aufsteigender
  Reihenfolge.

| Komponente | Vorher | Nachher | Beleg / Ort |
| --- | --- | --- | --- |
| Betriebssystem CT 102 | Ubuntu `24.04.4 LTS` | Ubuntu `24.04.5 LTS` | `50` Ubuntu-Pakete aktualisiert, `0` ausstehend |
| Grafana-Paket CT 102 | `grafana-enterprise 12.4.2` | `grafana-enterprise 13.3.1` | Repo `https://apt.grafana.com`, GPG-Signatur geprüft |
| APT-Quelle Grafana | `packages.grafana.com` + `/etc/apt/trusted.gpg` | `apt.grafana.com` + `/etc/apt/keyrings/grafana.gpg` | `jammy-icinga.list` und altes `trusted.gpg` entfernt |
| Library Panel `wbQMs6J4k` | v1 (`room`/`topic`-Overrides, `sortBy Time`) | v2 (`deviceId`-Mapping, A–Z-Sortierung) | Grafana Unified Storage / API |
| `Aqara Batterie Status` (`unEDfmJVk`) | v4 (`palette-classic`, unsortiert) | v5 (feste Hex-Farben, Tabellenlegende A–Z; später auf v6 bestätigt) | Grafana Unified Storage / API |
| `BSHC-Aqara-Dashboard` (`_ts0ZCT4k`) | v38 (`No data` in Ventil/Gauges/Panel 17) | v39 (alle Panels aktiv, einheitliche Namen/Farben A–Z) | Grafana Unified Storage / API |
| `BSHC-Dashboard` (`mttazdTnz`) | v14 (rohe `deviceId`-Labels, `List`-Legenden, `Panel Title`, fehlende Farb-/Einheitsangaben) | v15 (kanonische Namen, feste Hex-Farben, A–Z-Tabellenlegenden, saubere Gauges & Panel 17) | Grafana Unified Storage / API |

## Istzustand und Abhängigkeiten

- **Container-Pfad:** `proxmox` → `vmbr0` → `net0` (`eth0`, MAC
  `92:2E:0B:AC:A6:07`, `192.168.40.248/24` sowie globale und ULA-IPv6-Adressen;
  `onboot: 1`, `startup: order=20,up=10`, RootFS `local-lvm:vm-102-disk-0`, `8 GiB`,
  nach Upgrade `68 %` belegt / `2,5 GiB` frei).
- **Proxy- und SSO-Pfad:** Caddy CT 131 (`/etc/caddy/sites/grafana.caddy`)
  terminiert `https://grafana.jaylab.org` und verbindet zum Backend
  `grafana.jaylab.local:3443` mit `/etc/caddy/grafana-backend-ca.pem`;
  Authentik-OIDC (`https://login.jaylab.org/application/o/authorize/`) und
  lokaler `admin`-Notzugang bleiben unverändert.
- **Ursache der fehlenden SHC-Daten:** Die lesende Prüfung von Node-RED CT 105
  ([flows.json](../docs/AUTOMATISIERUNG-ZUGAENGE.md) / `shc-device.js`) sowie
  `schema.tagKeys(bucket: "shcbucket", start: -365d)` belegten, daß Node-RED
  `room` und `topic` auf Nachrichtenebene setzt, die `join`-Nodes jedoch nur
  `msg.payload` bündeln (die alten `change`-Nodes sind deaktiviert). In
  `shcbucket` existieren deshalb ausschließlich die Tag-Schlüssel
  `_measurement`, `_field` und `deviceId`. Node-RED CT 105 blieb auf
  Betreiberentscheidung unverändert; alle Abfragen filtern robust über
  `deviceId`.
- **Unified Storage:** Grafana `12.4.2`/`13.3.1` verwaltet geänderte Dashboards
  in `resource` / `resource_version` statt in der veralteten Tabelle
  `dashboard`; alle Anpassungen wurden deshalb ausschließlich über die offizielle
  Grafana-HTTP-API gespeichert. Das frühere `rc`-Paket `grafana 9.3.2` blieb
  bewußt ungepurgt, um bestehende Dateien nicht zu gefährden.

## Konkrete Änderung

### 1. APT-Quellen und System-/Grafana-Upgrade (CT 102)

1. Offiziellen Schlüssel von `https://apt.grafana.com/gpg.key` nach
   `/etc/apt/keyrings/grafana.gpg` geladen und Fingerabdruck auf exakt
   `B53AE77BADB630A683046005963FA27710458545` geprüft (`Grafana Labs
   <engineering@grafana.com>`, gültig bis 22.08.2027).
2. `/etc/apt/sources.list.d/grafana.list` auf
   `deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main`
   umgestellt; veraltete Dateien `/etc/apt/sources.list.d/jammy-icinga.list` und
   `/etc/apt/trusted.gpg` entfernt.
3. Bei gestopptem `grafana-server` mittels `DEBIAN_FRONTEND=noninteractive
   apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade`
   alle `51` Pakete aktualisiert (`grafana-enterprise 12.4.2 → 13.3.1`,
   `systemd 255.4-1ubuntu8.18 → .19`, `base-files`, `libsqlite3-0` u. a.).
   `grafana.ini` behielt unverändert den SHA-256-Wert
   `fc5866d913314da2aabd392e741bcb5d6049dbc4a5cf98ab89ed7af8f9dd2228`.
4. Container über `pct reboot 102` neu gestartet; `24` SQLite-Migrationen liefen
   beim ersten Start von Grafana `13.3.1` in `72 ms` fehlerfrei durch.

### 2. Kanonische Gerätezuordnung und feste Farbcodes

In allen betroffenen Panels der Dashboards `Aqara Batterie Status`,
`BSHC-Aqara-Dashboard` und `BSHC-Dashboard` (Bestandsumfang der sechs
E2/E3-SHC-Geräte gemäß Betreiberfestlegung) gilt dieselbe `deviceId`-Zuordnung:

| Bereich | `deviceId` | Kanonischer Name | Fixer Farbcode |
| --- | --- | --- | --- |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091adbe3` | `Badezimmer (Aqara)` | `#C0D8FF` |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091c96be` | `Küche (Aqara)` | `#9FDD12` |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091adb08` | `Schlafzimmer Eltern` | `#CA95E5` |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091a463f` | `Schlafzimmer Samuel` | `#EAB839` |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091a459e` | `Schlafzimmer Vincent` | `#37872D` |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091a4176` | `Tiefkeller` | `#0BD7CD` |
| Bosch SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005D585C78C6` | `Arbeitszimmer` | `#73BF69` |
| Bosch SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005D58597571` | `Badezimmer (SHC)` | `#F2495C` |
| Bosch SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005BB85F9F08` | `Esseck` | `#B877D9` |
| Bosch SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000289BB85F32B0` | `Raumthermostat` | `#3274D9` |
| Bosch SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005D585C79B6` | `Umkleidezimmer OG` | `#FADE2A` |
| Bosch SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005BB85F9E0D` | `Wohnzimmer` | `#5794F2` |

Für die sechs Tür-/Fensterkontakte (`ShutterContact`) im Library Panel
`wbQMs6J4k` werden über `deviceId` die Namen `Fenster Arbeitszimmer`,
`Fenster Bad`, `Fenster EG Schlafzimmer`, `Fenster Esszimmer`, `Garagentor` und
`Tür Hauseingang` vergeben.

### 3. Dashboard-Aufbau und deterministische Legenden

- **Einheitliche Tabellenlegenden:** Alle Zeitreihen-Panels (`Batteriespannung`,
  `Batterie in %`, `Ventilstellung`, `Temperatur-DG-OG-UG`, `HT-OG-DG`,
  `Luftfeuchtigkeit`, `Luftfeuchtigkeit Wohnzimmer`) nutzen
  `legend.displayMode = "table"` und `legend.placement = "bottom"` ohne
  dynamische Wert-Sortierung (`sortBy`). Gemischte Graphen führen `shcbucket`
  und `zigbee2mqtt` über `union()` in einer Flux-Abfrage zusammen und ordnen
  alle Serien über `|> group() |> sort(columns: ["_field", "_time"]) |>
  group(columns: ["_field"])` streng alphabetisch A–Z, ohne künstliche
  `null`-Lücken zwischen unterschiedlichen Sendeintervallen zu erzeugen.
- **Bereinigte Details in `BSHC-Aqara-Dashboard`:** Tippfehler in Titel
  (`Luftrdruck` → `Luftdruck (aktuell)`) und Override (`Tiekeller` →
  `Tiefkeller`) sowie doppelte Overrides entfernt; kaputten `reduceOptions.fields`-Regex
  bei Gauge ID 15 (`Luftfeuchtigkeit Wohnzimmer `) geleert; fehlendes
  `color.mode: "thresholds"` bei Gauges ID 11–14 und fehlende `unit: "celsius"`
  bei Gauge ID 13 ergänzt; Panel 17 (`SHC Verlauf (Temperatur, Ventilstellung,
  Luftfeuchtigkeit)`) auf die sechs SHC-`deviceId`s mit eindeutigen Zeilennamen
  `<Gerät> – <Meßgröße>` umgestellt.
- **Nachtrag `BSHC-Dashboard` (`mttazdTnz`, v14 → v15):** Sämtliche 16 Panels
  analog zu `BSHC-Aqara-Dashboard` überarbeitet (`apply-bshc-dashboard.ps1`):
  - **Panel 19 (`Ventilstellung`)**: Von rohem `position{deviceId="..."}` auf
    kanonische Namen A–Z (`Arbeitszimmer`, `Badezimmer (SHC)`, `Esseck`,
    `Umkleidezimmer OG`, `Wohnzimmer`), feste Hex-Farben, Einheit `percent` und
    Tabellenlegende (`lastNotNull`, `min`, `max`) umgestellt.
  - **Panel 2 (`HT-OG-DG`)**: Titel beibehalten, alle sechs SHC-Geräte A–Z auf
    kanonische Namen gemappt, feste Hex-Farben und vollständige Tabellenlegende
    (`lastNotNull`, `min`, `max`) gesetzt.
  - **Panel 21 (`Luftfeuchtigkeit Wohnzimmer`)**: Titel beibehalten,
    `Raumthermostat` gemappt, festen Farbcode `#3274D9`, Einheit `humidity` und
    Tabellenlegende (`lastNotNull`, `min`, `max`) ergänzt.
  - **12 Gauge-Panels (IDs 9, 10, 11, 14, 12, 13, 4, 6, 5, 15, 7, 8)**: Auf
    saubere Einzelwertabfrage (`last()`, `_field: " "` ohne `deviceId`-Label)
    sowie `color.mode: "thresholds"` (IDs 11–14) und `unit: "celsius"` (ID 13)
    umgestellt, so daß keine rohen `deviceId`-Labels mehr erscheinen.
  - **Panel 17 (`state-timeline`)**: Von `Panel Title` auf
    `SHC Verlauf (Temperatur, Ventilstellung, Luftfeuchtigkeit)` umbenannt und
    analog `_ts0ZCT4k` auf die 12 A–Z-Reihen `<Gerät> – <Meßgröße>` ohne rohe
    `deviceId`-Labels umgestellt.
  - `BSHC-Dashboard-DEV` (`YjZPR_A7k`) blieb vereinbarungsgemäß unverändert.
- **Lokale Werkzeuge:** [Set-JaylabCredential.ps1](../scripts/Set-JaylabCredential.ps1)
  um `'grafana'` erweitert; Vorher-/Nachher-JSONs und Hilfsskripte unter
  `.local/changes/2026-11-22-grafana/` abgelegt (von Git ausgeschlossen).

## Sicherung und Rücknahme

- **Unabhängiger Zugang:** Host `jaylab-proxmox` über WSL-SSH
  (`pct exec 102`, `pct restore 102`).
- **PBS-Sicherungen auf `proxmox-backupserver` (Namespace `containerbackup`):**
  1. **Vorab-Sicherung (bei gestopptem `grafana-server`):**
     `proxmox-backupserver:backup/ct/102/2026-11-22T14:42:16Z` (`3668669563` Byte)
  2. **Zwischensicherung nach OS-/Grafana-Upgrade (`13.3.1`):**
     `proxmox-backupserver:backup/ct/102/2026-11-22T14:45:18Z` (`5392887197` Byte)
  3. **Zwischensicherung nach erstem Dashboard-Lauf:**
     `proxmox-backupserver:backup/ct/102/2026-11-22T14:55:24Z` (`5393011966` Byte)
  4. **Schluß-Sicherung nach `BSHC-Dashboard`-Nachtrag (`mttazdTnz` v15):**
     `proxmox-backupserver:backup/ct/102/2026-11-22T17:33:20Z` (`5393313560` Byte)
- **Dateisicherung außerhalb CT 102 auf `proxmox` sowie lokal:**
  `/root/.local/jaylab/grafana-upgrade-20261122/` (`0700`, Dateien `0600`):
  `grafana.db` (SHA-256 `7ba5ac9add8af33e2a5b185768fb6a28ed74e59d9649e8ad80e21c0819b72581`),
  `grafana.ini` (`fc5866d913314da2aabd392e741bcb5d6049dbc4a5cf98ab89ed7af8f9dd2228`),
  `grafana-backend-2026.pem` (`a8b8d14fa6a20cacf7aa097a99958d01974d8094805855340643179ab5ab4583`),
  `/etc/apt/*`-Sicherungen und Original-JSONs (`unEDfmJVk.json`, `_ts0ZCT4k.json`,
  `wbQMs6J4k.json`), sowie lokale API-Vorabstände unter
  `.local/changes/2026-11-22-grafana/before-api/` (einschließlich `mttazdTnz.json`).
- **Vollständige Rücknahme auf Vor-Upgrade-Stand (auf `jaylab-proxmox`):**
  ```bash
  pct stop 102
  pct restore 102 proxmox-backupserver:backup/ct/102/2026-11-22T14:42:16Z --storage local-lvm --force 1
  pct start 102
  ```
- **Feingranulare Dashboard-Rücknahme:** Über die Grafana-Versionshistorie
  (`unEDfmJVk` v4, `_ts0ZCT4k` v38, `mttazdTnz` v14) bzw. durch erneutes
  Einspielen der unter `.local/changes/2026-11-22-grafana/before-api/`
  gesicherten Stände über die Grafana-HTTP-API.

## Abnahme

| Quelle / Zone | Ziel / Dienst / IP-Version | Erwartet | Gemessen / Beleg |
| --- | --- | --- | --- |
| `proxmox` (`pct exec`) | CT 102 OS, Pakete, `grafana-server`, SQLite | Ubuntu `24.04.5 LTS`, `grafana-enterprise 13.3.1`, `0` Updates, `PRAGMA integrity_check: ok` | Bestanden (`24` Migrationen in `72 ms`, `grafana.ini` SHA-256 unverändert) |
| CT 131 Caddy → CT 102 | `https://grafana.jaylab.local:3443/grafana/api/health` mit `/etc/caddy/grafana-backend-ca.pem` | HTTP `200`, `database: "ok"`, `version: "13.3.1"` | Bestanden |
| Windows → Caddy | `https://grafana.jaylab.org/grafana/api/health` | HTTP `200`, `database: "ok"`, `version: "13.3.1"` | Bestanden |
| Windows → Caddy (Negativtest) | `https://grafana.jaylab.org/grafana/api/search` (anonym) | HTTP `401` | Bestanden (`HTTP_STATUS=401`) |
| Windows → Caddy | `https://grafana.jaylab.org/grafana/login/generic_oauth` | HTTP `302` auf `login.jaylab.org` mit PKCE (`S256`) | Bestanden |
| Windows API (3×) + Negativprüfung | `POST /grafana/api/ds/query` auf alle Panels von `unEDfmJVk`, `wbQMs6J4k`, `_ts0ZCT4k`, `mttazdTnz` | Kein `No data`, identische Hex-Farben/Namen/Legenden/Gauges über alle drei Dashboards, keine `hdm:HomeMaticIP:`-/`deviceId`-Felder oder -Labels in `mttazdTnz`, identische A–Z-Folge über 3 Läufe | Bestanden (`wbQMs6J4k` v2, `unEDfmJVk` v6, `_ts0ZCT4k` v39, `mttazdTnz` v15; `mttazdTnz`: `5` Ventil-, `6` HT-OG-DG-, `1` Luftfeuchtigkeit-, `12` Gauge- und `12` Verlaufsserien ohne Roh-IDs; `ALL 3 RUNS IDENTICAL & NON-EMPTY (ZERO RAW DEVICE IDs IN BSHC): PASS`) |
| Chrome-Browser (anonym) | `https://grafana.jaylab.org/grafana/d/unEDfmJVk/aqara-batterie-status` | Keine ungeschützte Dashboard-Anzeige; `13.3.1`-Maske & `Jaylab SSO (LAN)` | Bestanden (`Grafana v13.3.1 (da3aa3ff57)` unter `/grafana/login` geladen) |
| Windows Workspace | `pwsh -NoProfile -File scripts/tests/Test-CredentialStore.ps1`, `scripts/Test-Workspace.ps1` | `0` Fehler | Bestanden |

## Abschluß

- **Aktivierungsstand:** Produktiv aktiv auf CT 102 (`Ubuntu 24.04.5 LTS`,
  `Grafana Enterprise 13.3.1`, `wbQMs6J4k` v2, `unEDfmJVk` v6, `_ts0ZCT4k` v39,
  `mttazdTnz` v15). Alle vier PBS-Sicherungen liegen auf
  `proxmox-backupserver`, die Dateisicherung auf `proxmox` unter
  `/root/.local/jaylab/grafana-upgrade-20261122/` bzw. lokal unter
  `.local/changes/2026-11-22-grafana/`.
- **Offene Betreiber-Sichtprüfung / Restbefunde:**
  1. Eine angemeldete Browser-Sichtprüfung der gerenderten Graphen, Legenden und
     Farbcodes inkl. Neuladen (`F5`) für `Aqara Batterie Status`,
     `BSHC-Aqara-Dashboard` und `BSHC-Dashboard` konnte nicht automatisiert
     durchlaufen werden, da das Browserprofil nicht bei Grafana angemeldet war
     (sie wurde für sämtliche Datenabfragen und die Negativprüfung auf rohe
     `deviceId`s stattdessen 3× gegen `/grafana/api/ds/query` bestätigt). Bitte
     die visuelle Darstellung und ein zweimaliges Neuladen in Ihrer angemeldeten
     Sitzung kurz gegenprüfen.
  2. Das alte, ungenutzte Plugin `flant-statusmap-panel` (`0.4.2`) wird beim
     Start von Grafana `13.3.1` wegen deaktivierter AngularJS-Unterstützung
     abgewiesen (`angular plugins are not supported`); keines der vorhandenen
     Dashboards verwendet dieses Plugin.
  3. Im Zeitfenster `now-24h` meldete der Aqara-Sensor `Tiefkeller` zuletzt am
     15. November 2026 (`11:10:23Z`); er erscheint daher standardmäßig im
     14-Tage-Dashboard `Aqara Batterie Status`, im `BSHC-Aqara-Dashboard` jedoch
     erst bei erweitertem Zeitfenster oder erneutem Funkempfang.
  4. Das Entwicklungs-Dashboard `BSHC-Dashboard-DEV` (`YjZPR_A7k`) wurde
     vereinbarungsgemäß nicht verändert.
