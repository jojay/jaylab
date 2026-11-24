# Jaylab Haus-Zentrale Umsetzungsplan

> **Für ausführende Agenten:** ERFORDERLICHER SUB-SKILL: Verwende `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans` zur schrittweisen Umsetzung dieses Plans. Schritte verwenden Checkbox-Syntax (`- [ ]`).

**Ziel:** Erweiterung der Node-RED-Datenerfassung auf CT 105 um sechs neue Measurements (`powerMeter`, `applianceState`, `roomClimate`, `securityStatus`, `deviceHealth`, `contactStatus`) sowie zwei fehlende Heizkörperthermostate und Bereitstellung des neuen zentralen Grafana-Dashboards „Jaylab Haus-Zentrale“ (`jaylab-haus-zentrale`) auf CT 102 ohne Veränderung der fünf bestehenden Dashboards.

**Architektur:** Eine einzige kanonische Geräte- und Farbquelle (`scripts/haus-zentrale/devices.json`) speist sowohl die eigenständig testbare Node-RED-Verarbeitungslogik (`nodered_logic.js`) und den deterministischen Flow-Patcher (`build_nodered_flows.js`) als auch den Grafana-Dashboard-Generator (`build_grafana_dashboard.ps1`). Sämtliche Logik, Sicherheitsinvarianten und Dashboard-Strukturen werden vorab lokal mit `node --test` und PowerShell-Tests verifiziert, bevor gesicherte, wiederholbare Rollout- und Rücknahmeskripte unter `.local/changes/2026-11-24-haus-zentrale/` auf CT 105 und CT 102 aktivieren.

**Tech-Stack:** Node.js (`v26.13.0` lokal auf Windows für `node --test`, `v24.22.3` / Node-RED `5.0.10` / `node-red-contrib-bosch-shc 0.8.39` auf CT 105), PowerShell 7 (`pwsh`), Grafana Enterprise `13.3.1` HTTP-API (CT 102), InfluxDB Cloud v2 / Flux (`uid: f7QzURA7k`, Buckets `shcbucket` und `zigbee2mqtt`).

**Entwurf (Spec):** [2026-11-24-haus-zentrale-dashboard-design.md](../specs/2026-11-24-haus-zentrale-dashboard-design.md) · **Bezug:** [Betrieb](../../BETRIEB.md), [Änderungsvorlage](../../vorlagen/AENDERUNG.md), [Grafana-Upgrade & Dashboards](../../AENDERUNG-GRAFANA-UPGRADE-DASHBOARDS-2026-11-22.md), [Node-RED-Upgrade](../../AENDERUNG-NODERED-UPGRADE-2026-11-22.md), [Automatisierungszugänge](../../AUTOMATISIERUNG-ZUGAENGE.md).

---

## Globale Randbedingungen

- **Zielsystem CT 105 (Node-RED):** `proxmox`, `192.168.40.223`, Dienst `nodered.service`, Projektdatei `/home/jay/.node-red/projects/nodered-managed/flows.json`, `contextStorage: null` (Standard-RAM-Kontext; `settings.js` bleibt unverändert); bei `pct exec 105` stets `/usr/local/bin/node` aufrufen.
- **Zielsystem CT 102 (Grafana):** `proxmox`, `192.168.40.248`, `Grafana Enterprise 13.3.1`, API über `https://grafana.jaylab.org/grafana/api/...` mit `.local/access/credentials/grafana.clixml`; Änderungen ausschließlich über die offizielle HTTP-API (Unified Storage).
- **InfluxDB- und SHC-Anbindung:** Bestehender Node-RED-InfluxDB-Node `2be7c8fd.d795c8`, bestehender SHC-Config-Node `361e3c3baf324236`, Grafana-Datenquelle `InfluxDB` (`uid: f7QzURA7k`), Buckets `shcbucket` und `zigbee2mqtt`; keine Migration auf `InfluxDB-DEV` (`4XosR_0nz`).
- **Geheimnisschutz:** Keine Kennwörter, Tokens, privaten Schlüssel oder Konto-E-Mail-Adressen in Repository-Dateien, Skripten oder Protokollen; der `org`-Wert für neue `influxdb batch`-Nodes wird zur Laufzeit von `patchFlows` aus einem vorhandenen `influxdb batch`-Node der originalen `flows.json` (z. B. `15280adaaa202494`) kopiert.
- **`shc-device`-Schreibschutz:** Jeder lesende Poll-`inject`-Node **muß** `payloadType: "str"` mit `payload: ""` senden (niemals `boolean` und niemals `number`/`date`), um unbeabsichtigte `putState`-Schreibbefehle (wie das Zurücksetzen von `PowerMeter.energyConsumption` auf `0`) sicher auszuschließen.
- **Bestandsschutz Alt-Dashboards:** Alle fünf bestehenden Dashboards (`_ts0ZCT4k`, `mttazdTnz`, `unEDfmJVk`, `kgz9x6J4z`, `YjZPR_A7k`) sowie Library Panel `wbQMs6J4k` bleiben zu 100 % unverändert; der bestehende Tab `Fensterkontakt` (`a141daf87ef3ad4d`, Measurement `ShutterContact`) bleibt streng auf den bisherigen 6 Kontakten (nur das Duplikat `Tür Hauseingang` `f82cb486c4c879d5` wird entfernt).
- **Kanonische Namen, Farben & Gestaltung:** `hdm:HomeMaticIP:3014F711A00004953859DEF1` heißt durchgängig **`Springer`** (niemals `Ela-Wandheizung` in Anzeigen); die 12 Bestandsfarben bleiben unverändert; alle Zeitreihen nutzen `legend.displayMode = "table"`, `placement = "bottom"`, ohne `sortBy`, streng A–Z; alle Texte in Rechtschreibung von vor 1996, niemals gendern.
- **Betrieb, Sicherung & Rückweg ([BETRIEB.md](../../BETRIEB.md)):** Vor jeder Live-Änderung PBS-Snapshot bzw. Dateisicherung außerhalb der Container unter `/root/.local/jaylab/haus-zentrale-20261124/` (`0700`/`0600`) anlegen, vorbereiteten Rückweg ablegen und `pwsh -NoProfile -File scripts/Test-Workspace.ps1` bestehen.

---

## Prüfschwerpunkte (Review Focus)

1. **Unbeabsichtigter SHC-Schreibbefehl (`putState`) durch falschen Poll-Payload:** Alle neuen sowie alle angefaßten Poll-`inject`-Nodes (`f3d793a5792cb934`, `c68eed6494d4878b`, `fa1db6e376b7e8e7`) müssen strikt `payloadType: "str"` und `payload: ""` setzen (abgesichert in Task 3: `all poll injects send empty string`).
2. **Null-Werte und Teilausfall bei `Springer` (`PowerMeter: null`, `status: UNDEFINED`):** Die Verarbeitung darf weder `NaN`/`null` nach InfluxDB schreiben noch den Batch abbrechen; `switchOn` wird trotzdem erfaßt und `deviceName` lautet `Springer` (abgesichert in Task 2: `buildPowerMeterPoints handles null PowerMeter for Springer`).
3. **Flatternde Waschmaschine, negativer Zähler-Reset und Ausschalt-Quittung im Zustandsautomat:** Eine kurze Pause (`< 4 W` für `120 s < 300 s`) darf `Läuft` nicht beenden; ein Zählerstand `< cycleStartWh` klemmt `cycleEnergyWh` auf `>= 0`; `switchOn == 0` setzt `Fertig` sofort auf `Aus` (`0`), und nach `240` Min. ohne Neustart erfolgt der Rückfall auf `Bereit` (`1`) (abgesichert in Task 2).
4. **Regression der Alt-Dashboards über `ShutterContact` (`wbQMs6J4k`):** Der Tab `Fensterkontakt` darf nach dem Patch exakt die 6 Alt-Kontakte ohne doppeltes `Tür Hauseingang`-Node enthalten, während alle 9 Kontakte im neuen Measurement `contactStatus` landen (abgesichert in Task 3 und Task 6).
5. **Gemischte Typen, `> 24 h`-Funkstille (`Tiefkeller`) und nicht erreichbare Kontakte (`Tür Hauseingang`, `Garagentor`):** Die Raum-Matrix nutzt spaltenweise Targets + Grafana-Transformation `joinByField` auf `Raum` (kein typgemischtes Flux-`union`), bevorzugt `Raumthermostat` in `E2 Wohn-/Eßzimmer`, blendet `> 24 h` stumme Aqara-Räume in der Live-Matrix aus (`–`) und markiert nicht erreichbare Kontakte in `contactStatus` explizit als `state = "UNAVAILABLE"`, `isOpen = 0`, `available = 0` (abgesichert in Task 2 und Task 4).

---

## Dateistruktur

| Pfad | Ablage | Verantwortung |
| --- | --- | --- |
| `scripts/haus-zentrale/devices.json` | Git | Kanonische Geräte-, Raum-, Farb-, Schwellen- und Matrixdefinition für Node-RED und Grafana |
| `scripts/haus-zentrale/tests/devices.test.js` | Git | Schema- und Vollständigkeitsprüfung für `devices.json` |
| `scripts/haus-zentrale/nodered_logic.js` | Git | Reine Node-RED-Extraktions-, Gesundheits- und Zustandsautomaten-Logik (ohne I/O) |
| `scripts/haus-zentrale/tests/nodered_logic.test.js` | Git | Unit-Tests aller Measurements, Zustandsübergänge und Fehlerfälle |
| `scripts/haus-zentrale/build_nodered_flows.js` | Git | Deterministischer, idempotenter Flow-Patcher und Sicherheitsvalidator für `flows.json` |
| `scripts/haus-zentrale/tests/build_nodered_flows.test.js` | Git | Tests auf Minimal-Fixture: Schreibschutz (`payload: ""`), `ShutterContact`-Trennung, Idempotenz, VM-Probe der `func`-Strings |
| `scripts/haus-zentrale/build_grafana_dashboard.ps1` | Git | Deterministischer Generator des Grafana-API-Payloads (`jaylab-haus-zentrale`) |
| `scripts/haus-zentrale/tests/Test-HausZentraleDashboard.ps1` | Git | Strukturelle und inhaltliche Prüfung des generierten Dashboard-JSON |
| `.local/changes/2026-11-24-haus-zentrale/Deploy-NodeRedFlows.ps1` | Lokal | Gesichertes CT-105-Rollout (PBS-Snapshot, Off-Container-Sicherung, `flows.json`-Wechsel, Live-Check) |
| `.local/changes/2026-11-24-haus-zentrale/Rollback-NodeRedFlows.ps1` | Lokal | Sofortige Wiederherstellung von `flows.json` aus der Off-Container-Sicherung |
| `.local/changes/2026-11-24-haus-zentrale/Deploy-GrafanaDashboard.ps1` | Lokal | Vorab-API-Export aller 5 Alt-Dashboards + `wbQMs6J4k` und Einspielen von `jaylab-haus-zentrale` |
| `.local/changes/2026-11-24-haus-zentrale/Verify-HausZentrale.ps1` | Lokal | 3× deterministische `/api/ds/query`-Abnahme + Nachweis unveränderter Alt-Dashboards |
| `docs/AENDERUNG-HAUS-ZENTRALE-2026-11-24.md` | Git | Änderungs- und Abnahmeprotokoll gemäß `docs/vorlagen/AENDERUNG.md` |

---

### Task 1: Zentrale Geräte- und Farbdefinition (`devices.json`)

**Dateien:**
- Erstellen: `scripts/haus-zentrale/devices.json`
- Test: `scripts/haus-zentrale/tests/devices.test.js`

**Schnittstellen:**
- Produziert: `scripts/haus-zentrale/devices.json` mit den Top-Level-Schlüsseln:
  - `climateSensors`: Array mit 17 Objekten (`deviceId`, `bucket`, `canonicalName`, `shcName`, `room`, `model`, `color`, `hasValve`, `hasHumidity`)
  - `roomClimateControls`: Array mit 9 Objekten (`deviceId`, `shcRoom`, `matrixRoom`)
  - `contacts`: Array mit 9 Objekten (`deviceId`, `shcName`, `canonicalName`, `shcRoom`, `matrixRoom`, `legacyShutterContact`)
  - `smartPlugs`: Array mit 4 Objekten (`deviceId`, `shcName`, `canonicalName`, `room`, `model`, `color`, `applianceConfig`)
  - `systemDevices`: Objekt mit `intrusionDetectionSystem`, `presenceSimulationService`, `camera3yes`
  - `physicalShcModels`: `["TRV", "THB", "SWD", "PSM", "PLUG_COMPACT", "CAMERA_EYES"]`
  - `matrixRooms`: Array mit 11 Objekten in fester Stockwerksreihenfolge (`sortOrder` `1..11`, `matrixRoom`, `primaryTempId`, `fallbackTempIds`, `rccId`, `valveIds`, `humidityId`, `contactId`)

- [ ] **Schritt 1: Fehlschlagenden Schema- und Vollständigkeitstest schreiben**

Lege `scripts/haus-zentrale/tests/devices.test.js` mit `node:test` und `node:assert/strict` an und prüfe alle exakten Vorgaben aus Spec Abschnitt 5 und 7:
- `climateSensors.length === 17` (11 `shcbucket`, 6 `zigbee2mqtt`), exakt 10 Einträge mit `hasValve === true`, exakt 7 mit `hasHumidity === true`.
- Alle 17 `color`-Werte sind gültige, paarweise verschiedene Hex-Farben (`^#[0-9A-F]{6}$`); die 12 Bestandsfarben aus Spec Abschnitt 5.1 stimmen exakt überein.
- `roomClimateControls.length === 9`, `contacts.length === 9` (davon exakt `6` mit `legacyShutterContact === true` und exakt `3` mit `false`), `smartPlugs.length === 4`.
- Für `hdm:HomeMaticIP:3014F711A00004953859DEF1` gilt `canonicalName === "Springer"` (nirgends `Ela-Wandheizung` als `canonicalName`); `Waschmaschine` trägt `applianceConfig` (`10 / 60 / 4 / 300 / 240`), `Creality` (`15 / 60 / 8 / 300 / 240`).
- `matrixRooms.length === 11` in exakter Reihenfolge (`E3 Badezimmer` … `Keller / Tiefkeller`), und für `E2 Wohn-/Eßzimmer` gilt `primaryTempId === "hdm:HomeMaticIP:3014F711A000289BB85F32B0"` mit `fallbackTempIds` (`Wohnzimmer`, `Esseck`) und `valveIds` (`Wohnzimmer`, `Esseck`).

- [ ] **Schritt 2: Test ausführen und Fehlschlag bestätigen**

Ausführen: `node --test scripts/haus-zentrale/tests/devices.test.js`
Erwartet: FAIL (`ENOENT: no such file or directory ... devices.json`).

- [ ] **Schritt 3: `scripts/haus-zentrale/devices.json` erstellen**

Übertrage sämtliche geprüften IDs, Namen, Modelle, Räume, Farben und Matrix-Verknüpfungen aus Spec Abschnitt 5 und Abschnitt 7 vollständig in `scripts/haus-zentrale/devices.json` (keine Geheimnisse, `legacyShutterContact: true` exakt für `Fenster Arbeitszimmer`, `Fenster Bad`, `Fenster EG Schlafzimmer`, `Fenster Esszimmer`, `Garagentor`, `Tür Hauseingang`).

- [ ] **Schritt 4: Test erneut ausführen und Erfolg nachweisen**

Ausführen: `node --test scripts/haus-zentrale/tests/devices.test.js`
Erwartet: PASS (`0` Fehler).

- [ ] **Schritt 5: Commit**

```powershell
git add scripts/haus-zentrale/devices.json scripts/haus-zentrale/tests/devices.test.js
git commit -m "feat(haus-zentrale): add canonical device and color catalog"
```

---

### Task 2: Node-RED-Verarbeitungslogik und Zustandsautomat (`nodered_logic.js`)

**Dateien:**
- Erstellen: `scripts/haus-zentrale/nodered_logic.js`
- Test: `scripts/haus-zentrale/tests/nodered_logic.test.js`

**Schnittstellen:**
- Konsumiert: `scripts/haus-zentrale/devices.json` (in Tests; zur Laufzeit Parameterübergabe)
- Produziert (CommonJS-Exporte in `scripts/haus-zentrale/nodered_logic.js`, ohne `require()` in den Laufzeitfunktionen selbst, so daß derselbe Quelltext direkt in Node-RED-Function-Nodes eingebettet werden kann):
  - `normalizePayload(payload) -> Array<object>`
  - `buildPowerMeterPoints(events, stateStore, plugsById, nowMs) -> Array<InfluxPoint>`
  - `stepApplianceState(deviceId, sample, ctx, config, nowMs) -> Array<InfluxPoint>` *(sample = `{ power, energyWh, switchOn }`, ctx = flow/node state map, config = `{ startThresholdW, startHoldSec, stopThresholdW, stopHoldSec, doneAutoResetMin, runningLabel }`)*
  - `buildRoomClimatePoints(events, rccById, nowMs) -> Array<InfluxPoint>`
  - `buildSecurityPoints(events, nowMs) -> Array<InfluxPoint>`
  - `buildDeviceHealthPoints(devices, services, physicalModels, nameOverrides, nowMs) -> Array<InfluxPoint>`
  - `buildContactStatusPoints(contactEvents, deviceStatusById, contactsById, nowMs) -> Array<InfluxPoint>`

- [ ] **Schritt 1: Fehlschlagende Unit-Tests für alle 6 Measurements und Review Focus #2, #3, #5 schreiben**

Lege `scripts/haus-zentrale/tests/nodered_logic.test.js` mit folgenden Testfällen an:
- `normalizePayload` akzeptiert sowohl Einzelobjekt (Long-Poll) als auch Array (`device: all`-Poll) und filtert `null`/`undefined`.
- `buildPowerMeterPoints handles null PowerMeter for Springer` (Review Focus #2): führt `PowerSwitch` (`OFF`) und fehlendes `PowerMeter` (`state: null`) zusammen, schreibt `measurement: "powerMeter"`, `tags.deviceName === "Springer"`, `fields.switchOn === 0` ohne `power`/`energyWh`/`NaN`.
- `stepApplianceState` für `Waschmaschine` (`10 / 60 / 4 / 300 / 240`, `runningLabel: "Läuft"`) und `Creality` (`15 / 60 / 8 / 300 / 240`, `runningLabel: "Druckt"`):
  - `0..60 s` mit `>= 10 W` → Wechsel `1 (Bereit)` auf `2 (Läuft)` bei `t >= 60 s`; kurzer Peak `< 60 s` bleibt in `1 (Bereit)`.
  - Review Focus #3a: `120 s` mit `2 W` während `Läuft` (`< 300 s`) setzt Entprelltimer bei erneutem `>= 4 W` zurück und bleibt in `2 (Läuft)`.
  - `>= 300 s` mit `< 4 W` → Wechsel auf `3 (Fertig)` mit `cycleDurationMin`, `finishedAtEpoch`, `cycleEnergyWh >= 0`.
  - Review Focus #3b: Zählerstand `< cycleStartWh` klemmt `cycleEnergyWh` auf `0`.
  - Review Focus #3c: `switchOn === 0` setzt `3 (Fertig)` sofort auf `0 (Aus)`; ohne Ausschalten fällt `3 (Fertig)` nach `240` Min. auf `1 (Bereit)` zurück.
  - Neustart-Wiedererkennung: frischer leerer `ctx` mit `switchOn === 1` und `power >= startThresholdW` erreicht binnen `60 s` den Zustand `2`.
  - Heartbeat nach `300 s` ohne Zustandswechsel emittiert einen aktuellen Punkt.
- `buildRoomClimatePoints` mappt `roomClimateControl_hz_1` → `room: "E2 Wohn-/Eßzimmer"` mit `setpoint`, `hasDemand`, `boostMode`, `ventilationMode`, `summerMode`, `operationMode`.
- `buildSecurityPoints` mappt `SYSTEM_DISARMED`/`SYSTEM_ARMED`/`SYSTEM_ARMING`, `ALARM_OFF`/`ALARM_ON` und `PresenceSimulationConfiguration.enabled`.
- `buildDeviceHealthPoints` filtert aus `38` gemischten SHC-Objekten exakt die `25` physischen Geräte (`physicalShcModels`), benennt `...9DEF1` in `Springer` um, aggregiert `faults.entries` in `faultCount`/`faultSummary` (`"OK"` falls leer) und markiert `UNAVAILABLE`/`UNDEFINED` als `available: 0`.
- `buildContactStatusPoints` (Review Focus #5): bei `status != "AVAILABLE"` (z. B. `Tür Hauseingang` `UNAVAILABLE`, `Garagentor` `UNDEFINED`) liefert selbst ein gecachtes `"OPEN"` oder `"CLOSED"` strikt `state: "UNAVAILABLE"`, `isOpen: 0`, `available: 0`; bei `AVAILABLE` + `"OPEN"` gilt `state: "OPEN"`, `isOpen: 1`, `available: 1`.

- [ ] **Schritt 2: Test ausführen und Fehlschlag bestätigen**

Ausführen: `node --test scripts/haus-zentrale/tests/nodered_logic.test.js`
Erwartet: FAIL (`Cannot find module '../nodered_logic.js'`).

- [ ] **Schritt 3: `scripts/haus-zentrale/nodered_logic.js` implementieren**

Implementiere alle sieben exportierten Funktionen als reines, abhängigkeitsfreies ES2020-JavaScript (ohne `node.warn` und ohne Top-Level-`require`, abschließend bewacht durch `if (typeof module !== 'undefined' && module.exports) { module.exports = { ... }; }`). Alle Zeitberechnungen stützen sich ausschließlich auf das übergebene `nowMs`, und jeder Punkt trägt `timestamp: new Date(nowMs)`.

- [ ] **Schritt 4: Test ausführen und Erfolg nachweisen**

Ausführen: `node --test scripts/haus-zentrale/tests/nodered_logic.test.js`
Erwartet: PASS (`0` Fehler).

- [ ] **Schritt 5: Commit**

```powershell
git add scripts/haus-zentrale/nodered_logic.js scripts/haus-zentrale/tests/nodered_logic.test.js
git commit -m "feat(haus-zentrale): add tested Node-RED extraction and appliance state logic"
```

---

### Task 3: Deterministischer Node-RED-Flow-Patcher (`build_nodered_flows.js`)

**Dateien:**
- Erstellen: `scripts/haus-zentrale/build_nodered_flows.js`
- Test: `scripts/haus-zentrale/tests/build_nodered_flows.test.js`

**Schnittstellen:**
- Konsumiert: `scripts/haus-zentrale/devices.json`, `scripts/haus-zentrale/nodered_logic.js`
- Produziert:
  - `patchFlows(originalFlows, devicesConfig, logicSource) -> Array<NodeRedNode>`
  - `validatePatchedFlows(flows, devicesConfig) -> { ok: boolean, errors: Array<string> }`
  - CLI: `node scripts/haus-zentrale/build_nodered_flows.js <input-flows.json> <output-flows.json>`

- [ ] **Schritt 1: Fehlschlagende Flow-Patcher-Tests schreiben (inkl. Review Focus #1 und #4)**

Lege `scripts/haus-zentrale/tests/build_nodered_flows.test.js` mit einer kompakten synthetischen Fixture der Original-Tabs (`Temperatur` `fbc07e693f44bb3f`, `Ventilstellung` `1d5dba1e404f98a8`, `Fensterkontakt` `a141daf87ef3ad4d`, `Alarm` `63f27dde43843cb0`, Config-Nodes `361e3c3baf324236` & `2be7c8fd.d795c8`, `influxdb batch` `15280adaaa202494` mit `org: "test-org"`) an:
- **Review Focus #1:** `validatePatchedFlows` und explizite Assertion bestätigen, daß **jeder** `inject`-Node in den Tabs `Temperatur`, `Ventilstellung`, `Fensterkontakt` (`f3d793a5792cb934`, `c68eed6494d4878b`, `fa1db6e376b7e8e7`) sowie in allen drei neuen Tabs (`hz_tab_plugs`, `hz_tab_climate`, `hz_tab_sec_health`) strikt `payloadType === "str"` und `payload === ""` setzt (keine `date`/`num`/`bool`-Polls an `shc-device`).
- **Review Focus #4 (`ShutterContact`-Trennung):** Im Tab `Fensterkontakt` (`a141daf87ef3ad4d`) existiert das Duplikat `f82cb486c4c879d5` nicht mehr und steht nicht mehr in `fa1db6e376b7e8e7.wires`; es verbleiben exakt die 6 `legacyShutterContact`-Geräte. Gleichzeitig enthält `hz_tab_sec_health` alle 9 Kontakte für `contactStatus`.
- `Temperatur` besitzt nun 11 `shc-device`-Nodes (ergänzt um `HT-EG-Schlafzimmer` und `HT-Ankleidezimmer`), `join` `04f8f732185167fb` hat `count: "11"` und `timeout: "30"`.
- `Ventilstellung` besitzt nun 10 `shc-device`-Nodes, `join` `fbfc6f9be4eef383` hat `count: "10"` und `timeout: "30"`.
- Alle neuen `influxdb batch`-Nodes erben `influxdb: "2be7c8fd.d795c8"`, `bucket: "shcbucket"` und `org: "test-org"` aus `15280adaaa202494` (kein hartkodierter Wert im Patcher-Quellcode).
- Alle Node-IDs sind eindeutig, alle Verdrahtungsziele existieren, ein zweiter `patchFlows`-Lauf ist idempotent (`deepEqual`), und `new vm.Script(node.func)` kompiliert jeden neu erzeugten Function-Node fehlerfrei und läßt sich mit Mock-`flow`/`msg` ausführen.

- [ ] **Schritt 2: Test ausführen und Fehlschlag bestätigen**

Ausführen: `node --test scripts/haus-zentrale/tests/build_nodered_flows.test.js`
Erwartet: FAIL (`Cannot find module '../build_nodered_flows.js'`).

- [ ] **Schritt 3: `scripts/haus-zentrale/build_nodered_flows.js` implementieren**

Implementiere `patchFlows`, `validatePatchedFlows` und den CLI-Einstiegspunkt:
- Bestehende Tabs `Temperatur`, `Ventilstellung`, `Fensterkontakt` gezielt über die bekannten IDs aus Spec/Ist-Erhebung aktualisieren (nicht neu erfinden; wiederholbarer Idempotenz-Abgleich nach `hz_`-Präfix bzw. Node-ID).
- Drei neue Tabs (`Steckdosen & Geräte`, `Raumklima (Soll)`, `Sicherheit & Gesundheit`) mit stabilen `hz_*`-IDs erzeugen:
  - `Steckdosen & Geräte`: 60-s-Poll (`payload: ""`, `once: true`, `onceDelay: "5"`) + Long-Poll (`poll: true`) für `PowerMeter` und `PowerSwitch` aller 4 Steckdosen → `buildPowerMeterPoints` + `stepApplianceState` → `influxdb batch`.
  - `Raumklima (Soll)`: 300-s-Poll (`payload: ""`, `once: true`, `onceDelay: "8"`) + Long-Poll (`poll: true`) über `shc-device` (`all|all|all|...|`, `service: "RoomClimateControl"`) → `buildRoomClimatePoints` → `influxdb batch`.
  - `Sicherheit & Gesundheit`: (1) 300-s-Poll (`once: true`, `onceDelay: "10"`) + Long-Poll für `IntrusionDetectionControl`, `SurveillanceAlarm`, `PresenceSimulationConfiguration` → `buildSecurityPoints`; (2) 600-s-Poll (`once: true`, `onceDelay: "12"`) für `device: "all"` (ohne `service`) und `service: "all"` (gepuffert im RAM-Flow-Kontext) → `buildDeviceHealthPoints`; (3) 900-s-Poll (`once: true`, `onceDelay: "15"`) + Long-Poll auf `ShutterContact` aller 9 Kontakte (abgeglichen mit dem im RAM-Flow-Kontext gespeicherten `deviceStatusById` aus `getDevice(undefined)`) → `buildContactStatusPoints`.
- Einbettung von `nodered_logic.js` + eingebetteten Teilen aus `devices.json` in die Function-Nodes ohne Duplikation und ohne `node.warn`.

- [ ] **Schritt 4: Gesamte Node.js-Testsuite ausführen**

Ausführen: `node --test scripts/haus-zentrale/tests/*.test.js`
Erwartet: PASS (`0` Fehler).

- [ ] **Schritt 5: Commit**

```powershell
git add scripts/haus-zentrale/build_nodered_flows.js scripts/haus-zentrale/tests/build_nodered_flows.test.js
git commit -m "feat(haus-zentrale): add deterministic Node-RED flow patcher and safety validator"
```

---

### Task 4: Deterministischer Grafana-Dashboard-Generator (`build_grafana_dashboard.ps1`)

**Dateien:**
- Erstellen: `scripts/haus-zentrale/build_grafana_dashboard.ps1`
- Test: `scripts/haus-zentrale/tests/Test-HausZentraleDashboard.ps1`

**Schnittstellen:**
- Konsumiert: `scripts/haus-zentrale/devices.json`
- Produziert: `scripts/haus-zentrale/build_grafana_dashboard.ps1 [-OutputPath <string>]` (gibt das vollständige Grafana-API-Payload-Objekt zurück bzw. schreibt es als UTF-8-JSON ohne BOM nach `-OutputPath`).

- [ ] **Schritt 1: Fehlschlagendes PowerShell-Testskript schreiben (inkl. Review Focus #5)**

Lege `scripts/haus-zentrale/tests/Test-HausZentraleDashboard.ps1` an (`Set-StrictMode -Version Latest`, Exit-Code `!= 0` bei Fehlern) und prüfe:
- Dashboard-Metadaten: `uid -eq 'jaylab-haus-zentrale'`, `title -eq 'Jaylab Haus-Zentrale'`, `time.from -eq 'now-24h'`, `time.to -eq 'now'`, `refresh -eq '1m'`, Tags enthalten `'smart-home'` und `'jaylab'`.
- Exakt 5 `row`-Panels: Row 1 (`Auf einen Blick`, `collapsed -eq $false`), Row 2 (`Heizung & Raumklima`, `collapsed -eq $false`), Row 3 (`Energie & Verbraucher`, `collapsed -eq $true`), Row 4 (`Türen, Fenster & Wetter`, `collapsed -eq $true`), Row 5 (`Sensoren & Technik`, `collapsed -eq $true`); eingeklappte Rows tragen ihre Unter-Panels innerhalb von `row.panels` (Grafana-13.3.1-Format).
- Gesamter JSON-Text enthält `0` Vorkommen von `Ela-Wandheizung`, während `Springer` in Row 1, Row 3 und Row 5 vorkommt.
- **Review Focus #5 (Raum-Matrix & Kontakt-/Aqara-Regeln):**
  - Raum-Matrix (`table`-Panel in Row 2) besitzt mehrere Query-Targets (keine typgemischte Flux-`union` über `float` und `string`), mindestens eine Transformation mit `id -eq 'joinByField'` auf `Raum`, eine Referenz auf `hdm:HomeMaticIP:3014F711A000289BB85F32B0` (`Raumthermostat`) als Primärfühler in `E2 Wohn-/Eßzimmer`, die 24-h-Frischeregel (`-24h` / `24h`) für Aqara-Fühler sowie die Anzeige von `contactStatus` (`Nicht erreichbar`).
  - Kontakt-Panels in Row 1, Row 2 und Row 4 fragen `contactStatus` ab (nicht `ShutterContact`).
- Abdeckung aller Geräte aus `devices.json`: Temperatur-Verlauf prüft alle 17 `deviceId`s + Hex-Farben, Ventilstellung alle 10 TRVs, Luftfeuchtigkeit alle 7 Feuchtefühler, Energie-Panels alle 4 Steckdosen, Tür-/Fenster-Timeline alle 9 Kontakte; alle Zeitreihen setzen `legend.displayMode = 'table'`, `legend.placement = 'bottom'`, kein `sortBy`.
- Erweiterte Zeitfenster per Panel-Query-Option: `timeFrom = '7d'` am Luftdruck-Verlauf und `timeFrom = '14d'` an den Aqara-Batterie-/Spannungs-/LQI-Verläufen.
- Keine einzige ungültige `gridPos`-Überlappung im Top-Level und in den eingeklappten Rows.

- [ ] **Schritt 2: Test ausführen und Fehlschlag bestätigen**

Ausführen: `pwsh -NoProfile -File scripts/haus-zentrale/tests/Test-HausZentraleDashboard.ps1`
Erwartet: FAIL (`build_grafana_dashboard.ps1` nicht gefunden).

- [ ] **Schritt 3: `scripts/haus-zentrale/build_grafana_dashboard.ps1` implementieren**

Erzeuge das Dashboard konsequent datengetrieben aus `devices.json`:
- Row 1 (`Auf einen Blick`): Waschmaschinen-Status (`applianceState`) + aktuelle Leistung/Zyklus-kWh + 6-h-Leistungsverlauf (mit `10 W` / `4 W`-Schwellenlinien); `Creality`-Status + W/kWh; `ZS Kompressor` & `Springer`; `Offene Kontakte` aus `contactStatus` (`X offen (von Y erreichbar)` + Liste offener/nicht erreichbarer Kontakte); `Alarmsystem` & `Anwesenheitssimulation` (`securityStatus`) + `Auffällige Geräte` (SHC `deviceHealth` + Aqara `> 6 h` / `< 25 %`).
- Row 2 (`Heizung & Raumklima`): Raum-Matrix (`table` mit getrennten Targets je Spalte `Raum`/`Sortierung`, `Ist °C`, `Soll °C`, `Diff °C`, `Ventil %`, `Heizbedarf`, `Feuchte %`, `Fenster`, zusammengeführt über `joinByField` auf `Raum`, sortiert nach Stockwerk `1..11`, `Sortierung` über `organize` ausgeblendet) sowie darunter `Temperatur-Verlauf` (17 Fühler), `Ventilstellung` (10 TRVs) und `Luftfeuchtigkeit` (7 Sensoren mit Komfortzone `40–60 %` über `thresholds`/`thresholdsStyle`).
- Row 3 (`Energie & Verbraucher`, `collapsed: true`, Unter-Panels in `row.panels`): Leistungsverlauf (W), Periodenverbrauch (kWh mittels `difference(nonNegative: true)`), Verbraucher-Übersicht (`table` mit Schaltzustand, aktueller Leistung, letztem Zyklus und Gesamt-kWh).
- Row 4 (`Türen, Fenster & Wetter`, `collapsed: true`, Unter-Panels in `row.panels`): `Tür- und Fenster-Verlauf` (`state-timeline` auf `contactStatus.state`, A–Z, `CLOSED`/`OPEN`/`UNAVAILABLE`), `Luftdruck (aktuell)`, `Luftdruck 3h-Tendenz` und `Luftdruck 7-Tage-Verlauf` (`timeFrom: "7d"`).
- Row 5 (`Sensoren & Technik`, `collapsed: true`, Unter-Panels in `row.panels`): `SHC-Gerätegesundheit` (`table` auf `deviceHealth`), `Aqara-Diagnose` (`table` auf `zigbee2mqtt` inkl. Batterie %, mV, LQI, `poweroutagecount`, Alter der letzten Meldung) sowie Zeitreihen für Batteriespannung, Batterie % und Funkqualität LQI (`timeFrom: "14d"`).

- [ ] **Schritt 4: Dashboard-Test und Workspace-Prüfung ausführen**

Ausführen:
```powershell
pwsh -NoProfile -File scripts/haus-zentrale/tests/Test-HausZentraleDashboard.ps1
pwsh -NoProfile -File scripts/Test-Workspace.ps1
```
Erwartet: Beide Befehle enden mit Exit-Code `0`.

- [ ] **Schritt 5: Commit**

```powershell
git add scripts/haus-zentrale/build_grafana_dashboard.ps1 scripts/haus-zentrale/tests/Test-HausZentraleDashboard.ps1
git commit -m "feat(haus-zentrale): add Grafana dashboard generator and validation tests"
```

---

### Task 5: Gesichertes Node-RED-Deployment auf CT 105 und Live-Verifikation

**Dateien (ausschließlich unter `.local/`, nicht in Git):**
- Erstellen: `.local/changes/2026-11-24-haus-zentrale/Deploy-NodeRedFlows.ps1`
- Erstellen: `.local/changes/2026-11-24-haus-zentrale/Rollback-NodeRedFlows.ps1`

**Schnittstellen:**
- Konsumiert: `scripts/haus-zentrale/build_nodered_flows.js`, `scripts/haus-zentrale/devices.json`, `.local/access/ssh_config_wsl` (`jaylab-proxmox`), `scripts/Test-JaylabAutomation.ps1`, `scripts/Test-JaylabNodeRed.ps1`, `.local/access/credentials/grafana.clixml`
- Produziert: Aktive erweiterte `flows.json` in CT 105, PBS-Snapshot von CT 105, Dateisicherung unter `/root/.local/jaylab/haus-zentrale-20261124/` (`0700`/`0600`) und unter `.local/changes/2026-11-24-haus-zentrale/before/`

- [ ] **Schritt 1: Rücknahme- und Rolloutskript unter `.local/changes/2026-11-24-haus-zentrale/` anlegen**

`Rollback-NodeRedFlows.ps1` stoppt `nodered.service` auf CT 105, spielt `/root/.local/jaylab/haus-zentrale-20261124/flows.json.original` (mit SHA-256-Abgleich und Eigentümer `jay:jay`, Modus `0644`) zurück und startet `nodered.service`. `Deploy-NodeRedFlows.ps1` führt alle Vorab-Sicherungen, den Offline-Patch/Validator, die Installation und den Start durch.

- [ ] **Schritt 2: Vorab-Sicherung auf CT 105 / `proxmox` anlegen**

Ausführen (über `wsl.exe --exec ssh -F /mnt/c/Users/ajjay/Documents/GitHub/jaylab/.local/access/ssh_config_wsl jaylab-proxmox ...`):
- PBS-Snapshot: `vzdump 105 --storage proxmox-backupserver --mode snapshot --notes-template "pre-haus-zentrale-2026-11-24"` (Backup-ID protokollieren).
- Dateisicherung auf `proxmox` außerhalb CT 105 unter `/root/.local/jaylab/haus-zentrale-20261124/` (`chmod 700` Verzeichnis, `chmod 600` Datei) + SHA-256 notieren + lokale Kopie (ohne `flows_cred.json`!) nach `.local/changes/2026-11-24-haus-zentrale/before/flows.original.json`.

- [ ] **Schritt 3: Kandidaten erzeugen, validieren und auf CT 105 aktivieren**

Ausführen:
```powershell
node scripts/haus-zentrale/build_nodered_flows.js .local/changes/2026-11-24-haus-zentrale/before/flows.original.json .local/changes/2026-11-24-haus-zentrale/candidate-flows.json
pwsh -NoProfile -File .local/changes/2026-11-24-haus-zentrale/Deploy-NodeRedFlows.ps1
```
Erwartet: `validatePatchedFlows` bestanden, `nodered.service` gestoppt, `flows.json` mit Eigentümer `jay:jay` und Rechten `0644` aktiviert, `nodered.service` aktiv und fehlerfrei im Journal.

- [ ] **Schritt 4: Dienst- und Protokollabnahme CT 105**

Ausführen:
```powershell
pwsh -NoProfile -File scripts/Test-JaylabAutomation.ps1 -Service shc
pwsh -NoProfile -File scripts/Test-JaylabNodeRed.ps1
```
Erwartet: Beide Prüfungen melden HTTP/GET OK ohne Fehler; Node-RED-Journal (`journalctl -u nodered -n 50`) zeigt aktive Flows ohne Ausnahmen oder unbeabsichtigte `putState`-Meldungen.

- [ ] **Schritt 5: InfluxDB-Live-Nachweis der neuen Measurements und `ShutterContact`-Schutz**

Nach ~90 Sekunden (Initial-`once`-Polls abgeschlossen) über `/grafana/api/ds/query` auf Bucket `shcbucket` (`-15m`) abfragen und bestätigen:
- Alle 6 neuen Measurements (`powerMeter` inkl. `Springer`, `applianceState` für `Waschmaschine` und `Creality`, `roomClimate` mit 9 Räumen, `securityStatus`, `deviceHealth` mit 25 physischen Geräten, `contactStatus` mit 9 Kontakten) enthalten mindestens einen aktuellen Punkt.
- `temperature` enthält alle 11 SHC-Fühler, `valveTappetState` alle 10 TRVs.
- `ShutterContact` enthält nach `now-15m` weiterhin **höchstens** die bisherigen 6 Alt-Kontakte (`Werkstattfenster`, `Fenster-Samuel`, `Fenster-Vincent` erscheinen dort **nicht**).
*(Bei Fehlschlag sofort `Rollback-NodeRedFlows.ps1` ausführen und Ursache prüfen.)*

---

### Task 6: Grafana-Rollout auf CT 102, 3×-Abnahme, Alt-Dashboard-Prüfung und Abschlußdokumentation

**Dateien:**
- Erstellen (lokal): `.local/changes/2026-11-24-haus-zentrale/Deploy-GrafanaDashboard.ps1`
- Erstellen (lokal): `.local/changes/2026-11-24-haus-zentrale/Verify-HausZentrale.ps1`
- Erstellen (Git): `docs/AENDERUNG-HAUS-ZENTRALE-2026-11-24.md`

**Schnittstellen:**
- Konsumiert: `scripts/haus-zentrale/build_grafana_dashboard.ps1`, `.local/access/credentials/grafana.clixml`, Live-Daten aus Task 5
- Produziert: Produktives Dashboard `https://grafana.jaylab.org/grafana/d/jaylab-haus-zentrale/jaylab-haus-zentrale` + vollständiges Änderungsprotokoll `docs/AENDERUNG-HAUS-ZENTRALE-2026-11-24.md`

- [ ] **Schritt 1: Vorab-API-Export aller 5 bestehenden Dashboards und `wbQMs6J4k`**

Vor dem Upload alle Bestands-JSONs (`_ts0ZCT4k`, `mttazdTnz`, `unEDfmJVk`, `kgz9x6J4z`, `YjZPR_A7k`, `wbQMs6J4k`) per `GET` in `.local/changes/2026-11-24-haus-zentrale/before-api/` ablegen und exakte Versionsnummern sichern.

- [ ] **Schritt 2: Dashboard `jaylab-haus-zentrale` erzeugen und über Grafana-API einspielen**

Ausführen:
```powershell
pwsh -NoProfile -File scripts/haus-zentrale/build_grafana_dashboard.ps1 -OutputPath .local/changes/2026-11-24-haus-zentrale/candidate-dashboard.json
pwsh -NoProfile -File .local/changes/2026-11-24-haus-zentrale/Deploy-GrafanaDashboard.ps1
```
Erwartet: HTTP `200`, `status: "success"`, `uid: "jaylab-haus-zentrale"`, `version: 1`.

- [ ] **Schritt 3: 3× deterministische Live-Abnahme und Negativ-/Bestandsschutzprüfung (`Verify-HausZentrale.ps1`)**

Ausführen:
```powershell
pwsh -NoProfile -File .local/changes/2026-11-24-haus-zentrale/Verify-HausZentrale.ps1
```
Prüft programmatisch:
1. Drei aufeinanderfolgende Läufe gegen `POST /grafana/api/ds/query` auf **alle** Panels von `jaylab-haus-zentrale` (Top-Level sowie eingeklappte Rows 3–5): identische Seriennamen/Reihenfolge, kein unerwartetes `No data`, keine rohen `hdm:HomeMaticIP:...`- oder `zigbee2mqtt/...`-Labels, Anzeigename `Springer` vorhanden, `0` Vorkommen von `Ela-Wandheizung`.
2. Raum-Matrix zeigt alle 11 Klimaräume; `Keller / Tiefkeller` zeigt bei `> 24 h` Funkstille sauber keinen Live-Temperaturwert, während Row 5 (`Aqara-Diagnose`) den letzten bekannten Wert und das Alter ausweist.
3. Bestandsprüfung der Alt-Dashboards: Versionsnummern von `wbQMs6J4k`, `unEDfmJVk`, `_ts0ZCT4k`, `mttazdTnz`, `kgz9x6J4z` und `YjZPR_A7k` sind exakt unverändert; erneuter Lauf der Abfrageprüfung aus `.local/changes/2026-11-22-grafana/verify-dashboards.ps1` bleibt 100 % PASS.

- [ ] **Schritt 4: Änderungsdokumentation nach Vorlage erstellen**

Erstelle `docs/AENDERUNG-HAUS-ZENTRALE-2026-11-24.md` streng nach [docs/vorlagen/AENDERUNG.md](../../vorlagen/AENDERUNG.md) (in Rechtschreibung von vor 1996, ohne Gendern, ohne Geheimnisse) mit Ergebnis/Umfang, Istzustand, konkreten Änderungen, PBS-Backup-IDs, SHA-256-Prüfsummen, Rücknahmeverfahren für CT 105 und CT 102, vollständiger Abnahmetabelle sowie den zwei offenen Betreiberpunkten (angemeldete Browser-Sichtprüfung unter `https://grafana.jaylab.org/grafana/d/jaylab-haus-zentrale/jaylab-haus-zentrale` und Nachkalibrierung der Schwellenwerte von `Waschmaschine` / `Creality` nach dem ersten realen Zyklus).

- [ ] **Schritt 5: Gesamte lokale Prüfung und abschließender Git-Commit**

Ausführen:
```powershell
node --test scripts/haus-zentrale/tests/*.test.js
pwsh -NoProfile -File scripts/haus-zentrale/tests/Test-HausZentraleDashboard.ps1
pwsh -NoProfile -File scripts/Test-Workspace.ps1
git status --short
git add scripts/haus-zentrale docs/AENDERUNG-HAUS-ZENTRALE-2026-11-24.md docs/superpowers/specs/2026-11-24-haus-zentrale-dashboard-design.md docs/superpowers/plans/2026-11-24-haus-zentrale-dashboard.md
git commit -m "feat(haus-zentrale): deploy Node-RED telemetry and unified Grafana dashboard"
```
Erwartet: Alle Tests und `Test-Workspace.ps1` melden `0` Fehler; unter `.local/` liegende Skripte und Exporte bleiben von Git ausgeschlossen.
