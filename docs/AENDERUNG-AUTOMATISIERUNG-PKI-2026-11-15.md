# Aktiviert: Ersatz der entfallenen Automatisierungs-CA

## Ergebnis und Umfang

Betreiberangabe vom 15. November 2026: Die bisherige CA-Infrastruktur existiert
nicht mehr. Die bereits freigegebenen MQTT-/SHC-Adreßkorrekturen sind aktiv;
der Betreiber hat anschließend ausdrücklich Zertifikate und API-Lesezugang
zur Aktivierung freigegeben. Diese sind inzwischen aktiviert und geprüft.
Er betrifft ausschließlich CT 105 (Node-RED) und CT 107 (MQTT).

## Istzustand und Abhängigkeiten

Der Node-RED-Webserver hat ein seit Februar 2024 abgelaufenes Zertifikat.
Das MQTT-Clientzertifikat ist seit Januar 2024 abgelaufen. Das noch bis
Januar 2028 gültige MQTT-Serverzertifikat ist selbstsigniert; die normale
Serverprüfung mit der im Flow gespeicherten CA schlägt fehl. Die bestehende
Flow-Einstellung `verifyservercert=false` ist kein geeigneter Abnahmenachweis.

Die Hostzugänge mit strikter SSH-Schlüsselprüfung und `pct exec` funktionieren
unabhängig von diesen TLS-Diensten. MQTT-Kennwortanmeldung über SSH/Loopback
und SHC-API sind bereits geprüft. Auch die OIDC-Abhängigkeit wurde untersucht:
`authentik.jaylab.local` zeigt auf `.226`; TCP 443 ist aus CT 105 nicht erreichbar.
Ein gültiges Node-RED-Zertifikat allein stellt daher die Webanmeldung noch nicht
wieder her. Ein Wiederaufbau von Authentik gehört nicht zu diesem Kandidaten.

## Konkreter, lokal vorbereiteter Kandidat

Unter `.local/pki/automation-2026/` liegen:

- Eine neue `Jaylab Automation CA 2026`, RSA 3072, Pfadlänge 0, gültig bis
  November 2031. Ihr Schlüssel liegt ausschließlich lokal in verschlüsselter
  `automation-ca.pfx`; das zufällige PFX-Kennwort ist Windows-DPAPI-gebunden.
  Das Verzeichnis ist per ACL auf das aktuelle Windows-Konto und SYSTEM begrenzt.
- `nodered-server.pem` für `nodered.jaylab.local`, `localhost`, `.223` und
  `127.0.0.1`, mit Server-EKU, gültig bis 15. November 2027.
- `mqtt-client.pem` für `system.jaylab.local`, mit Client-EKU, gültig bis
  15. November 2027.
- Das öffentliche, über den geprüften SSH-Zugang gelesene bestehende
  MQTT-Serverzertifikat als künftiger expliziter Vertrauensanker.

Beide neuen Dienstzertifikate wurden aus signaturgeprüften CSRs mit den
bereits vorhandenen Dienstschlüsseln erzeugt. Kein privater Dienstschlüssel
hat CT 105 verlassen. OpenSSL bestätigt CA-Kette, Servername und jeweilige
Verwendungsart. Das Wiederöffnen der CA-PFX mit dem DPAPI-Kennwort wurde geprüft.
Kein Zertifikat wurde in einen globalen Zertifikatsspeicher installiert.

| Kandidat | SHA256 des öffentlichen Zertifikats |
| --- | --- |
| Neue CA | `34B200933E0914B4F407B38515ACC14F8252FCBA46C1990810098AEEAE5A4ECD` |
| Node-RED-Server | `4BE4F854CCC9E28EC2520BBAA48578F4444BA0A9FE3DEC364CDDD9DB6DCE4214` |
| MQTT-Client | `9D1FCFB605AD71387A9EDF6910427DFC0E2DF5AEF8707625B62284C0DB078324` |
| Bestehender MQTT-Server | `C6BDE2AFFEB8EC4212AAC2F1CCEA594311C5253D7B94E847E63208FEEF9438CD` |

## Vorgesehene Aktivierung

1. Aktuelle Dateien auf dem jeweiligen Host außerhalb der LXC sichern und
   Hashes gegen gleichzeitige Änderungen prüfen.
2. In CT 107 die neue öffentliche Client-CA an
   `/etc/mosquitto/ca_certificates/ca.crt` anhängen. Bisherige CA erhalten,
   damit andere bestehende Clients ihre Vertrauensbasis behalten.
   Mosquitto kontrolliert neu starten und Dienstzustand prüfen.
3. In CT 105 ausschließlich den MQTT-Clientzertifikatseintrag im verschlüsselten
   Projektspeicher ersetzen; Schlüssel und MQTT-Kennwort erhalten. Für die
   Serverprüfung das bestehende, über SSH abgeglichene Brokerzertifikat in den
   TLS-Vertrauenssatz aufnehmen und `verifyservercert=true` einstellen.
4. Das tatsächlich geladene `/home/jay/.node-red/node-cert.pem` durch den neuen
   Serverzertifikatskandidaten ersetzen. Vorhandenen privaten Schlüssel und
   Dateirechte erhalten. Node-RED kontrolliert neu starten.
5. Keine DNS-, Router-, Firewall-, Bridge- oder Betriebssystem-Vertrauensspeicher
   ändern. Die neue CA muß nicht allgemein auf Arbeitsplatzrechnern installiert
   werden, um einen fest gebundenen API-Prüfweg zu benutzen.

## Sicherung und Rücknahme

Originale auf den geprüften Hosts unter `/root/.local/jaylab/` mit 0700/0600
sichern. Verschlüsselte Flowzugänge nicht ins Repository oder in die Ausgabe
übernehmen. Rücknahme: Node-RED/Mosquitto stoppen, ausschließlich die gesicherten
betroffenen Dateien mit Eigentümer und Modus zurückspielen und Dienste starten.
Bei zwischenzeitlichen Betreiberänderungen anhand der Hashes abbrechen.
Der bestehende Hostzugang bleibt der von den Anwendungen unabhängige Rückweg.
Die neue CA-PFX benötigt zusätzlich eine Sicherung durch den Betreiber;
DPAPI-Wiederherstellbarkeit auf einem anderen Rechner ist nicht nachgewiesen.

## Abnahme

| Quelle | Ziel | Erwartet |
| --- | --- | --- |
| CT 105 | MQTT `.213:8883` | Normale Serverprüfung und gültiges Clientzertifikat, CONNECT erfolgreich |
| CT 105 | MQTT `.213:8883` ohne Clientzertifikat | Abgewiesen |
| SSH/Loopback | MQTT ohne Kennwort | Abgewiesen |
| CT 105 | Node-RED HTTPS | Name, Zeit und neue CA-Kette gültig |
| CT 105 | SHC | Bestehender Longpoll und GET weiterhin erfolgreich |
| Verwaltungsrechner | Beide SSH-Hostprofile | Unverändert zugänglich |

Eine authentifizierte Node-RED-Editor-API-Abfrage benötigt zusätzlich einen
erreichbaren Anmeldedienst oder einen gesondert freigegebenen unabhängigen
API-Lesezugang. Dafür ist zusätzlich ein nicht aktivierter Kandidat vorbereitet:
`nodered-read-token.js` unter dem obigen geschützten lokalen Kandidatenpfad.
Er verwendet die in der installierten Node-RED-Version nachgewiesene
`adminAuth.tokens`-Schnittstelle, einen zufälligen 256-Bit-Bearertoken und
ausschließlich `permissions: 'read'`. Im Zielmodul steht nur SHA256; der Token
liegt lokal DPAPI-geschützt in `nodered-read-token.clixml`. Der Zugang läuft
nach einem Jahr ab. Das Modul ist syntaktisch geprüft, aber nicht eingebunden.

Falls zusätzlich freigegeben: vor der Einbindung prüfen, daß kein bestehender
`adminAuth.tokens`-Handler überschrieben wird; Modul unter
`/home/jay/.node-red/jaylab-read-token.js` ablegen und am Ende von `settings.js`
gezielt `module.exports.adminAuth.tokens = require('./jaylab-read-token.js');`
ergänzen. Die OIDC-Konfiguration bleibt bestehen. Für die Abnahme über
SSH/Loopback `/flows` lesen, Antwort nur zählen, und einen Schreibzugriff
mit leerem Beleg auf `/flows` auf 403 prüfen. Anonyme bzw. falsche Tokens
müssen abgewiesen werden. Rücknahme ist die gezielte Entfernung dieser
Einbindung und des Moduls; ein Neustart widerruft den Zugang.

## Abschluß und Abnahmebelege

Aktivierung abgeschlossen. Bei der Serverprüfung kollidierten alte CA und
Brokerzertifikat mit gleichem Betreff. Der endgültige MQTT-Server-Vertrauenssatz
in CT 105 enthält deshalb ausschließlich das über SSH abgeglichene
Brokerzertifikat; die bisherigen Client-CAs im Broker bleiben erhalten.

| Prüfung | Gemessen |
| --- | --- |
| MQTT mit voller Serverprüfung, Clientzertifikat und Kennwort | Verbunden |
| MQTT ohne Clientzertifikat | Keine CONNACK-Verbindung |
| MQTT ohne Kennwort | Abgewiesen, Code 5 |
| Node-RED GET `/flows` mit neuem Token und voller TLS-Prüfung | HTTP 200, 142 Elemente |
| Node-RED anonym und falscher Token | Jeweils HTTP 401 |
| Node-RED Schreibzugriff mit Lesetoken | HTTP 401, Flows unverändert |
| SHC | GET erfolgreich; etablierter Longpoll des laufenden Node-RED-Prozesses |
| Persistente Dateien, Eigentümer und Modi | Fünf Dateien CT 105 und eine Datei CT 107 stimmen mit endgültigen Kandidaten überein |

Der installierte Node-RED-Code liefert bei fehlenden Schreibrechten HTTP 401
statt des zunächst erwarteten 403. Der Schreibtest enthielt außerdem eine
ungültige API-Version, die vor jeder Laufzeitänderung zurückgewiesen würde.
Es wurde kein Flow deployt, um die Schreibsperre zu prüfen.

Sicherungspfade auf den jeweiligen Proxmox-Hosts, Verzeichnis 0700, Dateien 0600:

| Host | Verzeichnis | Umfang |
| --- | --- | --- |
| proxmox3 | `/root/.local/jaylab/pki-20261115T105200Z-mqtt/` | Broker-Client-CA, Original/Kandidat/Manifest |
| proxmox | `/root/.local/jaylab/pki-20261115T105227Z-nodered/` | Fünf Node-RED-Dateien, Originale/Kandidaten/Manifest |
| proxmox | `/root/.local/jaylab/pki-20261115T105601Z-mqtt-trust/` | Abschließende Begrenzung des MQTT-Server-Vertrauenssatzes |

Die endgültigen Dateien wurden mit den Manifesten erneut abgeglichen. Bei
vollständiger Rücknahme die Node-RED-Stände in umgekehrter Reihenfolge
zurücknehmen; der älteste Node-RED-PKI-Stand enthält noch die zuvor
erfolgreiche SHC-Adreßkorrektur. Vorher gegen aktuelle Hashes prüfen.

Wiederholbare Abnahme:

```powershell
pwsh -NoProfile -File scripts/Test-JaylabNodeRed.ps1
pwsh -NoProfile -File scripts/Test-JaylabAutomation.ps1 -Service mqtt-tls
pwsh -NoProfile -File scripts/Test-JaylabAutomation.ps1 -Service shc
```

Der reguläre InfluxDB-Zugang aus KeePass war bei der letzten Dateiprüfung noch
nicht hinterlegt. Das Ziel ist deshalb insgesamt noch nicht abgeschlossen.
