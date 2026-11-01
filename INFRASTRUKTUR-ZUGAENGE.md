# Prüfung der Infrastrukturzugänge

## Nachprüfung der Cisco-Kommandozeilenzugänge am 1. November 2026

Alle drei dokumentierten Switches nehmen SSH-Verbindungen auf Port 22 an und
melden `OpenSSH_7.3p1.RL`. Der Windows-SSH-Client scheitert mit seinen
Standardeinstellungen daran, daß die Switches nur `ssh-rsa` und `ssh-dss` als
Hostschlüsselverfahren anbieten. Mit der auf den einzelnen Aufruf begrenzten
Option `-o HostKeyAlgorithms=+ssh-rsa` gelingt die kryptographische Aushandlung
bei allen drei Geräten. Anschließend bricht die eingeschaltete strikte
Hostschlüsselprüfung ab, da die RSA-Hostschlüssel lokal nicht bekannt sind.

| Switch | Adresse | Beobachteter RSA-Fingerabdruck (SHA256) |
| --- | --- | --- |
| cisco16 | 192.168.10.1 | `b9TvBDJWG4osQgUD4Bu8lEhU8ZYu88U1HleH8wX6rxA` |
| cisco8 | 192.168.10.2 | `1pIlLyLFcttJeK78++lWb+PRg/wS65DczqV8kvERwyA` |
| cisco162 | 192.168.10.16 | `cuUaBFciMFvmgMpsRY5aqA6VSzkPiubnxU+BDKhUa3k` |

Diese Fingerabdrücke wurden über das Netz beobachtet und noch nicht unabhängig
über eine vertrauenswürdige Quelle bestätigt. Es wurde kein Hostschlüssel
übernommen. Benutzername, Anmeldeverfahren, Anmeldung und CLI-Berechtigungen
sind noch nicht bestätigt. `ajjay` war lediglich der für die Verbindungsprüfung
eingesetzte lokale Benutzername; die Prüfung endete vor der Benutzerauthentifizierung.

Nach unabhängigem Fingerabdruckabgleich kann die interaktive Anmeldung zum
Beispiel so erfolgen; `BENUTZER` ist durch den tatsächlichen Switch-Benutzer
zu ersetzen:

```powershell
ssh -o HostKeyAlgorithms=+ssh-rsa BENUTZER@192.168.10.1
```

Die Option wurde nur für die Diagnoseaufrufe gesetzt, nicht global konfiguriert.
Es wurden keine Kennwörter gesendet und keine Switch-Konfigurationen geändert.

Stand: 31. Oktober 2026. Prüfung vom Windows-Arbeitsplatz im Verwaltungsnetz
192.168.10.241, Gateway 192.168.10.3. Grundlage sind die Hosts-, DHCP- und
Deployment-Dateien dieses Repositories sowie aktive, lesende Verbindungsprüfungen.

## Ergebnis

Die meisten dokumentierten Verwaltungsdienste sind erreichbar. Ein belastbarer
administrativer Zugang für Analyse und Deployment ist noch nicht nachgewiesen.
Erreichbare TCP-Ports allein bestätigen weder Anmeldung noch Berechtigungen.
Der verbundene ERPNext-Zugang konnte dagegen authentifiziert werden.

Es wurden keine Infrastrukturkonfigurationen geändert, keine Dienste neu gestartet,
keine Deployments ausgeführt und keine neuen SSH-Hostschlüssel gespeichert.

## Erreichbarkeit und Anmeldung

| Komponente | Adresse | Prüfung | Ergebnis / Hindernis |
| --- | --- | --- | --- |
| Firewall | 192.168.10.3 | SSH 22 | Erreichbar; Hostschlüssel lokal unbekannt, Anmeldung daher nicht geprüft |
| DNS / DHCP / Stubby | 192.168.10.6 | SSH 22, DNS TCP 53 | Beide erreichbar; SSH-Hostschlüssel unbekannt; DNS-Abfragen für mehrere interne Namen erfolgreich |
| Proxmox | 192.168.10.4 | SSH 22, HTTPS 8006 | Erreichbar; bekannter ED25519-Hostschlüssel stimmt; Anmeldung mit vorhandenem Schlüssel als root, codex und ajjay abgewiesen |
| Proxmox-Serviceverwaltung | 192.168.10.5 | TCP 22, 443 | 22 erreichbar; 443 ohne erfolgreichen Verbindungsaufbau; Anmeldung nicht geprüft |
| Proxmox2 und weitere Instanzen | 192.168.10.7–12 | SSH 22, HTTPS 8006 | Alle Ports erreichbar; SSH-Hostschlüssel unbekannt |
| Proxmox3 | 192.168.10.13 | SSH 22, HTTPS 8006 | Erreichbar; SSH-Hostschlüssel unbekannt |
| Proxmox3-Serviceverwaltung | 192.168.10.14 | TCP 22, 443 | 22 erreichbar; 443 ohne erfolgreichen Verbindungsaufbau; Anmeldung nicht geprüft |
| Proxmox Backup Server | 192.168.10.15 | SSH 22, HTTPS 8007 | Erreichbar; SSH-Hostschlüssel unbekannt; API ohne Anmeldung antwortet mit 401 |
| Cisco16 / Cisco8 / Cisco162 | 192.168.10.1 / .2 / .16 | TCP 22, 443 | Alle erreichbar; Anmeldung und Rechte nicht geprüft |
| Synstation | 192.168.50.1 | TCP 22, 5001 | 5001 erreichbar; 22 ohne erfolgreichen Verbindungsaufbau; Anmeldung nicht geprüft |
| WAF laut Hosts-Datei | 192.168.2.4 | TCP 22, 443 | Kein erfolgreicher Verbindungsaufbau |
| Web laut Hosts-Datei | 192.168.3.6 | TCP 22, 443 | Kein erfolgreicher Verbindungsaufbau |
| Cloudflared | 192.168.40.241 | SSH 22 | Erreichbar; Hostschlüssel unbekannt |
| ERPNext laut Hosts-Datei | 192.168.40.125 | TCP 22, HTTP 80, HTTPS 443 | 22 und 80 erreichbar; HTTP über erpnext.jaylab.local antwortet mit 200; 443 ohne erfolgreichen Verbindungsaufbau; SSH-Hostschlüssel unbekannt |
| ERPNext-Verbindung im Assistenten | Konfigurierter Connector | GET frappe.auth.get_logged_user | Authentifizierte Antwort erfolgreich; damit ist kein SSH- oder Betriebssystemzugang bestätigt; Zielgleichheit mit .125 nicht gesondert geprüft |
| K3s-4 | 192.168.40.226 | TCP 22, 443, 6443 | Kein erfolgreicher Verbindungsaufbau; DNS-Auflösung erfolgreich |
| K3s-2 / K3s-3 | Name aus DHCP-Datei | DNS | k3s-2.jaylab.local und k3s-3.jaylab.local nicht auflösbar |
| Netbox / Authentik | Alias auf 192.168.40.226 | DNS, HTTPS 443 | Namen auflösbar; HTTPS-Zeitüberschreitung |
| Paperless | 192.168.40.221 | TCP 22, 80, 443 | Alle erreichbar; SSH-Hostschlüssel unbekannt; Web-Anmeldung nicht geprüft |

TCP-Verbindungen wurden mit etwa drei Sekunden Wartezeit geprüft; erfolglose
Verbindungen unterscheiden nicht zwischen abgeschaltetem Dienst, Filterung,
Routingproblem und veralteter Zieladresse. DNS TCP 53 ist kein vollständiger
Funktionstest von DNS, DHCP oder Stubby. IPv6 wurde nicht aktiv geprüft.

## Lokale Zugangsvoraussetzungen

- OpenSSH, SCP, Bash und kubectl sind vorhanden. Helm, Ansible, Terraform und
  OpenTofu wurden im aktuellen PATH nicht gefunden.
- Kein SSH-Agent erreichbar. Eine lokale SSH-Konfigurationsdatei ist im
  aufgelisteten SSH-Verzeichnis nicht vorhanden.
- Vorhandener Schlüssel: `%USERPROFILE%\.ssh\id_ed25519_proxmox_codex`.
  Der Schlüssel wurde bei der Proxmox-Anmeldung angeboten und abgewiesen.
  Ursache und vorgesehener Benutzer müssen serverseitig geklärt werden.
- Die wirksame Standardkonfiguration für `ssh proxmox` verwendet den Benutzer
  `ajjay` und Standardschlüsselnamen; den vorhandenen besonderen Schlüssel muß
  man ausdrücklich mit `-i` angeben.
- `%USERPROFILE%\.kube\config` ist nicht vorhanden. Ein Kubernetes-Zugang
  und seine Rechte konnten deshalb nicht geprüft werden.
- HTTPS mit regulärer Zertifikatsprüfung scheitert bei Proxmox, PBS und dem
  getesteten Switch 192.168.10.1 mit curl-Fehler 60. Die genaue Ursache in der
  Zertifikatskette wurde nicht bestimmt. Nur zur Diagnose ohne Anmeldedaten
  wurde einmal mit deaktivierter Zertifikatsprüfung getestet: Proxmox und PBS
  antworten mit HTTP 401; der Switch liefert HTTP 302, anschließend curl-Fehler 56.
  Daraus folgt kein freigegebener Zugang mit deaktivierter Zertifikatsprüfung.

## Voraussetzungen für den nächsten Analyse- oder Deploymentauftrag

1. Den vorgesehenen SSH-Benutzer und die Berechtigung des vorhandenen öffentlichen
   Schlüssels auf Proxmox über einen bereits vertrauenswürdigen Zugang prüfen.
   Danach Anmeldung und die tatsächlich benötigten administrativen Rechte lesend
   nachweisen. Der private Schlüssel bleibt auf dem Arbeitsplatz.
2. Die Hostschlüssel der übrigen Komponenten über Konsole oder eine andere
   vertrauenswürdige Quelle abgleichen. Erst danach in `known_hosts` hinterlegen
   und Benutzeranmeldung sowie Rechte prüfen.
3. Für API-Zugriffe vertrauenswürdige Zertifikatsketten und geeignete
   Zugangsdaten bereitstellen; anschließend API-Rechte prüfen. Die 401-Antworten
   belegen nur, daß die API erreichbar ist.
4. Bei K3s Zieladressen, Betriebszustand und Netzfreigaben klären; danach eine
   geeignete Kubeconfig bereitstellen und Clusterzugang sowie Rechte prüfen.
5. Bei WAF, Web und Synstation klären, ob die dokumentierten Adressen und
   Verwaltungsports noch gelten. Die WAF-Dokumentation ist widersprüchlich:
   `hosts` nennt 192.168.2.4, ein aktiver DHCP-Eintrag nennt 192.168.20.241.
6. Vor Verwendung der Synchronisationsskripte Schlüsselpfade und Fehlerbehandlung
   berichtigen. DNS verwendet `/home/vscode/.ssh/id_ed25519`, Stubby
   `/home/jay/.ssh/id_rsa`, nftables `~/.ssh/id_ed25519`. Diese entsprechen nicht
   dem hier vorhandenen besonderen Schlüssel. Die Skripte brechen bei fehlgeschlagenen
   Einzelbefehlen nicht zuverlässig ab und enthalten direkte Dienstneustarts;
   die nftables-Skripte löschen außerdem die Conntrack-Tabelle. Sie wurden nicht
   ausgeführt.

## Geprüfter SSH-Aufruf

Dieser Aufruf verwendet den vorhandenen Schlüssel ausdrücklich, erlaubt keine
interaktive Anmeldung und übernimmt keine unbekannten Hostschlüssel. Er scheitert
derzeit an der Benutzeranmeldung:

```powershell
ssh -i "$env:USERPROFILE/.ssh/id_ed25519_proxmox_codex" -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5 root@proxmox.jaylab.local 'id; hostname'
```
