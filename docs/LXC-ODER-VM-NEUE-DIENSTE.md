# LXC oder VM für die neuen Netzdienste

Bewertung vom 15. November 2026 zum
[HTTPS-/Split-DNS-/SSO-Plan](Implementierungsplan-Heimnetz-HTTPS-Split-DNS-SSO.md).
Grundlage sind die Herstellerunterlagen und lesende Prüfungen der drei
Proxmox-Hosts. Es wurden keine Gäste angelegt und keine Privilegien,
Netzregeln oder laufenden Dienste umgestellt.

## Empfehlung für Jaylab

| Anwendung | Empfohlene Betriebsform | Begründung |
| --- | --- | --- |
| Caddy einschließlich Cloudflare-DNS-Modul | Eigener **unprivilegierter LXC**, Caddy nativ als systemd-Dienst | Kleine eigenständige Linux-Anwendung; Docker ist hierfür nicht nötig |
| Authentik-Server, Worker und PostgreSQL | Zusammen in einer **eigenen Linux-VM**, mit versionierter offizieller Compose-Konfiguration | Zentraler Anmeldedienst mit hohem Schutzbedarf; eigener Gastkernel und weniger Abhängigkeiten von verschachteltem Containerbetrieb |
| Eingebetteter Authentik-Outpost | In der Authentik-Installation | Zunächst kein weiterer Gast und kein allgemeiner Docker-Socket-Zugriff nötig |
| Lokales DNS | Vorhandenen dnsmasq-LXC behalten | Split-DNS wurde mit dnsmasq 2.91 isoliert geprüft; dafür ist kein neuer Unbound-Gast erforderlich |

Für bestehende Grafana-, ERPNext-, MQTT- und Zigbee2MQTT-Gäste folgt daraus
kein Auftrag zur Neuinstallation oder Migration. Diese Bewertung betrifft
die neu bereitzustellenden Komponenten des Plans.

Die Proxmox-LXC sind Systemcontainer. Docker-Container innerhalb eines LXC
sind eine zusätzliche Schicht. Ein unprivilegierter LXC ist dabei nicht
dasselbe wie ein rootlos betriebener Docker-Daemon.

## Warum die Entscheidung je Anwendung unterschiedlich ausfällt

### Caddy: unprivilegierter LXC ist die zweckmäßige Ausgangswahl

Caddy wird nativ als Linux-Systemdienst angeboten. Für DNS-01 mit Cloudflare
muß der Build das zusätzliche DNS-Modul enthalten; das normale Paket allein
enthält nur Standardmodule. Der Build-/Aktualisierungsweg und die Prüfung
mit `caddy list-modules` gehören deshalb zur Bereitstellung.
[Caddy-Installationswege](https://caddyserver.com/docs/install).

Mein Vorschlag ist ein eigener Debian-LXC mit `unprivileged: 1`, zunächst
1 CPU-Kern, 1 GiB RAM und 8 GiB verwaltetem Root-Dateisystem. Das sind
Planungswerte, keine gemessene Mindestanforderung. Caddy läuft als eigener
Dienstbenutzer; Konfiguration, persistenter Zertifikatsspeicher und
DNS-API-Zugang werden gezielt gesichert. Zusätzliche Datenvolumes bei Bedarf
als von Proxmox verwaltete Volumes planen.

Docker, Host-Docker-Socket und Geräteweiterreichung sind hierfür nicht
vorgesehen. Zusätzliche LXC-Features nicht aus einem alten Template übernehmen.
Die tatsächlich verwendete systemd-Unit samt ihren Namespace- und
Schutzoptionen im Pilot prüfen. Falls dafür ein Feature nötig ist, seinen
Umfang begründen und die Unit erneut testen; nicht pauschal AppArmor oder
die Dienstabsicherung abschalten.

Der Proxy verarbeitet auch Anfragen aus dem Tunnel und besitzt wertvolle
Zertifikats-/DNS-Zugänge. Ein LXC ist deshalb kein Grund, Backend- oder
Netzrechte großzügig zu vergeben. Wer für diesen Dienst ausdrücklich dieselbe
Kerneltrennung wie beim IdP verlangt, kann Caddy ebenfalls in einer kleinen
VM betreiben. Für den hier vorgesehenen einzelnen nativen Dienst halte ich
den unprivilegierten LXC jedoch für die angemessene Ausgangswahl.

### Authentik: eigene VM ist meine Empfehlung, keine Herstellerpflicht

Authentik dokumentiert unter anderem Docker Compose für kleine produktive
Installationen. Die Dokumentation verlangt dafür nicht ausdrücklich eine
Proxmox-VM. Meine VM-Empfehlung folgt aus der Rolle als zentraler IdP und dem
Betrieb des Compose-Stacks auf Proxmox.
[Authentik Compose](https://docs.goauthentik.io/install-config/install/docker-compose/).

Server, Worker und PostgreSQL zunächst gemeinsam in einer dedizierten VM
betreiben. Keine fremden Anwendungen in diesen Docker-Host aufnehmen. Als
Ausgangspunkt die bereits geplanten 2 vCPU und 4 GiB RAM beibehalten und
etwa 32 GiB virtuelle Platte mit Überwachung des freien Platzes vorsehen.
Wachstum von Datenbank, Images und Aktualisierungen berücksichtigen. Ein
separater Datenbankgast würde für diesen Heimnetzstart weitere
Netz-/Sicherungsabhängigkeiten schaffen und ist zunächst nicht nötig.

Die VM erhält ein eigenes Gastbetriebssystem samt Kernel, Updates und
QEMU-Gastagent. Docker-Netze und Anwendungsvolumes liegen innerhalb des
Gasts. Dadurch muß die Proxmox-LXC-Sicherheitskonfiguration für diesen
Compose-Stack nicht angepaßt werden. Der Gastagent unterstützt den Betrieb,
ersetzt aber keine konsistente PostgreSQL-Sicherung.

### Docker im unprivilegierten LXC: möglich, aber nicht meine erste Wahl

LXC teilen den Hostkernel; unprivilegierte Container bilden ihre Root-UID auf
eine unprivilegierte Host-UID ab. Proxmox nennt für hohe Isolation und
Live-Migration weiterhin QEMU-VMs als geeigneten Ort verschachtelter
Anwendungscontainer. Auch die auf den installierten PVE-9.2.21-Hosts
vorliegenden Unterlagen enthalten diese Einordnung.
[Proxmox-Containerdokumentation, offizieller Quellbestand](https://github.com/proxmox/pve-docs/blob/master/pct.adoc).

Bei einem Docker-LXC wären insbesondere Nesting, `keyctl`, AppArmor,
UID-Abbildung und der tatsächlich benutzte Storage-Treiber bzw. Snapshotter
zu prüfen. Proxmox beschreibt `keyctl` für Docker in unprivilegierten
Containern; Nesting erweitert die Sicht auf `procfs`/`sysfs`. Nicht alle
Features sind für jeden nativen Dienst nötig.
[Proxmox-Featuredefinitionen](https://github.com/proxmox/pve-container/blob/master/src/PVE/LXC/Config.pm),
[Docker-Storagehinweise](https://docs.docker.com/engine/storage/drivers/overlayfs-driver/).

Ich würde einen Authentik-LXC nur nach einem eigenen Pilot mit genau den
vorgesehenen PVE-, Docker-, Dateisystem- und Compose-Versionen freigeben:
Neuinstallation, Host-/Gastneustart, Aktualisierung und isolierter Restore
müssen bestehen. Ein privilegierter LXC oder `apparmor=unconfined` ist kein
pauschaler Ersatz für diesen Nachweis. Das Einsparen des VM-Gastkernels
gleicht für den zentralen Anmeldedienst die zusätzliche Betriebsebene aus
meiner Sicht hier nicht auf.

## Tatsächliche Ressourcen und Platzierung

Momentaufnahme unter der am 15. November laufenden Last:

| Host | CPU-Threads | RAM gesamt | RAM verfügbar | Freier `local-lvm`-Platz |
| --- | --- | --- | --- | --- |
| `proxmox` | 8 | 62,7 GiB | 56,3 GiB | 76,8 GiB |
| `proxmox2` | 4 | 15,5 GiB | 13,0 GiB | 113,9 GiB |
| `proxmox3` | 4 | 31,2 GiB | 21,1 GiB | 592,5 GiB |

Alle drei melden Proxmox VE 9.2.21. Eine kleine Authentik-VM ist damit
grundsätzlich auf `proxmox` oder `proxmox3` dimensionierbar. Die Werte sind
kein Reservierungs- oder Lastnachweis für zusätzlich gestartete, momentan
inaktive Gäste. Die endgültige Belegung vor einem Deployment erneut prüfen.

`proxmox2` würde ich wegen seiner Routerrolle nicht als bevorzugten Ort für
diese neuen Anwendungen wählen. Caddy und Authentik als getrennte Gäste
planen, damit ihre Dienst-/Gastwartung getrennt bleibt. Eine Verteilung auf
zwei Hosts ist möglich, stellt mit nur je einer Instanz jedoch keine
Hochverfügbarkeit her.

Die Speicherabfrage meldete wiederholt Zeitüberschreitungen beim Anmelden
an IPv6-iSCSI-Portalen des Synology-Ziels. Der gleichzeitig angezeigte
Status `active` des iSCSI-Storage ist daher kein hinreichender Beleg, daß
alle Zugriffswege funktionieren. Für die neuen Gäste vorerst den belegten
lokalen Speicher vorsehen und die iSCSI-Pfade gesondert untersuchen. An
Storage-Konfiguration oder Portalen wurde bei dieser Prüfung nichts geändert.

Eine Kontrollprobe an Paperless CT 116 fand kein `docker` im Suchpfad;
seine Konfiguration hat außerdem keine gesetzte `unprivileged: 1`-Option.
Dieser bestehende Gast ist deshalb kein Nachweis dafür, daß ein
unprivilegierter Authentik-/Docker-Stack bereits im Bestand erprobt ist.
Bestehende Gäste wurden nicht umgestellt.

## Sicherung und Abnahme gelten für beide Varianten

- Proxmox-Sicherungen für den vollständigen Gast und die benötigten Volumes
  einrichten. Inhalte gewöhnlicher LXC-Bind-Mounts sind nicht automatisch
  Bestandteil von `vzdump`; sie benötigen einen eigenen Sicherungsweg.
- Für Authentik zusätzlich einen nativen PostgreSQL-Dump sowie geschützte
  Konfiguration, `AUTHENTIK_SECRET_KEY` und erforderliche Dateien sichern.
  Ein laufender Snapshot allein belegt keine wiederherstellbare Datenbank.
  [Authentik-Sicherungsanleitung](https://docs.goauthentik.io/sys-mgmt/ops/backup-restore).
- Wiederherstellung mit passender Version in einem isolierten Gast testen,
  ohne produktiven DNS-Namen oder aktive IdP-Sitzungen umzuschalten.
- Caddy mit dem tatsächlich vorgesehenen Cloudflare-Modul, systemd-Profil,
  TLS-Erneuerungsweg und persistentem Zertifikatsspeicher abnehmen.
- Die Gastwahl ersetzt keine Netzsegmentierung. Feste LAN-Adressen,
  IPv4-/IPv6-Regeln und die Vorgabe ohne VLANs gelten unverändert.

Der Betreiber hat diese Empfehlung übernommen. Im Implementierungsplan sind
nun **Caddy als unprivilegierter LXC und Authentik als dedizierte Compose-VM**
festgelegt. Ein neuer Unbound-Gast oder eine pauschale Migration vorhandener
Anwendungen ist dafür nicht erforderlich.
