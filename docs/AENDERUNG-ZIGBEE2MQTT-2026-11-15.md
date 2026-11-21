# Änderung: Zigbee2MQTT-Zugang und MQTT-Verbindung

## Ergebnis und Umfang

Auftrag vom 15. November 2026: Zugang zu `zb2mqtt` herstellen, Funktion und
Empfang prüfen, für Wiederverwendung dokumentieren. Die Anbindung des bereits
vorhandenen Dienstes an den wiederhergestellten MQTT-Broker wird mit demselben
Zertifikatsverfahren vervollständigt. Kein neues Zigbee-Netz, kein Pairing,
kein Firmwarewechsel und keine Änderung von Netzwerkkennung oder Netzschlüssel.

## Istzustand und Abhängigkeiten

CT 121 auf `proxmox`, `.250`, Zigbee2MQTT 1.29.2, zigbee-herdsman
0.14.83-hotfix.0, Node.js 19.9.0. Verwaltungszugang über geprüftes Host-SSH und
`pct exec`. Sonoff Zigbee 3.0 USB Dongle Plus als `/dev/ttyUSB0`, Z-Stack-Firmware
Revision 20210708. Das Journal bestätigt Coordinator-Start und zwölf Geräte,
hängt danach aber seit 10:51 UTC im MQTT-Verbindungsaufbau. Keine laufende
MQTT-Verbindung und kein Frontend-Listener nachgewiesen.

Der gespeicherte MQTT-Client ist seit Januar 2024 abgelaufen; der konfigurierte
Server ist `mqtt://mqtt.jaylab.local:8883`, die Serverprüfung abgeschaltet.
Die installierte MQTT-Bibliothek wertet vorhandene Schlüssel/Zertifikate zwar
als TLS-Anforderung; eine ausdrückliche `mqtts`-URL beseitigt diese Unklarheit.
Die alte CA-Infrastruktur existiert laut Betreiber nicht mehr. Der Broker
vertraut bereits der neuen Automatisierungs-CA.

## Konkrete Änderung

Vorhandenen privaten Clientschlüssel beibehalten. Öffentlichen CSR in CT 121
erzeugen und mit der bereits eingerichteten Automatisierungs-CA einen eigenen
Client `zb2mqtt.jaylab.local` ausstellen. Der private CA-Schlüssel bleibt
lokal verschlüsselt und DPAPI-geschützt; der private Dienstschlüssel bleibt
im Container. Zertifikatskandidat SHA256:
`01211BECD01A7DFA2C68D0AFD44DF572004B689759D61DE61B080807DE9A4A96`.

Betroffene Dateien in CT 121:

- `/root/client.crt`: neuer Clientzertifikatskandidat.
- `/root/ca.crt`: über geprüftes SSH abgeglichenes Brokerzertifikat als
  ausdrücklicher Server-Vertrauensanker.
- `/opt/zigbee2mqtt/data/configuration.yaml`: nur `mqtt.server` auf
  `mqtts://mqtt.jaylab.local:8883` und `mqtt.reject_unauthorized` auf `true`.

Alle weiteren Konfigurationswerte einschließlich Geräte, Zigbee-Kanal,
Netzschlüssel, Pairing-Einstellung und Frontend bleiben erhalten. Der bisher
mit `frontend: true` konfigurierte HTTP-Dienst soll nach erfolgreichem Start
ebenfalls erreichbar sein; für Prüfungen den authentifizierten Hostweg verwenden.

## Sicherung und Rücknahme

Vorher Originale und Kandidaten mit Dateimetadaten auf `proxmox` außerhalb
des LXC unter `/root/.local/jaylab/zigbee-<UTC-Zeit>/` sichern, Verzeichnis
0700, Dateien 0600. JSON-Vergleich der geparsten YAML-Konfiguration darf nur
die beiden beauftragten MQTT-Felder als Unterschied zeigen. Zertifikat gegen
vorhandenen Schlüssel und CA prüfen. Vor Aktivierung Originalhashes erneut
vergleichen. Danach Dienst kontrolliert neu starten.

Bei fehlgeschlagener Aktivierung Dienst stoppen, ausschließlich die drei
Originaldateien mit bisherigen Eigentümern und Modi atomar zurückspielen und
Dienst starten. Der unabhängige Hostzugang bleibt verfügbar. Kein zweiter
Prozeß öffnet den Coordinator, und es wird kein Backup auf ein neues Netz
zurückgespielt. Nach Start zusätzlich `database.db` und `coordinator_backup.json`
auf dem Host sichern, ohne Inhalte auszugeben.

## Abnahme

| Prüfung | Erwartet |
| --- | --- |
| systemd, Journal | Vollständiger Start statt Warten auf MQTT |
| MQTT | TLS-Prüfung und Clientanmeldung erfolgreich; Bridge online |
| Frontend | Lokaler HTTP-Aufruf erfolgreich |
| Geräteliste | Bestehende zwölf Geräte unverändert |
| Funk | Frische, nicht als retained zugestellte Geräteberichte; mit Quelle und Beobachtungszeit zählen |
| Negativabgrenzung | Nur Cache/retained-Daten beweisen keinen aktuellen Funkempfang; schlafende Geräte können im kurzen Fenster fehlen |

Vor Aktivierung zeigte eine 45-Sekunden-Beobachtung mittels `strace` am
bereits geöffneten seriellen Deskriptor keine `read`-Daten. Es wurde kein
zweites Mal auf die serielle Schnittstelle zugegriffen und kein Rohrahmen
gespeichert. Dieses kurze negative Fenster beweist keinen Ausfall aller Sender.

## Abschluß

Aktivierung und Software-Abnahme abgeschlossen. Sicherung auf `proxmox`:
`/root/.local/jaylab/zigbee-20261115T111001Z/`. Drei persistente Dateien
stimmen mit den Kandidaten überein; nur zwei MQTT-Konfigurationsfelder wurden
geändert, die IEEE-Gerätemenge blieb unverändert. MQTT-TLS, HTTP 200 und
lesender WebSocket bestanden. Keine aktuellen Geräteberichte in der
240-Sekunden-MQTT-Beobachtung; eine weitere 45-Sekunden-Serienbeobachtung
bestätigt Coordinator-Antworten, jedoch keinen AF_INCOMING_MSG.
Bereinigte Einzelbelege, Grenzen und Wiederholung stehen im
[Empfangsbericht](ZIGBEE2MQTT-ZUGANG-UND-EMPFANG.md). Ein vom Betreiber
gezielt ausgelöstes Gerät bleibt für einen positiven Empfangsnachweis nötig.
