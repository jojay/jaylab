# Entwurf: Smart-Home-Dashboard „Jaylab Haus-Zentrale“ und Node-RED-Datenerfassung

- **Datum:** 24. November 2026
- **Status:** Entwurf zur Freigabe durch den Betreiber
- **Bezug:**
  - [Grafana-Upgrade und Dashboard-Überarbeitung (22. November 2026)](../../AENDERUNG-GRAFANA-UPGRADE-DASHBOARDS-2026-11-22.md)
  - [Node-RED, MQTT, InfluxDB und Bosch SHC](../../AUTOMATISIERUNG-ZUGAENGE.md)
  - [Zigbee2MQTT: Zugang und Empfangsprüfung](../../ZIGBEE2MQTT-ZUGANG-UND-EMPFANG.md)
  - [Betrieb, Bestandsaufnahme und Wiederherstellung](../../BETRIEB.md)

---

## 1. Absicht und Hintergrund

Die Smart-Home-Visualisierung in Grafana (`CT 102`, `Grafana Enterprise 13.3.1`) verteilt sich derzeit auf fünf stark überlappende Dashboards (`BSHC-Aqara-Dashboard`, `BSHC-Dashboard`, `Aqara Batterie Status`, `Tür und Fenster` sowie `BSHC-Dashboard-DEV`). Gleichzeitig bleibt ein großer Teil der vorhandenen Hardware unsichtbar:

1. **Bereits in InfluxDB vorhanden, aber ausgeblendet:** Drei angeschlossene Bosch-Heizkörperthermostate (`HT-Vincent`, `HT-Samuel`, `HT-Lea-Arbeitszimmer`) schreiben laufend Temperatur und Ventilstellung in `shcbucket`, werden in den bestehenden Dashboards jedoch herausgefiltert. Ebenso erfaßt `zigbee2mqtt` bereits Funkqualität (`linkquality`) und Neustartzähler (`poweroutagecount`), ohne daß ein Dashboard sie auswertet.
2. **Am Bosch Smart Home Controller (SHC) live vorhanden, aber von Node-RED bisher nicht erfaßt:** Vier schalt- und meßbare Smart-Steckdosen (`Waschmaschine`, `Creality`, `ZS Kompressor`, `Springer` – im SHC noch unter dem Namen `Ela-Wandheizung`), neun Raumklimaregler (`ROOM_CLIMATE_CONTROL` mit Soll-Temperatur und Heizbedarf), zwei weitere Heizkörperthermostate (`HT-EG-Schlafzimmer`, `HT-Ankleidezimmer`), drei weitere Tür-/Fensterkontakte (`Werkstattfenster`, `Fenster-Samuel`, `Fenster-Vincent`), das Alarmsystem (`intrusionDetectionSystem`), die Anwesenheitssimulation (`presenceSimulationService`) sowie die Geräteerreichbarkeit und Störungsmeldungen (`status` / `faults`).

Im Alltag soll ein einziges zentrales Dashboard beim Öffnen sofort beantworten:

1. **Wie steht es um die Waschmaschine?** (Läuft sie, wieviel Leistung zieht sie, oder ist der Waschgang bereits **fertig**?)
2. **Wie sind Raumtemperaturen und Ventilstellungen im ganzen Haus** – einschließlich Vergleich zum jeweiligen **Soll-Wert**?
3. **Welche Zustände melden die übrigen Geräte im Haus** (weitere Steckdosen, offene Fenster/Türen, Luftfeuchte, Luftdruck, Alarm und ausgefallene oder geschwächte Sensoren)?

---

## 2. Ziele, Nicht-Ziele und Anti-Ziele

### Ziele

- Neues, eigenständiges Grafana-Dashboard **„Jaylab Haus-Zentrale“** auf CT 102, das Alltagsüberblick und Verlaufsanalyse über klappbare Bereiche (Rows) bündelt.
- Möglichst vollständige Erfassung und Darstellung aller aktiven Bestandsgeräte:
  - 10 SHC-Heizkörperthermostate (`TRV`) + 1 SHC-Raumthermostat (`THB`)
  - 9 SHC-Raumklimaregler (`ROOM_CLIMATE_CONTROL`)
  - 9 SHC-Tür-/Fensterkontakte (`SWD`)
  - 4 SHC-Smart-Steckdosen (`PSM` / `PLUG_COMPACT`)
  - SHC-Alarmsystem, Anwesenheitssimulation und Gerätegesundheit aller physischen SHC-Geräte (einschließlich Außenkamera `3yes` und `faults`)
  - alle 6 Aqara-Wettersensoren (`lumi.weather` über `zigbee2mqtt`)
- Verläßliche Zustandslogik (`Aus` / `Bereit` / `Läuft` bzw. `Druckt` / `Fertig`) in Node-RED für `Waschmaschine` und `Creality`, die kurze Wasch- oder Heizpausen sauber entprellt.
- Konsequente Verwendung kanonischer Anzeigenamen (insbesondere **`Springer`** statt `Ela-Wandheizung`), fester Hex-Farbcodes und deterministischer A–Z-Tabellenlegenden.
- Rückwärtskompatible, minimalinvasive Ergänzung bestehender Node-RED-Tabs und saubere Kapselung neuer Meßdomänen in eigenen Tabs.

### Nicht-Ziele

- **Keine Migration auf die lokale InfluxDB (CT 110):** Die produktive Cloud-Anbindung (`InfluxDB`, `uid: f7QzURA7k`, Buckets `shcbucket` und `zigbee2mqtt`) bleibt bestehen; eine Ablösung durch `InfluxDB-DEV` (`4XosR_0nz`) ist ein gesondertes Folgeprojekt.
- **Kein Umbau und kein Löschen bestehender Dashboards:** `BSHC-Aqara-Dashboard` (`_ts0ZCT4k`), `BSHC-Dashboard` (`mttazdTnz`), `Aqara Batterie Status` (`unEDfmJVk`), `Tür und Fenster` (`kgz9x6J4z`) und `BSHC-Dashboard-DEV` (`YjZPR_A7k`) bleiben unverändert als Rückfall bestehen.
- **Keine aktiven Schaltbefehle aus Grafana oder Node-RED:** Alle neuen Flows und Panels arbeiten rein lesend und veränderungsfrei gegenüber dem SHC (keine Steckdosen schalten, keine Soll-Temperaturen setzen, keine Szenarien auslösen, keine SHC-Geräte umbenennen).
- **Keine Push-Benachrichtigungen/Alerting-Regeln in diesem Schritt:** Das neue Measurement `applianceState` bereitet spätere Benachrichtigungen (etwa „Waschmaschine fertig“) sauber vor, richtet in diesem Vorhaben aber noch keine Alert-Kanäle ein.
- **Ausdrücklich ausgeklammert bleiben nur:** die Server-/NAS-Dashboards (`Proxmox [Flux]`, `Synology DashBoard`), rein interne SHC-Hilfsdienste (`PhilipsHueBridgeManager`, `VentilationService`) sowie die 5 verwaisten bzw. unvollständig angelernten Zigbee2MQTT-Altgeräte (die `Creality`-Steckdose wird sauber über den SHC erfaßt).

### Anti-Ziele

- **Keine unübersichtliche „Scroll-Wüste“:** Waschmaschine, Steckdosen, offene Fenster, Alarm/Ampel und die Raum-Matrix müssen ohne langes Herunterscrollen erfaßbar sein.
- **Keine falschen „Fertig“-Meldungen** während kurzer Pausen zwischen Heiz-, Wasch- und Schleuderphasen.
- **Kein unbeabsichtigtes `putState` durch Node-RED:** Ein falscher `inject`-Typ an einem `shc-device`-Node darf niemals eine Steckdose schalten, eine Soll-Temperatur überschreiben oder gar den Energiezähler (`PowerMeter`) auf `0` zurücksetzen.
- **Keine rohen `deviceId`-Kennungen** (`hdm:HomeMaticIP:...`), keine fehlenden Einheiten, keine springenden Legenden und kein „No data“ bei selten bewegten Fensterkontakten.

---

## 3. Randbedingungen und Sicherheitsvorgaben

1. **Systemumgebung (gemessener Bestand):**
   - **Node-RED (`proxmox`, CT 105, `192.168.40.223`):** Node.js `24.22.3`, Node-RED `5.0.10`, `node-red-contrib-bosch-shc` `0.8.39`, aktives Projekt `/home/jay/.node-red/projects/nodered-managed/flows.json`. `contextStorage` in `settings.js` ist `null` (Standard-RAM-Kontext).
   - **Grafana (`proxmox`, CT 102, `192.168.40.248`):** `Grafana Enterprise 13.3.1` mit Unified Storage; Dashboards dürfen ausschließlich über die offizielle Grafana-HTTP-API (`https://grafana.jaylab.org/grafana/api/...`) angelegt oder geändert werden.
   - **InfluxDB Cloud (`f7QzURA7k`):** Buckets `shcbucket` und `zigbee2mqtt` (beide mit unbegrenzter Vorhaltezeit `retentionPeriod: 0`).
2. **Kritische Sicherheitsregel für `shc-device`-Nodes in Node-RED:**
   - Die Prüfung von `/home/jay/.node-red/node_modules/node-red-contrib-bosch-shc/nodes/shc-device.js` zeigt, daß ein eingehendes `msg.payload` einen **Schreibbefehl (`putState`)** auslöst, sobald `typeof msg.payload === "boolean"` für `PowerSwitch`, `PowerMeter`, `IntrusionDetectionControl`, `PresenceSimulationConfiguration` oder `CameraLight` gilt – oder `typeof msg.payload === "number"` zwischen `5` und `30` für `RoomClimateControl`.
   - Insbesondere sendet `PowerMeter` bei `boolean` als Payload `{"@type":"powerMeterState","energyConsumption":0}` und löscht damit den Zählerstand!
   - **Verbindliche Vorgabe:** Jeder lesende Poll-`inject`-Node **muß** `payloadType: "str"` mit leerem String `payload: ""` verwenden (niemals `date`/Timestamp-Zahl und niemals `boolean`). Für Sammel-Abfragen mit `deviceId: "all"` blockiert `shc-device.js` zusätzlich jeden Schreibpfad.
3. **SHC-Batteriestatus (`BatteryLevel` vs. `deviceHealth`):**
   - Die Live-Abfrage am SHC belegt, daß `BatteryLevel.state` bei sämtlichen SHC-Geräten im Normalbetrieb `null` liefert; der deaktivierte Tab `Batteriestatus` liest fehlerhaft `state.value` und bleibt deaktiviert. Batteriewarnungen und Geräteausfälle werden stattdessen über `faults.entries` sowie den Geräte-`status` (`AVAILABLE`, `UNAVAILABLE`, `UNDEFINED`) im neuen Measurement `deviceHealth` erfaßt.
4. **Betriebs-, Sicherungs- und Geheimnisschutzregeln:**
   - Vor jeder Live-Änderung an CT 105 oder CT 102 sind Sicherungen außerhalb der Container anzulegen (PBS-Backup bzw. Dateisicherung mit Rechten `0700`/`0600` unter `/root/.local/jaylab/...` auf `proxmox`), gemäß [BETRIEB.md](../../BETRIEB.md).
   - Keine Kennwörter, Tokens, privaten Schlüssel oder Konto-E-Mail-Adressen in Repository-Dateien oder Protokolle schreiben.
   - In `node-red-contrib-bosch-shc` beim `inject`/`influxdb`-Konfigurationsnode wird die vorhandene `influxdb`-Konfiguration (`2be7c8fd.d795c8`) wiederverwendet; neue Function-Nodes verzichten auf unnötiges `node.warn(msg)` im Regelbetrieb.

---

## 4. Betrachtete Ansätze

| Kriterium | Ansatz A: Schlanke Haus-Zentrale | Ansatz B: Smarte Haus-Zentrale mit Statuslogik & Soll/Ist *(gewählt)* | Ansatz C: Zweiteiliges Cockpit |
| --- | --- | --- | --- |
| **Node-RED-Umfang** | Nur 4 Steckdosen + 2 TRVs + 3 Fensterkontakte ergänzen | Wie A, plus Waschmaschinen-/Creality-Zustandsautomat, 9× `ROOM_CLIMATE_CONTROL`, Alarm/Anwesenheit, `deviceHealth` + bereinigte `join`-Zähler | Identisch zu B |
| **Waschmaschine „Fertig“** | Nur über Watt-Kurve ablesbar | Eindeutige Status-Kachel (`Aus`/`Bereit`/`Läuft`/`Fertig`) + Zyklus-kWh + Kurve | Identisch zu B |
| **Raumklima** | Nur Ist + Ventil | Ist, **Soll**, Differenz, Heizbedarf, Ventil, Feuchte und Fenster je Raum | Identisch zu B |
| **Dashboard-Pflege** | 1 Dashboard | **1 Dashboard** mit 5 klappbaren Rows | 2 getrennte Dashboards („Haus jetzt“ + „Analyse“) |
| **Abwägung** | Geringstes Risiko, aber Kurven-Raten bei der Waschmaschine und fehlende Soll-Werte | Optimaler Kompromiß aus schneller Übersicht, voller Geräteabdeckung und geringer Pflege | Am Handy ohne Scrollen, aber doppelte Pflege und ständiger Wechsel für Verläufe |

**Entscheidung:** Der Betreiber hat **Ansatz B** gewählt und ausdrücklich Wert darauf gelegt, möglichst alle vorhandenen Geräte einzubinden. *(Verworfene Alternative ohne Node-RED: scheitert am Kernwunsch Waschmaschine, da bislang keine Steckdosenwerte erfaßt werden.)*

---

## 5. Vollständige Gerätezuordnung, Kanonische Namen und Farbcodes

### 5.1 Raumklima-Fühler (10 SHC-TRVs, 1 SHC-Raumthermostat, 6 Aqara-Sensoren)

Die bisherigen 12 Farben bleiben identisch erhalten; die 5 neu aufgenommenen SHC-Fühler erhalten klar unterscheidbare feste Hex-Farben:

| Quelle / Bucket | `deviceId` | SHC-Gerätename / -Raum | Kanonischer Anzeigename | Farbcode |
| --- | --- | --- | --- | --- |
| SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005D585C78C6` | `HT-Arbeitszimmer` (`E2:Arbeitszimmer`, TRV) | `Arbeitszimmer` | `#73BF69` |
| SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005D58597571` | `HT-Badezimmer` (`E3:Badezimmer`, TRV) | `Badezimmer (SHC)` | `#F2495C` |
| SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005BB85F9F08` | `HT-Esseck` (`E2:Wohn/Esszimmer`, TRV) | `Esseck` | `#B877D9` |
| SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000289BB85F32B0` | `Raumthermostat` (`E2:Wohn/Esszimmer`, THB) | `Raumthermostat` | `#3274D9` |
| SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005D585C79B6` | `HT-Umkleidezimmer` (`E2:Umkleideraum`, TRV) | `Umkleidezimmer OG` | `#FADE2A` |
| SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005BB85F9E0D` | `HT-Wohnzimmer` (`E2:Wohn/Esszimmer`, TRV) | `Wohnzimmer` | `#5794F2` |
| SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005398584A0F` | `HT-Vincent` (`Vincent`, TRV) | `Vincent (SHC)` | `#FF9830` |
| SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005398584BCF` | `HT-Samuel` (`Samuel`, TRV) | `Samuel (SHC)` | `#E07A5F` |
| SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A0000053985B4092` | `HT-Lea-Arbeitszimmer` (`Lea Arbeitszimmer `, TRV) | `Lea Arbeitszimmer` | `#1F78C1` |
| SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A000005D5859748B` | `HT-EG-Schlafzimmer` (`E1:Schlaf`, TRV) | `Schlafzimmer Eltern (SHC)` | `#A352CC` |
| SHC (`shcbucket`) | `hdm:HomeMaticIP:3014F711A0000053985846BB` | `HT-Ankleidezimmer` (`E3:Ankleidezimmer`, TRV) | `Ankleidezimmer` | `#8AB8FF` |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091adbe3` | `aquara-SZ-Badezimmer` | `Badezimmer (Aqara)` | `#C0D8FF` |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091c96be` | `aquara-SZ-Kueche` | `Küche (Aqara)` | `#9FDD12` |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091adb08` | `aquara-SZ-Eltern` | `Schlafzimmer Eltern` | `#CA95E5` |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091a463f` | `aquara-SZ-Samuel` | `Schlafzimmer Samuel` | `#EAB839` |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091a459e` | `aquara-SZ-Vincent` | `Schlafzimmer Vincent` | `#37872D` |
| Aqara (`zigbee2mqtt`) | `zigbee2mqtt/0x00158d00091a4176` | `aquara-SZ-Tiefkeller` | `Tiefkeller` | `#0BD7CD` |

### 5.2 Raumklimaregler (`ROOM_CLIMATE_CONTROL`, 9 Räume)

| `deviceId` | SHC-Raumname | Kanonischer Raum in Matrix |
| --- | --- | --- |
| `roomClimateControl_hz_2` | `E3:Badezimmer` | `E3 Badezimmer` |
| `roomClimateControl_hz_9` | `E3:Ankleidezimmer` | `E3 Ankleidezimmer` |
| `roomClimateControl_hz_1` | `E2:Wohn/Esszimmer` | `E2 Wohn-/Eßzimmer` |
| `roomClimateControl_hz_7` | `E2:Arbeitszimmer` | `E2 Arbeitszimmer` |
| `roomClimateControl_hz_8` | `E2:Umkleideraum` | `E2 Umkleideraum` |
| `roomClimateControl_hz_3` | `E1:Schlaf` | `E1 Schlafzimmer Eltern` |
| `roomClimateControl_hz_15` | `Lea Arbeitszimmer ` | `Lea Arbeitszimmer` |
| `roomClimateControl_hz_13` | `Samuel` | `Samuel` |
| `roomClimateControl_hz_12` | `Vincent` | `Vincent` |

### 5.3 Tür- und Fensterkontakte (`SWD`, alle 9 Kontakte)

| `deviceId` | SHC-Name (Raum) | Kanonischer Anzeigename | Raumzuordnung in Matrix |
| --- | --- | --- | --- |
| `hdm:HomeMaticIP:3014F711A000009D585A160F` | `Fenster-Arbeitszimmer` (`E2:Arbeitszimmer`) | `Fenster Arbeitszimmer` | `E2 Arbeitszimmer` |
| `hdm:HomeMaticIP:3014F711A000009D585A25E5` | `Fenster-Bad` (`E3:Badezimmer`) | `Fenster Bad` | `E3 Badezimmer` |
| `hdm:HomeMaticIP:3014F711A000009D585A191E` | `Fenster-EG-Schlafzimmer` (`E1:Schlaf`) | `Fenster EG Schlafzimmer` | `E1 Schlafzimmer Eltern` |
| `hdm:HomeMaticIP:3014F711A000009D5858CD31` | `Fenster-Esszimmer` (`E2:Wohn/Esszimmer`) | `Fenster Esszimmer` | `E2 Wohn-/Eßzimmer` |
| `hdm:HomeMaticIP:3014F711A000009D585A1636` | `Garagentor` (`E0:Wagenhalle`) | `Garagentor` | *(Außen-/Zugangskontakt)* |
| `hdm:HomeMaticIP:3014F711A000009D585A1652` | `Tür Hauseingang` (`E0:Haus-Foyer`) | `Tür Hauseingang` | *(Außen-/Zugangskontakt)* |
| `hdm:HomeMaticIP:3014F711A000009398584454` | `Werkstattfenster` (`Keller`) | `Werkstattfenster` | `Keller / Tiefkeller` |
| `hdm:HomeMaticIP:3014F711A000009398584465` | `Fenster-Samuel` (`Samuel`) | `Fenster Samuel` | `Samuel` |
| `hdm:HomeMaticIP:3014F711A000009A185930F2` | `Fenster-Vincent` (`Vincent`) | `Fenster Vincent` | `Vincent` |

### 5.4 Smart-Steckdosen und System-/Sicherheitsgeräte

| `deviceId` | SHC-Gerät & Typ | Kanonischer Anzeigename | Farbcode | Bemerkung |
| --- | --- | --- | --- | --- |
| `hdm:HomeMaticIP:3014F711A0000493985923FF` | `Waschmaschine` (`PSM`, Waschküche) | `Waschmaschine` | `#5794F2` | Leistung, Energie, Schaltzustand + Zustandsautomat |
| `hdm:ZigBee:842712fffebbc43f` | `Creality` (`PLUG_COMPACT`, Keller) | `Creality` | `#FF9830` | Leistung, Energie, Schaltzustand + Zustandsautomat |
| `hdm:HomeMaticIP:3014F711A0000495385A125B` | `ZS Kompressor` (`PSM`, Keller) | `ZS Kompressor` | `#73BF69` | Leistung, Energie, Schaltzustand |
| `hdm:HomeMaticIP:3014F711A00004953859DEF1` | `Ela-Wandheizung` (`PSM`, E1:Schlaf) | **`Springer`** | `#B877D9` | Name vom Betreiber festgelegt (`Springer`); derzeit `UNDEFINED` / `PowerMeter: null` |
| `intrusionDetectionSystem` | `-IntrusionDetectionSystem-` | `Alarmsystem` | — | `IntrusionDetectionControl` + `SurveillanceAlarm` |
| `presenceSimulationService` | `-PresenceSimulationService-` | `Anwesenheitssimulation` | — | `PresenceSimulationConfiguration` |
| `hdm:Cameras:a692861d-be1b-3b98-a47b-9f33e83a46fe` | `3yes` (`CAMERA_EYES`, Außenbereich) | `Außenkamera 3yes` | — | Nur über `deviceHealth` erfaßt (derzeit `UNAVAILABLE`) |

---

## 6. Node-RED-Erweiterung und Datenmodell (`shcbucket`)

### 6.1 Bestehende Tabs minimalinvasiv bereinigen

Um volle Rückwärtskompatibilität zu den Alt-Dashboards und zum Library-Panel `wbQMs6J4k` zu wahren, bleiben Measurement-Namen, Field-Namen und `deviceId`-Tags in bestehenden Tabs unverändert:

| Tab | Geplante Änderung | Begründung |
| --- | --- | --- |
| `Temperatur` | `HT-EG-Schlafzimmer` und `HT-Ankleidezimmer` ergänzen; `join` auf `count: 11`, `timeout: 30` (bisher `count: 6`, `timeout: 60`) | Alle 11 SHC-Temperaturfühler in `shcbucket` (`temperature`/`temp`); kürzeres Timeout verhindert Hänger bei Geräteausfall |
| `Ventilstellung` | `HT-EG-Schlafzimmer` und `HT-Ankleidezimmer` ergänzen; `join` auf `count: 10`, `timeout: 30` (bisher `count: 5`, `timeout: 60`) | Alle 10 Heizkörper-Ventile in `shcbucket` (`valveTappetState`/`position`) |
| `Fensterkontakt` | Doppeltes `Tür Hauseingang`-Node entfernen; **streng bei den bisherigen 6 Kontakten** im Measurement `ShutterContact` bleiben (optional 15-Min.-`inject` mit `payload: ""` nur auf diese 6 Kontakte) | Das geteilte Library Panel `wbQMs6J4k` (`Tür und Fenster Status`, eingebunden in `_ts0ZCT4k`) filtert `ShutterContact` nicht nach `deviceId`. So bleiben alle 5 Alt-Dashboards inklusive `wbQMs6J4k` und `kgz9x6J4z` zu 100 % unverändert und frei von neuen rohen `deviceId`s |
| `Humidity`, `zigbee2mqtt` | Unverändert lassen | Liefern bereits vollständig und fehlerfrei |
| `Batteriestatus` | Weiterhin deaktiviert lassen | Liest `BatteryLevel.state.value` (`null`); abgelöst durch `deviceHealth` |
| `Alarm` | Durch den neuen Tab `Sicherheit & Gesundheit` ablösen bzw. dort sauber nach InfluxDB schreiben | Bisher nur an `debug`-Nodes verdrahtet |

### 6.2 Drei neue Node-RED-Tabs (alle Poll-`inject`s strikt mit `payload: ""`)

Alle drei neuen Tabs schreiben über den bestehenden InfluxDB-v2-Konfigurationsnode (`2be7c8fd.d795c8`) in den Bucket `shcbucket`. Soweit ein `shc-device`-Node `device: all` verwendet, müssen Auswertungsfunktionen sowohl Arrays (aus periodischem Poll) als auch Einzelobjekte (aus dem Long-Poll-Listener) normalisieren und Nullwerte (`state == null`, z. B. bei `Springer`) sauber überspringen.

#### A. Tab `Steckdosen & Geräte`

1. **Erfassung `powerMeter`:**
   - Für alle 4 Steckdosen (`Waschmaschine`, `Creality`, `ZS Kompressor`, `Springer`) werden `PowerMeter` und `PowerSwitch` per Long-Poll (`poll: true`) und per 60-Sekunden-Intervall (`inject`, `payload: ""`, `once: true`) abgefragt und je Gerät im RAM-Flow-Kontext zusammengeführt, so daß vollständige Punkte geschrieben werden.
   - **Measurement `powerMeter`:**
     - Tags: `deviceId`, `deviceName` (kanonisch, also **`Springer`** für `...9DEF1`), `room`
     - Fields: `power` (float, W — nur wenn numerisch vorhanden), `energyWh` (float, Wh kumulativ — nur wenn numerisch vorhanden), `switchOn` (int `0`/`1`)
2. **Zustandsautomat `applianceState` (`Waschmaschine` und `Creality`) *(Festlegung des Erstellers, vom Betreiber grundsätzlich bestätigt)*:**
   - Alle Schwell- und Haltezeiten stehen zentral als leicht änderbares Konfigurationsobjekt am Kopf des Function-Nodes (Speicherung des Laufzeitzustands im Standard-RAM-Flow-Kontext ohne Änderung an `settings.js`).
   - Startparameter:
     - **`Waschmaschine`:** `startThresholdW = 10`, `startHoldSec = 60`, `stopThresholdW = 4`, `stopHoldSec = 300`, `doneAutoResetMin = 240`
     - **`Creality`:** `startThresholdW = 15`, `startHoldSec = 60`, `stopThresholdW = 8`, `stopHoldSec = 300`, `doneAutoResetMin = 240`
   - Zustände: `0 = Aus` (`switchOn == 0`), `1 = Bereit` (`switchOn == 1`, Ruhezustand), `2 = Läuft` (Waschmaschine) bzw. `2 = Druckt` (Creality), `3 = Fertig`.
   - Übergänge:
     - Ausschalten (`switchOn == 0`) wechselt sofort in `0 (Aus)` und beendet ggf. den Zustand `Fertig`.
     - Liegt `power >= startThresholdW` ununterbrochen mindestens `startHoldSec` an, startet ein Durchgang (`2`), und `cycleStartWh` sowie `cycleStartMs` werden vermerkt.
     - Fällt `power < stopThresholdW` ununterbrochen mindestens `stopHoldSec` lang (Entprellen von Heiz-/Einweich- oder Abkühlpausen), wechselt der Zustand in `3 (Fertig)`; `cycleEnergyWh` (`energyWh - cycleStartWh`, >= 0), `cycleDurationMin` und `finishedAtEpoch` (Unix-Sekunden) werden gespeichert.
     - Nach `doneAutoResetMin` (`240` Minuten) ohne erneutes Einschalten/Starten fällt `3 (Fertig)` automatisch auf `1 (Bereit)` zurück.
     - Nach einem Node-RED-Neustart beginnt der Automat konservativ in `Aus` oder `Bereit` und erkennt eine aktiv laufende Maschine innerhalb von 60 Sekunden automatisch wieder als `Läuft`/`Druckt`.
   - **Measurement `applianceState`** (geschrieben bei jedem Zustandswechsel plus 5-Minuten-Heartbeat):
     - Tags: `deviceId`, `deviceName`
     - Fields: `stateCode` (int `0..3`), `stateText` (string), `cycleEnergyWh` (float), `cycleDurationMin` (float), `finishedAtEpoch` (int)
   - *Kalibrierungshinweis:* Nach dem ersten vollständig aufgezeichneten Waschgang bzw. 3D-Druck sind die realen Standby- und Pausenleistungen in `powerMeter` gegen die Startschwellen zu prüfen und bei Bedarf im Konfigurationsobjekt nachzujustieren.

#### B. Tab `Raumklima (Soll)`

- Abfrage aller 9 `ROOM_CLIMATE_CONTROL`-Instanzen (`service: "RoomClimateControl"`, Long-Poll `poll: true` + 5-Minuten-Poll mit `payload: ""`, `once: true`).
- **Measurement `roomClimate`:**
  - Tags: `deviceId`, `room` (kanonischer Raumname gemäß Abschnitt 5.2)
  - Fields: `setpoint` (float, °C), `hasDemand` (int `0`/`1`), `boostMode` (int `0`/`1`), `ventilationMode` (int `0`/`1`), `summerMode` (int `0`/`1`), `operationMode` (string)

#### C. Tab `Sicherheit & Gesundheit`

1. **Alarm und Anwesenheitssimulation (`securityStatus`):**
   - Abfrage von `intrusionDetectionSystem` (`IntrusionDetectionControl`, `SurveillanceAlarm`) und `presenceSimulationService` (`PresenceSimulationConfiguration`) per Long-Poll + 5-Minuten-Poll (`payload: ""`, `once: true`).
   - **Measurement `securityStatus`:**
     - Tags: `deviceId`, `service`
     - Fields: `armed` (int: `0 = DISARMED`, `1 = ARMED`, `2 = ARMING`), `alarmActive` (int `0`/`1`), `presenceSimEnabled` (int `0`/`1`), `statusText` (string)
2. **SHC-Gerätegesundheit (`deviceHealth`):**
   - Alle 10 Minuten lesender Abruf (`inject`, `payload: ""`, `once: true`) über `shc-device` (`device: all`, ohne `service` → `getDevice(undefined)`) für den Geräte-`status` sowie `shc-device` (`device: all`, `service: all` → `getDeviceServices(undefined, undefined)`) zum Einsammeln vorhandener `faults.entries`.
   - Erfaßt werden alle **25 physischen SHC-Geräte** (Modelle `TRV`, `THB`, `SWD`, `PSM`, `PLUG_COMPACT`, `CAMERA_EYES`; virtuelle `ROOM_CLIMATE_CONTROL`- und Manager-Dienste werden herausgefiltert). Für `hdm:HomeMaticIP:3014F711A00004953859DEF1` wird `deviceName` auf **`Springer`** abgebildet.
   - **Measurement `deviceHealth`:**
     - Tags: `deviceId`, `deviceName`, `deviceModel`, `room`
     - Fields: `available` (int `1` bei `status == "AVAILABLE"`, sonst `0`), `statusText` (string: `AVAILABLE` / `UNAVAILABLE` / `UNDEFINED`), `faultCount` (int), `faultSummary` (string, `"OK"` falls keine Störung)
3. **Vollständige Kontakt-Erfassung (`contactStatus`, alle 9 Kontakte):**
   - Erfaßt alle **9 Tür-/Fensterkontakte** über Long-Poll (`ShutterContact`) sowie einen 15-Minuten-Vollabruf (`inject`, `payload: ""`, `once: true`) und gleicht jeden Kontakt gegen den aktuellen Geräte-`status` aus `getDevice(undefined)` ab.
   - **Measurement `contactStatus`:**
     - Tags: `deviceId`, `deviceName` (kanonischer Name gemäß Abschnitt 5.3), `room`
     - Fields: `state` (string: `"OPEN"`, `"CLOSED"` oder `"UNAVAILABLE"`, sobald der SHC-Geräte-`status != "AVAILABLE"` ist), `isOpen` (int: `1` nur bei `AVAILABLE` und `"OPEN"`, sonst `0`), `available` (int: `1` bei `status == "AVAILABLE"`, sonst `0`)
   - Das neue Dashboard **„Jaylab Haus-Zentrale“** liest für alle Kontakt-Panels in Row 1, Row 2 und Row 4 ausschließlich `contactStatus`.

---

## 7. Grafana-Dashboard „Jaylab Haus-Zentrale“

- **Metadaten *(Festlegungen des Erstellers)*:** Titel `Jaylab Haus-Zentrale`, eigene neue UID (z. B. `jaylab-haus-zentrale`), Standard-Zeitbereich `now-24h..now`, Auto-Refresh `1m`, Tags `["smart-home", "jaylab"]`, Datenquelle `InfluxDB` (`uid: f7QzURA7k`).
- **Einheitliche Gestaltungsregeln:** Alle Zeitreihen nutzen feste Hex-Farben aus Abschnitt 5 und tabellarische Legenden unterhalb der Graphen (`displayMode: "table"`, `placement: "bottom"`) in fester alphabetischer A–Z-Reihenfolge ohne dynamische Sortierung (`sortBy`), wie in [AENDERUNG-GRAFANA-UPGRADE-DASHBOARDS-2026-11-22.md](../../AENDERUNG-GRAFANA-UPGRADE-DASHBOARDS-2026-11-22.md) bewährt.

### Row 1: „Auf einen Blick“ *(immer offen)*

- **Waschmaschine (Fokusbereich links, ca. 10 von 24 Spalten breit):**
  - Stat-Kachel für den aktuellen Zustand (`Aus` grau / `Bereit` blau / `Läuft` orange / `Fertig` grün), aktuelle Leistung (W) sowie bei `Fertig`/`Läuft` Zeitpunkt (`finishedAtEpoch`), Zyklusdauer und Zyklus-kWh.
  - Direkt daneben bzw. darunter ein kompakter 6-Stunden-Leistungsverlauf (Timeseries/Sparkline in W mit Schwellenmarkierung), damit Verlauf und Zustand ohne Scrollen sichtbar bleiben.
- **Creality & weitere Steckdosen (ca. 6 Spalten):**
  - Status-Kachel `Creality` (`Aus` / `Bereit` / `Druckt` / `Fertig`, W, letzter Zyklus).
  - Kompakte Status-Kacheln für `ZS Kompressor` und `Springer` (Schaltzustand + aktuelle W bzw. `Nicht erreichbar`).
- **Fenster & Türen (ca. 4 Spalten) *(Festlegung des Erstellers)*:**
  - Liest `contactStatus` (nicht veraltete Cache-Werte aus `ShutterContact`) und zeigt **`X offen (von Y erreichbar)`** (grün bei `X = 0`, rot bei `X >= 1`; aktuell z. B. `0 / 7`) sowie gesondert die Anzahl nicht erreichbarer Kontakte (gelb, aktuell `2`: `Tür Hauseingang`, `Garagentor`), ergänzt um die Namen offener Kontakte bei `X > 0`.
- **Haus-Status: Alarm & Geräte-Ampel (ca. 4 Spalten):**
  - Alarmsystem (`Unscharf` / `Scharf` / `ALARM`) + Anwesenheitssimulation (`Aus` / `Aktiv`).
  - Warnzähler **„Auffällige Geräte“** = Anzahl nicht erreichbarer/gestörter physischer SHC-Geräte (`deviceHealth.available == 0` oder `faultCount > 0`) plus überfälliger/batterieschwacher Aqara-Sensoren (`lastSeen > 6 h` oder `battery < 25 %`).

### Row 2: „Heizung & Raumklima“ *(standardmäßig offen)*

1. **Raum-Matrix (Table-Panel über volle Breite, 11 Klimaräume in fester Stockwerksreihenfolge):**
   - Reihenfolge von oben nach unten: `E3 Badezimmer`, `E3 Ankleidezimmer`, `E2 Wohn-/Eßzimmer`, `E2 Arbeitszimmer`, `E2 Umkleideraum`, `E2 Küche`, `E1 Schlafzimmer Eltern`, `Lea Arbeitszimmer`, `Samuel`, `Vincent`, `Keller / Tiefkeller`.
   - Spalten:
     - `Raum`
     - `Ist °C` *(Festlegung gemäß SHC-Bestand & Ersteller)*:
       - In **`E2 Wohn-/Eßzimmer`** ist der Wand-**`Raumthermostat`** (`hdm:HomeMaticIP:3014F711A000289BB85F32B0`) der primäre Temperaturfühler (entspricht der aktiven SHC-`TemperatureLevelConfiguration` in `roomClimateControl_hz_1`, in der `HT-Wohnzimmer` und `HT-Esseck` auf `active: false` stehen); nur falls `Raumthermostat` länger als `24 h` keinen Wert liefert, greift als Fallback der Mittelwert aus `Wohnzimmer` und `Esseck`.
       - In den vier Doppel-Sensor-Räumen (Badezimmer, Schlafzimmer Eltern, Samuel, Vincent) wird der frei im Raum hängende Aqara-Sensor bevorzugt, solange seine letzte Meldung `< 24 h` alt ist; sonst fällt die Anzeige automatisch auf den SHC-Fühler zurück.
       - **Einheitliche 24-Stunden-Frischeregel für alle Aqara-Fühler *(Festlegung des Erstellers)*:** Meldet ein reiner Aqara-Raum (`Keller / Tiefkeller`, `E2 Küche`) länger als `24 h` keinen Meßwert, zeigt die Live-Raum-Matrix konsequent **`–`** statt veralteter Mehrtageswerte (betrifft derzeit `Tiefkeller`). Letzter bekannter Meßwert und exaktes Alter stehen stattdessen gut sichtbar in **Row 5 („Aqara-Diagnose“)**, und **Row 1 („Auffällige Geräte“)** schlägt sofort an.
     - `Soll °C` (`roomClimate.setpoint`; `–` in Küche und Keller ohne SHC-Regler)
     - `Diff °C` (`Ist − Soll`, farbcodiert)
     - `Ventil %` (Balken-/Gauge-Zelle `0–100 %`; bei `E2 Wohn-/Eßzimmer` Maximum von `Wohnzimmer` und `Esseck`)
     - `Heizbedarf` (`hasDemand`: aktiv/inaktiv bzw. Boost/Lüften)
     - `Feuchte %` (Komfortzone `40–60 %` grün, darunter/darüber gelb/rot; `–` in Räumen ohne Feuchtefühler sowie bei Aqara-Funkstille `> 24 h`)
     - `Fenster` (`Offen` rot / `Zu` grün / **`Nicht erreichbar`** gelb bzw. grau direkt aus `contactStatus.state` für die 7 Raumkontakte, so daß kein ausgefallener Kontakt fälschlich grün als `Zu` erscheint; `Tür Hauseingang` und `Garagentor` stehen in Row 1 und Row 4) *(Festlegung des Erstellers)*
   - *Technischer Bauhinweis:* Die unterschiedlichen Datentypen (`float` und `string`) werden in Grafana über getrennte Query-Targets je Spalte und die Transformation **`Join by field` (Feld `Raum`)** zusammengeführt — nicht über ein typgemischtes Flux-`union()`.
2. **Temperatur-Verlauf (Timeseries):** Alle 17 Fühler mit kanonischen Namen, festen Hex-Farben und A–Z-Tabellenlegende (`lastNotNull`, `min`, `max`).
3. **Ventilstellung (Timeseries):** Alle 10 Heizkörper-TRVs (`0–100 %`), feste Hex-Farben, A–Z-Tabellenlegende.
4. **Luftfeuchtigkeit (Timeseries):** Alle 7 Feuchtesensoren (6 Aqara + `Raumthermostat`) mit farblich hinterlegter Komfortzone `40–60 %`.

### Row 3: „Energie & Verbraucher“ *(standardmäßig eingeklappt)*

- **Leistungsverlauf (W):** Zeitreihe für `Waschmaschine`, `Creality`, `ZS Kompressor` und `Springer`.
- **Energieverbrauch je Zeitraum (kWh):** Balken-/Zeitreihe auf Basis von `energyWh` (`difference(nonNegative: true)` bzw. `spread()`), geschützt gegen eventuelle Zähler-Rücksetzungen.
- **Verbraucher-Übersicht (Table):** Schaltzustand (`Ein`/`Aus`), aktuelle Leistung (W), letzter gemessener Wasch-/Druckzyklus (Dauer + kWh) und Gesamt-kWh seit Zählerbeginn.

### Row 4: „Türen, Fenster & Wetter“ *(standardmäßig eingeklappt)*

- **Tür- und Fenster-Verlauf (`state-timeline`):** Alle **9 Kontakte** aus `contactStatus.state` mit kanonischen Namen in A–Z-Reihenfolge (`CLOSED` grün, `OPEN` rot/orange, `UNAVAILABLE` gelb/grau).
- **Luftdruck:** Stat-Kachel (aktueller Mittelwert der aktiven Aqara-Sensoren in `hPa`), 3-Stunden-Tendenz (steigend/stabil/fallend) und 7-Tage-Verlaufskurve (`relativeTime: 7d` bzw. 14d über Panel-Query-Option).

### Row 5: „Sensoren & Technik“ *(standardmäßig eingeklappt)*

- **SHC-Gerätegesundheit (Table):** Alle 25 physischen SHC-Geräte mit Raum, Modell, Erreichbarkeit (`AVAILABLE` grün, `UNDEFINED` gelb, `UNAVAILABLE` rot), Störungsanzahl (`faultCount`), Störungstext (`faultSummary`) und Alter der letzten Prüfung. *(Macht aktuell z. B. `Tür Hauseingang`, `Garagentor`, `Springer` und `3yes` sofort sichtbar.)*
- **Aqara-Diagnose (Table + Zeitreihen):**
  - Übersichtstabelle je Aqara-Sensor: Batteriestand (%), Batteriespannung (mV), Funkqualität (`linkquality`), `poweroutagecount` und Alter der letzten Meldung (Warnstufen: `> 6 h` gelb, `> 24 h` rot — macht stumme Sensoren wie `Tiefkeller` sofort erkennbar).
  - Zeitreihen für Batteriespannung (`mV`), Batteriestand (`%`) und Funkqualität (`linkquality`) mit 14-Tage-Rückblick (`relativeTime: 14d`), unabhängig vom 24-h-Standardfenster des Dashboards.

---

## 8. Offene Punkte für den Umsetzer

Folgende Detailentscheidungen bleiben bewußt dem Umsetzungsplan und dem Umsetzer überlassen:

- Exakte Panel-IDs, `gridPos`-Koordinaten (auf dem 24-Spalten-Raster) und konkrete Schwellenwert-Farben je Panel.
- Exakte Node-RED-Node-IDs und interne Verdrahtung innerhalb der Vorgaben aus Abschnitt 6 (einschließlich Wahl zwischen Einzel-`shc-device`-Nodes oder `all`-Abfrage je neuem Tab, solange Nullwerte und Schreibschutz eingehalten sind).
- Erstellung der wiederholbaren Sicherungs-, Rollout-, Verifikations- und Rücknahmeskripte unter `.local/changes/...` gemäß [BETRIEB.md](../../BETRIEB.md), einschließlich:
  - Vorab-PBS-Backup / Dateisicherung von `flows.json` (CT 105) und Grafana-Dashboard-Export (CT 102) auf `proxmox` unter `/root/.local/jaylab/...`,
  - Nachweis gegen Node-RED, daß alle Poll-`inject`s strikt `payload: ""` senden und kein ungewolltes `putState` auftritt,
  - dreifacher deterministischer API-Abfrageprüfung gegen `/grafana/api/ds/query` für alle neuen Panels (kein `No data`, keine rohen `deviceId`s, korrekter Anzeigename `Springer`) sowie Gegenprüfung, daß die bestehenden 5 Dashboards unverändert laufen.

---

## 9. Zusammenfassung der Entwurfsfestlegungen des Erstellers

Folgende Detailpunkte wurden im Rahmen von Ansatz B als sinnvolle Standardannahmen vorgeschlagen und stehen dem Betreiber zur Gegenprüfung offen:

1. **Auto-Reset des Zustands `Fertig`:** Automatischer Rückfall auf `Bereit` nach **4 Stunden (`240` Minuten)** ohne Neustart, oder sofort beim Ausschalten der Steckdose.
2. **Start-Schwellenwerte des Zustandsautomaten:** `Waschmaschine` (`>= 10 W` für `60 s` → `Läuft`, `< 4 W` für `300 s` → `Fertig`) und `Creality` (`>= 15 W` für `60 s` → `Druckt`, `< 8 W` für `300 s` → `Fertig`), gespeichert im Standard-RAM-Kontext (ohne Änderung an `settings.js`), mit Nachkalibrierung nach dem ersten realen Lauf.
3. **Standard-Zeitfenster & Refresh:** `now-24h..now` mit `1m` Auto-Refresh (Aqara-Batterie-/LQI-Graphen und Luftdruck mit erweitertem Rückblick von 14 bzw. 7 Tagen).
4. **Doppel-Sensoren in der Raum-Matrix:** In Räumen mit Aqara- und SHC-Fühler (Badezimmer, Schlafzimmer Eltern, Samuel, Vincent) zeigt die Raum-Matrix bevorzugt den frei hängenden Aqara-Fühler (bei Daten `< 24 h`, sonst SHC-Fallback); in den Zeitreihen bleiben alle 17 Fühler sichtbar.
5. **11 Klimaräume + 2 Außenkontakte:** Die Raum-Matrix bildet die 11 Wohn-/Nutzräume ab; `Tür Hauseingang` und `Garagentor` erscheinen in Row 1 („Offene Kontakte“) und Row 4 („Türen, Fenster & Wetter“).
6. **Bestehende Dashboards bleiben unangetastet** als Rückfall bestehen.
7. **Eigenes Measurement `contactStatus` für alle 9 Kontakte:** Läßt `ShutterContact` streng bei den bisherigen 6 Kontakten, so daß alle 5 Alt-Dashboards inklusive Library Panel `wbQMs6J4k` völlig unangetastet und ohne rohe `deviceId`s bleiben.
8. **Nicht erreichbare Kontakte explizit ausweisen:** Kontakte mit SHC-Status `UNAVAILABLE`/`UNDEFINED` (aktuell `Tür Hauseingang`, `Garagentor`) erscheinen in Row 1, Row 2 und Row 4 als `Nicht erreichbar` bzw. `UNAVAILABLE` statt fälschlich grün als `Zu`.
9. **Einheitliche 24-Stunden-Frischeregel in der Raum-Matrix:** `E2 Wohn-/Eßzimmer` nutzt den `Raumthermostat` als Primärfühler (gemäß aktiver SHC-Konfiguration); reine Aqara-Räume (`Keller / Tiefkeller`, `E2 Küche`) zeigen bei `> 24 h` Funkstille `–` in der Live-Matrix und ihren Alt-Wert samt Alter in Row 5.
