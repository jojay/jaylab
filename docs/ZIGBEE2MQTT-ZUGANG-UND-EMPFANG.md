# Zigbee2MQTT: Zugang und Empfangsprüfung

Stand: 15. November 2026. **Verwaltungszugang, MQTT-TLS-Verbindung und Frontend
funktionieren. Ein aktueller Empfang von Zigbee-Geräten wurde im Prüfzeitraum
nicht nachgewiesen.** Die unmittelbar nach dem Start veröffentlichten
Sensorwerte sind alte Cachezustände und kein Nachweis lebender Sender.

## Geprüfter Bestand und Zugang

| Bestandteil | Gemessener Stand |
| --- | --- |
| Host / LXC | `proxmox`, CT 121 `zb2mqtt`, laufend, `onboot: 0` |
| Adresse | `192.168.40.250`, DHCP, Bridge `vmbr0` |
| Dienst | `zigbee2mqtt.service`, `/usr/bin/npm start`, Arbeitsverzeichnis `/opt/zigbee2mqtt` |
| Versionen | Zigbee2MQTT 1.29.2, zigbee-herdsman 0.14.83-hotfix.0, Node.js 19.9.0 |
| Empfänger | Sonoff Zigbee 3.0 USB Dongle Plus, Silicon Labs USB-Schnittstelle |
| Host-Gerätepfad | `/dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0` zeigt auf `/dev/ttyUSB0` |
| LXC-Durchreichung | `/dev/ttyUSB0`, Zeichen-Gerät 188:0, in `pct config 121` belegt |
| Coordinator | `0x00124b002a2e95b4`, Z-Stack 3.x, Firmware-Revision 20210708 |
| MQTT | `mqtts://mqtt.jaylab.local:8883`, aktuell `.213`, Kennwort und Clientzertifikat |
| Frontend | HTTP auf TCP 8080, HTTP 200 und lesender WebSocket-Empfang geprüft |
| Geräte | Zwölf Geräte zusätzlich zum Coordinator; sechs Xiaomi-Wettersensoren, drei Router, drei unvollständig identifizierte Geräte |

Administrativ den bestehenden WSL-SSH-Zugang zum Host mit strikter
Hostschlüsselprüfung verwenden. Der private SSH-Schlüssel bleibt in WSL:

```powershell
wsl.exe --exec ssh -F /mnt/c/Users/ajjay/Documents/GitHub/jaylab/.local/access/ssh_config_wsl jaylab-proxmox 'pct exec 121 -- systemctl status zigbee2mqtt --no-pager'
pwsh -NoProfile -File scripts/Test-JaylabAutomation.ps1 -Service zigbee
```

Der zweite Befehl prüft HTTP, lesenden WebSocket-Empfang, einen MQTT-TLS-CONNECT
mit der tatsächlich konfigurierten Identität und den Gerätebestand. Er
veröffentlicht keine MQTT-Nachricht und schaltet kein Gerät.
Geheimnisse verbleiben im Container. Er beweist die Anbindung, jedoch keinen
aktuellen Funkbericht eines Senders.

Für den Browser kann ein auf den lokalen Arbeitsplatz begrenzter SSH-Tunnel
verwendet werden. Der Host erreicht den Container über seine bestehende Bridge:

```powershell
wsl.exe --exec ssh -F /mnt/c/Users/ajjay/Documents/GitHub/jaylab/.local/access/ssh_config_wsl -N -L 127.0.0.1:18080:192.168.40.250:8080 jaylab-proxmox
# Danach im Browser http://127.0.0.1:18080 öffnen; Tunnel mit Strg+C beenden.
```

Das Frontend ist im Bestand als `frontend: true` ohne eigenen Token
konfiguriert. Sein HTTP- und WebSocket-Zugang ist deshalb keine nachgewiesene
SSO- oder HTTPS-Absicherung. Diese Einstellung wurde bei der Zugangsreparatur
erhalten; keine öffentliche Bereitstellung oder Firewallfreigabe wurde ergänzt.

## Durchgeführte Korrektur

Der Dienst war zunächst zwar `active`, blieb aber nach dem Coordinator-Start
beim MQTT-Verbindungsaufbau stehen. Das MQTT-Clientzertifikat war seit
21. Januar 2024 abgelaufen. Nach Sicherung wurden nur folgende Dateien geändert:

- `/root/client.crt`: eigenes Zertifikat `zb2mqtt.jaylab.local`, bestehender
  privater Schlüssel erhalten, neue Automatisierungs-CA, gültig bis
  15. November 2027.
- `/root/ca.crt`: das über den geprüften SSH-Zugang abgeglichene bestehende
  Brokerzertifikat als ausdrücklicher Server-Vertrauensanker.
- `/opt/zigbee2mqtt/data/configuration.yaml`: `mqtt.server` ausdrücklich
  `mqtts://mqtt.jaylab.local:8883`, `mqtt.reject_unauthorized: true`.

Danach kontrollierter Neustart. Das Journal bestätigt am 15. November um
12:10 MEZ (11:10 UTC) `Connected to MQTT server` und `Zigbee2MQTT started!`.
Die laufende Node-Instanz hält eine etablierte Verbindung an `.213:8883`.
HTTP 200, WebSocket und eine unabhängige volle MQTT-TLS-Anmeldung bestanden.

Sicherung auf `proxmox` außerhalb des LXC:
`/root/.local/jaylab/zigbee-20261115T111001Z/`, Verzeichnis 0700, Dateien 0600.
Sie enthält Originale/Kandidaten/Manifest der drei Dateien sowie
`database.db.network-original` und `coordinator_backup.json.network-original`.
Der abschließende Hashvergleich bestätigt die Kandidaten. Ein semantischer
YAML-Vergleich bestätigt ausschließlich die beiden genannten MQTT-Feldänderungen;
die IEEE-Gerätemenge ist unverändert. Geräte wurden weder zurückgesetzt noch
neu gepairt; keine Zigbee-Netzkennung und kein Netzschlüssel wurde geändert.
Rücknahme steht im [Änderungsprotokoll](AENDERUNG-ZIGBEE2MQTT-2026-11-15.md).

## Was zum Funkempfang tatsächlich belegt ist

1. Vor der Korrektur: 45 Sekunden am bereits geöffneten seriellen Deskriptor
   beobachtet, keine `read`-Daten. Kein zweiter Prozeß öffnete den Dongle.
2. Nach der Korrektur: 12:10:57 bis 12:11:42 MEZ, 45 Sekunden serielle
   Beobachtung. 52 Lesevorgänge, 356 Byte, 52 gültige ZNP-Rahmen ohne
   Prüfsummenfehler. Coordinator-Antworten und Sendebestätigungen sind belegt;
   **kein AF_INCOMING_MSG (0x4481)** und keine eingehende Gerätenachricht.
   Ein antwortender Coordinator allein beweist noch keinen Empfang von Sensoren.
3. MQTT-Beobachtung: 12:09:16 bis 12:13:16 MEZ, 240 Sekunden. Sechs alte
   retained-Bridge-Nachrichten und danach der vollständige Dienststart wurden
   beobachtet. Exakt sechs Sensorzustände kamen gemeinsam um 12:10:23 MEZ
   beim Start aus dem Cache. Danach kamen im Fenster keine weiteren
   Geräteberichte. Die retained-Geräteliste vor Neustart enthielt nur sechs
   Geräte; die neue Liste enthält den tatsächlichen Bestand von zwölf.
4. Zwei reine `/get`-Zustandsabfragen an die bekannten Philips-Geräte
   `0x001788010d20b66d` und `0x001788010d20b443` ergaben innerhalb von
   18 Sekunden keine Zustandsantwort. Keine `/set`-Nachricht wurde gesendet.

Die serielle Auswertung nutzte die Definition von `AF incomingMsg` der
installierten zigbee-herdsman-Version: Kommando 129, Quelle, Cluster und LQI.
Es wurden nur Metadaten gezählt, keine seriellen Rohdaten oder Sensorwerte
gespeichert. Die Trace-Prozesse sind beendet und vom Dienst getrennt.

## Gespeicherte letzte Sichtungen

Die folgenden Daten stammen aus `database.db`, nicht aus einem aktuellen
Empfang. Die Dateispeicherzeiten und die gecachten LQI-Werte ersetzen diesen
Nachweis nicht. Alle Einträge sind deutlich älter als die Prüfung:

| Gerät | Typ / Modell | Letzter gespeicherter Empfang (UTC) | Interview |
| --- | --- | --- | --- |
| `0x00158d00091a4176` | Xiaomi WSDCGQ11LM | 24.01.2026 14:34 | abgeschlossen |
| `0x00158d00091adb08` | Xiaomi WSDCGQ11LM | 14.12.2024 13:20 | abgeschlossen |
| `0x00158d00091adbe3` | Xiaomi WSDCGQ11LM | 09.01.2024 16:50 | abgeschlossen |
| `0x00158d00091a463f` | Xiaomi WSDCGQ11LM | 13.09.2024 14:04 | abgeschlossen |
| `0x00158d00091c96be` | Xiaomi WSDCGQ11LM | 14.02.2025 00:10 | abgeschlossen |
| `0x00158d00091a459e` | Xiaomi WSDCGQ11LM | 18.08.2025 22:34 | abgeschlossen |
| `0x001788010d20b66d` | Philips 1742830P7, Router | 30.01.2026 18:00 | abgeschlossen |
| `0x001788010d20b29e` | Router, Modell ungeklärt | 30.01.2026 18:00 | unvollständig |
| `0x001788010d20b443` | Philips 1742830P7, Router | 30.01.2026 18:00 | abgeschlossen |
| `0x00158d00058a151f` | unbekannt | 23.09.2024 19:44 | unvollständig |
| `0x842712fffebbc43f` | unbekannt | 14.11.2024 18:47 | unvollständig |
| `0x842e14fffef5155d` | unbekannt | 22.12.2024 16:20 | unvollständig |

Damit lautet die Antwort auf „funktioniert alles?“: **Nein, das ist nicht
nachgewiesen.** Die Softwarekette ist wieder funktionsfähig, aber aktuelle
Funkberichte fehlen und vier Geräte haben kein abgeschlossenes Interview.
Ein vollständiger Sender- oder Hardwareausfall läßt sich aus dem begrenzten
Zeitfenster ebenfalls nicht ableiten. Stromversorgung, Batterien und
tatsächliche Zuordnung der Sender müssen am Gerät geprüft werden.

## Wiederholbarer Live-Test

```powershell
pwsh -NoProfile -File scripts/Observe-JaylabZigbee.ps1 -Seconds 180
```

Der Beobachter liest mit dem bereits geprüften Node-RED-Client in CT 105
`zigbee2mqtt/#`, mit normaler TLS-Prüfung. Er veröffentlicht nichts. Retained
Nachrichten werden gesondert gezählt. Bei einem beobachteten Neustart werden
die ersten 30 Sekunden nach dem frischen Online-Signal nicht als laufender
Gerätebericht gezählt. Das alte Klartextformat `online` und das JSON-Format
werden verarbeitet. Ohne frisches Online-Signal bleibt die automatische
`afterStartupGrace`-Klassifikation zurückhaltend; Zeitstempel und Datenbank-
Sichtungen sind zusätzlich zu vergleichen. Auch ein nicht-retained
Start-Cachebericht beweist keinen neuen Funkempfang.

Während des Fensters einen bekannten Sender gezielt auslösen bzw. einen
Wettersensor mit seiner üblichen Meldetaste kurz aufwecken, ohne ihn
zurückzusetzen. Gerätekennung und Zeitpunkt notieren. Erfolg bedeutet:
neuer Gerätebericht nach der Startphase und vorgerückter `lastSeen`-Wert,
idealerweise zusätzlich ein entsprechender AF_INCOMING_MSG-Rahmen.
Bleibt der Bericht aus, zunächst Versorgung und richtige Gerätezuordnung
prüfen; nicht das Zigbee-Netz löschen oder pauschal neu pairen.

Die bestehende Einstellung `permit_join: true` wurde unverändert vorgefunden.
Das offene Beitrittsfenster ist eine gesondert zu entscheidende
Betriebseinstellung, kein erforderlicher Bestandteil der Empfangsprüfung.
