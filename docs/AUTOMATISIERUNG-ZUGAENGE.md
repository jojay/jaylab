# Node-RED, MQTT, InfluxDB und Bosch SHC

Gemessen und nach ausdrücklicher Freigabe berichtigt am 15. November 2026. Beide Proxmox-Hosts erlauben weiterhin
root-Anmeldung über die vorhandenen WSL-Profile mit strikter Hostschlüsselprüfung.
Die Container sind administrativ über `pct exec` zugänglich.

| Dienst | Ort | Aktuelle IPv4 | Nachweis |
| --- | --- | --- | --- |
| Node-RED | proxmox, CT 105 | 192.168.40.223 | Neue gültige TLS-Kette; API-GET 200, anonyme/falsche Tokens und Schreiben abgewiesen |
| MQTT | proxmox3, CT 107 | 192.168.40.213 | Volle TLS-Prüfung und Clientzertifikatsanmeldung erfolgreich; fehlendes Zertifikat/Kennwort abgewiesen |
| InfluxDB | proxmox3, CT 110 | 192.168.40.218 | v2.8.0, TCP 8086, lokale HTTP-Gesundheitsabfrage erfolgreich |
| Bosch SHC | physisches Gerät, DHCP-MAC 64:da:a0:10:b1:c9 | 192.168.40.231 | Bestehendes Clientzertifikat funktioniert; Information, Geräte, Räume, Dienste und Szenarien lesbar |

Alle drei LXC laufen, besitzen `onboot: 0` und hängen jeweils an `vmbr0` ihres
Hosts. Daraus folgt keine Aussage über physische Segmentisolation. Die LXC
besitzen auch globale und lokale IPv6-Adressen; die Dienst-API-Prüfungen wurden
über IPv4 ausgeführt. Eine gesonderte IPv6-Abnahme steht aus.

## Wiederholbarer Zugang

Die vorhandenen SSH-Dateien bleiben unter `.local/access/`, private Schlüssel
am bisherigen Ort in WSL. Beispiel vom Repository-Stamm:

```powershell
wsl.exe --exec ssh -F /mnt/c/Users/ajjay/Documents/GitHub/jaylab/.local/access/ssh_config_wsl jaylab-proxmox 'pct exec 105 -- hostname'
wsl.exe --exec ssh -F /mnt/c/Users/ajjay/Documents/GitHub/jaylab/.local/access/ssh_config_wsl jaylab-proxmox3 'pct exec 107 -- hostname'
wsl.exe --exec ssh -F /mnt/c/Users/ajjay/Documents/GitHub/jaylab/.local/access/ssh_config_wsl jaylab-proxmox3 'pct exec 110 -- hostname'
pwsh -NoProfile -File scripts/Test-JaylabAutomation.ps1 -Service shc
```

[Test-JaylabAutomation.ps1](../scripts/Test-JaylabAutomation.ps1) unterstützt
außerdem `nodered`, `mqtt`, `mqtt-tls` und `influxdb`. Es liest Dienstzustände,
Netzadressen bzw. die Gesundheitsantwort. Bei MQTT führt ein inaktiver Dienst
zu einem Fehlerstatus; auch ein aktiver Dienst bestätigt noch keine
Broker-Anmeldung. Bei InfluxDB bestätigt die Gesundheitsantwort keine
authentifizierte Datenabfrage.

`-Service mqtt-tls` führt zusätzlich CONNECT/DISCONNECT mit gültigem Zugang
sowie die beiden Negativtests ohne Clientzertifikat bzw. Kennwort aus.
Keine Publikation oder Subscription. Der Node-RED-API-Zugang wird gesondert mit
[Test-JaylabNodeRed.ps1](../scripts/Test-JaylabNodeRed.ps1) geprüft.

## SHC-Anbindung im Node-RED-LXC

Das aktive Projekt ist `nodered-managed` unter
`/home/jay/.node-red/projects/nodered-managed`. Es enthält einen `shc-config`
mit Zustand `PAIRED`, 38 `shc-device`-Nodes und zwei Szenarien-Nodes.
Installiert sind `node-red-contrib-bosch-shc` 0.3.30 und
`bosch-smart-home-bridge` 1.2.2 unter `/home/jay/node_modules/`.

Die zuvor gespeicherte SHC-Adresse `192.168.40.4` scheiterte mit `EHOSTUNREACH`.
DNS und DHCP-Lease für die bekannte Geräte-MAC belegen dagegen `.231`.
Mit den vorhandenen, im Speicher entschlüsselten Projektzugängen funktionieren
GET-Abfragen an `.231`: 15 Räume, 38 Geräte, 166 Gerätedienste und 8 Szenarien.
Es wurde kein neues Pairing vorgenommen und keine Szenarie ausgelöst.

Nach ausdrücklicher Freigabe wurde ausschließlich `shcip` auf `.231` geändert
und Node-RED kontrolliert neu gestartet. Das Journal bestätigt gestartete
Flows und den SHC-Longpoll an `.231`. Die GET-Prüfung bestand danach erneut;
ein zweiter Vorbereitungslauf meldete `changed=false`, Dienst aktiv.

[Test-JaylabShc.js](../scripts/Test-JaylabShc.js) wiederholt diese GET-Abfragen
über den A-Record von `shc.jaylab.local` mit ausdrücklicher IPv4-Auswahl. Es wird über SSH auf stdin an Node.js in CT 105
übergeben. Zertifikat, privater Schlüssel und Projektgeheimnis verlassen den
Container nicht. Die bestehende Bibliothek prüft die Bosch-CA; ihre eigene
Namensprüfung entspricht nicht der üblichen TLS-SAN-Prüfung. Es wurde keine
Zertifikatsprüfung abgeschaltet.

Der ungeänderte Node.js-Namenszugang wählt zuerst einen der vorhandenen
IPv6-Einträge (`fd4d:b7b5:44d3::d42d`, `2a02:908:c250:9d00::d42d`) und scheitert
im Test mit `EHOSTUNREACH`. `getent ahostsv4` liefert korrekt `.231`.
Der hier gespeicherte Test löst deshalb ausdrücklich den A-Record auf;
eine bloße Umstellung des laufenden Flows auf den DNS-Namen genügt derzeit nicht.

Die Node-RED-Webanmeldung verwendet OpenID Connect über
`authentik.jaylab.local`; eine neue Websitzung wurde nicht angemeldet.
Administrativer Datei- und Prozeßzugriff über den Host ist nachgewiesen.

Die erste Prüfung des damals hinterlegten Webzertifikats
`/home/jay/.node-red/node-cert.pem` ergab den Aussteller
`jaylab Intermediate CA`, CN und SAN `nodered.jaylab.local` sowie die Gültigkeit
vom 25. Februar 2023 bis zum 25. Februar 2024. Der lokale HTTPS-Aufruf an
`/auth/login` mit dieser Zertifikatsdatei als Vertrauensanker scheitert am
15. November 2026 ausdrücklich mit `certificate has expired` (curl 60).
Nach zusätzlicher Freigabe wurde es durch das neue Zertifikat der
`Jaylab Automation CA 2026` ersetzt. Die Kette und der Name `localhost`
wurden bei der API-Abnahme normal geprüft. Der neue unabhängige API-Lesetoken
liefert GET `/flows` mit HTTP 200 und 142 Flow-Elementen. Anonyme und falsche
Tokens sowie der Schreibversuch werden mit HTTP 401 abgewiesen; der Quellcode
der installierten Zugriffskontrolle bestätigt diesen Ablehnungsstatus.
Der Schreibtest verwendete zusätzlich die ungültige API-Version `v99`, die
selbst bei unerwarteter Berechtigung ein Deployment verhindert. Die Flows
blieben vor/nach dem Test identisch. OIDC bleibt konfiguriert, sein Dienst
unter `.226:443` ist derzeit nicht erreichbar; die Browseranmeldung ist damit
weiterhin offen. Der geprüfte API-Zugang benötigt Authentik nicht.

## MQTT-Befund und konkrete Korrektur

`/etc/mosquitto/conf.d/mqtt.conf` band ursprünglich an `localhost:1883`,
`mqtt.jaylab.local:8883` und zusätzlich `192.168.40.172:8883`.
Die letzte Adresse liegt nicht auf dem Container. Mosquitto 2.0.11 meldet
`Cannot assign requested address` und beendet den Start mit Status 1.
Die Konfiguration verlangt Kennwort und für TLS ein Clientzertifikat.
Die zugehörigen MQTT- und TLS-Zugänge sind im Node-RED-Projekt vorhanden.

Nach Freigabe wurde die veraltete Zeile entfernt und Mosquitto gestartet.
Die Abnahme zeigte zusätzlich, daß der eigene Name innerhalb des Containers
auf `127.0.1.1` zeigt. Deshalb wurde der externe TLS-Listener ausdrücklich an
`.213:8883` gebunden. Die alte globale Zeile `bind_interface eth0` erzeugte
einen zusätzlichen Klartextlistener auf eth0; sie wurde entfernt. Gemessen
sind anschließend nur Loopback auf 1883 sowie `127.0.1.1` und `.213` auf 8883.
Kennwort- und Clientzertifikatsanforderungen bleiben erhalten.

Mit den bestehenden Node-RED-MQTT-Anmeldedaten wurde über die beiden geprüften
SSH-Hostprofile und Broker-Loopback CONNECT/CONNACK mit Rückgabecode 0 geprüft.
Ohne Zugangsdaten kam Code 5 (abgewiesen). Danach DISCONNECT, keine
Publikation oder Subscription. Die Zugänge wurden ausschließlich im Speicher
zwischen den SSH-Verbindungen weitergereicht und nicht dauerhaft kopiert.
[Test-JaylabMqtt.py](../scripts/Test-JaylabMqtt.py) wiederholt diesen Weg in WSL:

```powershell
wsl.exe --exec python3 /mnt/c/Users/ajjay/Documents/GitHub/jaylab/scripts/Test-JaylabMqtt.py
```

Die erste direkte TLS-Abnahme scheiterte am seit Januar 2024 abgelaufenen
Clientzertifikat und einer unpassenden Server-Vertrauenskette. Nach
Betreiberbestätigung, daß die bisherige CA nicht mehr existiert, wurde der
[begrenzte PKI-Ersatz](AENDERUNG-AUTOMATISIERUNG-PKI-2026-11-15.md)
zusätzlich freigegeben und aktiviert. Das neue Clientzertifikat ist bis
15. November 2027 gültig; die neue öffentliche CA wurde an den
Broker-Vertrauenssatz angehängt. Das weiterhin gültige MQTT-Serverzertifikat
wird in Node-RED ausdrücklich als einziger Server-Vertrauensanker verwendet.
Ein gemeinsamer Satz mit der alten, gleichnamigen CA verursachte eine
OpenSSL-Auswahlkollision; die Begrenzung auf das über SSH abgeglichene
Serverzertifikat beseitigte sie. Der TLS-Konfigurationsnode wird vom
MQTT-Broker-Node und dem Zigbee2MQTT-Servernode für denselben Broker verwendet.
`verifyservercert=true` ist jetzt aktiv.

Die abschließende TLS-Prüfung bestand: gültiger Zugang verbunden,
ohne Clientzertifikat keine CONNACK-Verbindung, ohne Kennwort Rückgabecode 5.
Der laufende Node-RED-Prozeß besitzt eine etablierte Verbindung an `.213:8883`.
SHC-GET und Longpoll bleiben erfolgreich. Keine Broker-Schutzanforderung wurde
abgeschaltet.

Sicherungen liegen auf den Hosts außerhalb der betroffenen LXC:

| Host | Verzeichnis | Inhalt |
| --- | --- | --- |
| proxmox3 | `/root/.local/jaylab/automation-20261115T100433Z-mqtt/` | MQTT-Original vor erster Korrektur und Kandidat |
| proxmox3 | `/root/.local/jaylab/automation-20261115T100704Z-mqtt-bind/` | MQTT-Stand nach erstem Start und endgültiger Listener-Kandidat |
| proxmox | `/root/.local/jaylab/automation-20261115T100507Z-shc/` | Flow vor SHC-Korrektur und Kandidat |

Jedes Verzeichnis enthält `original` und `candidate`, Dateien 0600,
Verzeichnis 0700. Die endgültige MQTT-Datei wurde erneut mit ihrem Kandidaten
verglichen; der Inhalt stimmt überein. Rücknahme und Umfang stehen im
[Änderungsprotokoll](AENDERUNG-AUTOMATISIERUNG-2026-11-15.md).
Die zusätzlichen PKI-Sicherungen mit Dateimanifest, Originalen und Kandidaten
stehen im [PKI-Protokoll](AENDERUNG-AUTOMATISIERUNG-PKI-2026-11-15.md).

## InfluxDB und verbleibende Grenzen

Die lokale InfluxDB ist eingerichtet (`/api/v2/setup`: `allowed=false`).
Ein reguläres CLI-Zugangsprofil wurde an den geprüften üblichen Orten nicht
gefunden. API-Anmeldung, Organisationen und Buckets sind noch ungeprüft.
Die automatische Freigabeprüfung lehnte den Versuch ab, vorhandene Tokens
mit `influxd recovery auth list` aus einer temporären BoltDB-Kopie auszulesen.
Dieses Verfahren wurde nicht ausgeführt. Der Betreiber stellt stattdessen
einen regulären KeePass-Zugang bereit. Es wurden keine Benutzer oder Tokens angelegt.

Benötigt wird der Eintrag der lokalen Instanz
`http://influxdb.jaylab.local:8086`, mit Benutzername/Kennwort oder einem
vorhandenen API-Token. Lokale geschützte Eingabe:

```powershell
pwsh -NoProfile -File scripts/Set-JaylabCredential.ps1 -DeviceId influxdb
# Nur bei einem vorhandenen API-Token stattdessen:
pwsh -NoProfile -File scripts/Set-JaylabCredential.ps1 -DeviceId influxdb -PasswordOnly
```

Danach prüft [Test-JaylabInflux.ps1](../scripts/Test-JaylabInflux.ps1) den Zugang
über den fest gebundenen SSH-Host und HTTP ausschließlich auf Loopback in
CT 110. Datenbankdateien werden nicht gelesen. Benutzername/Kennwort werden
für die normale `/api/v2/signin`-Anmeldung verwendet; die Sitzung wird nach
den lesenden Organisations-/Bucket-Abfragen abgemeldet. Ein vorhandenes Token
wird ausschließlich für diese GET-Abfragen verwendet. Keine Geheimnisse auf
der Befehlszeile oder in der Ausgabe; die lokale Ablage ist Windows-DPAPI-gebunden.
Der Zugang war bei der letzten Dateiprüfung noch nicht hinterlegt.

Der aktive Node-RED-Influx-Node ist für Version 2.0 mit dem wirksamen Ziel
`https://westeurope-1.azure.cloud2.influxdata.com` konfiguriert. Die ebenfalls
vorhandenen Felder `127.0.0.1`, Port 8086 und Datenbank `shc` sind kein Nachweis
einer Verbindung zur lokalen CT-110-Instanz. Die Cloudanmeldung und tatsächliche
Dateneingänge wurden nicht geprüft.

Node-RED-API, MQTT und SHC sind angemeldet geprüft. Für den Abschluß des
Dienstzugangsziels fehlt der reguläre InfluxDB-Zugang. Die OIDC-Browseranmeldung
und eine externe Sicherung der neuen CA bleiben gesonderte Betriebspunkte.
