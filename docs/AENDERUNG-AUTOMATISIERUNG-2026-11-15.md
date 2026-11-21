# Änderung: MQTT-Listener und SHC-Zieladresse

## Ergebnis und Umfang

Am 15. November 2026 vom Betreiber ausdrücklich freigegeben: beide belegten
Fehler beheben. MQTT in CT 107 auf proxmox3 soll starten; Node-RED in CT 105
auf proxmox soll den bereits gekoppelten SHC wieder erreichen. Betroffen sind
Mosquitto 2.0.11 und das aktive Node-RED-Projekt `nodered-managed`.
Das erneute Laden der Flows und die mögliche Wiederaktivierung bestehender
Automatisierungen waren Teil der Freigabe. Keine Netz-, Router- oder
Firewalländerung, kein neues Pairing und kein Start gestoppter anderer LXC.

## Istzustand und Abhängigkeiten

SSH-Hostprofile erlauben root-Zugriff mit fester Hostschlüsselbindung;
`pct exec` bleibt vom Anwendungsdienst unabhängig. CT 107 besitzt `.213`,
Mosquitto bindet zusätzlich an die nicht vorhandene `.172` und scheitert.
CT 105 besitzt `.223`; der Flow verwendet SHC `.4`, das bekannte Gerät hat
laut DHCP/DNS `.231`. Die vorhandene SHC-Clientanmeldung wurde an `.231`
erfolgreich geprüft. Unveränderter Namenszugang scheitert wegen der bevorzugten
IPv6-Adreßwahl. Daher wird das konkrete SHC-IPv4-Ziel berichtigt.
Beide LXC hängen an `vmbr0` des jeweiligen Hosts. Physische Isolation wird
durch diese Änderung weder hergestellt noch behauptet.

## Konkrete Änderung

1. `/etc/mosquitto/conf.d/mqtt.conf` in CT 107: ausschließlich
   `listener 8883 192.168.40.172` entfernen. Alle übrigen Listener,
   Kennwort- und Clientzertifikatsanforderungen erhalten.
2. Mosquitto starten. Da Version 2.0.11 keinen hier nachgewiesenen reinen
   Konfigurationstest bietet, ist der kontrollierte Dienststart mit
   vorbereiteter Rücknahme die Prüfung durch den tatsächlichen Parser.
3. `/home/jay/.node-red/projects/nodered-managed/flows.json` in CT 105:
   ausschließlich `shcip` des bestehenden `shc-config` von `.4` auf `.231`
   ändern. Vorher und nachher JSON vergleichen; jede weitere Abweichung ablehnen.
4. Node-RED kontrolliert stoppen, Datei atomar ersetzen und starten.
   Projektgeheimnis, `flows_cred.json`, Berechtigungen und Eigentümer erhalten.

## Sicherung und Rücknahme

Der aktivierende Ablauf speichert Original und Kandidat unter
`/root/.local/jaylab/automation-<UTC-Zeit>-<Dienst>/` auf dem jeweiligen
Proxmox-Host, außerhalb des betroffenen Containers; Verzeichnis 0700,
Dateien 0600. Der genaue Pfad wird bei Aktivierung protokolliert.
Die bereits geprüfte Hostanmeldung und `pct exec` sind der Rückweg.
Vor dem Schreiben wird der Originalhash erneut verglichen; konkurrierende
Änderungen führen zum Abbruch. Bei Startfehler wird die Originaldatei
wiederhergestellt und Node-RED erneut gestartet bzw. Mosquitto gestoppt.

Manuelle Rücknahme über den zugehörigen Host: Dienst mit `pct exec ID --
systemctl stop DIENST` stoppen, gesichertes Original über `pct push ID
HOST-SICHERUNG ZIELPFAD` übertragen und bisherigen Dateieigentümer sowie
Modus wiederherstellen. Danach Node-RED starten; MQTT war zuvor fehlgeschlagen
und wird bei Rücknahme gestoppt belassen. Vor der Rücknahme den gegenwärtigen
Hash vergleichen, damit spätere Betreiberänderungen erhalten bleiben.

## Abnahme

| Quelle | Ziel | Erwartet | Stand vor Aktivierung |
| --- | --- | --- | --- |
| Verwaltungsrechner | Host-SSH und `pct exec` | Unverändert zugänglich | Geprüft |
| CT 107 | Mosquitto | Aktiv, TLS-Listener 8883 | Fehlgeschlagen |
| CT 105 | MQTT über TLS/Clientzertifikat/Kennwort | CONNECT/CONNACK, sofortiges DISCONNECT, keine Publikation | Offen |
| CT 105 | SHC `.231` | Information, Räume und Geräte lesbar | GET erfolgreich |
| CT 105 | Node-RED | Aktiv und bestehender SHC-Longpoll gestartet | SHC-Ziel noch falsch |
| Verwaltungsrechner | Lokale Repositoryprüfung | Bestanden | Nach Abschluß erneut prüfen |

Persistenz wird durch erneutes Lesen der geschriebenen Dateien geprüft;
ein zweiter Vorbereitungslauf muß keine weitere Änderung benötigen.
IPv6-Netzpfade werden nicht geändert; die funktionale Abnahme der Anbindung
erfolgt über das belegte IPv4-Ziel. Ein MQTT-Test ohne Zugangsdaten darf keine
Anmeldung erhalten.

## Abschluß

Beide Korrekturen sind aktiviert. Node-RED läuft mit SHC `.231`, Longpoll und
GET-Abfragen sind bestätigt; erneuter Vorbereitungslauf ohne weitere Änderung.
Mosquitto läuft. Bei der Abnahme wurde zusätzlich der TLS-Listener auf die
tatsächliche `.213` gebunden, weil der Container seinen eigenen Namen auf
Loopback auflöst. Die globale `bind_interface eth0`-Zeile wurde entfernt, damit
kein zusätzlicher Klartextlistener auf eth0 entsteht. Die abschließend
gemessenen Listener sind Loopback:1883 und Loopback/`.213`:8883.
Die persistente MQTT-Datei stimmt mit dem gesicherten Kandidaten überein.
MQTT-Anmeldung über SSH und Loopback ist erfolgreich, anonyme Anmeldung wird
abgewiesen. Die direkte TLS-Verbindung bleibt wegen abgelaufenem Clientzertifikat
und nicht passender Server-Vertrauenskette offen. Die vorgefundenen TLS-Prüfungen
wurden nicht abgeschaltet. Konkrete Ergebnisse und Sicherungspfade stehen
im [Zugangsbericht](AUTOMATISIERUNG-ZUGAENGE.md). Die lokale
InfluxDB-Anmeldung wird getrennt mit einem vom Betreiber in KeePass
bereitgestellten regulären Zugang geprüft. Die abgelehnte Token-Auslesung aus
der InfluxDB-Datenbank wird nicht ausgeführt.
