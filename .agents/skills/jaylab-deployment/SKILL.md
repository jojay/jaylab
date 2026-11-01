---
name: jaylab-deployment
description: "Bereitet überprüfbare Deployments, Rücknahme und Wiederherstellung für Jaylab-Netzdienste und Proxmox/LXC vor und führt beauftragte Änderungen aus."
---

# Deployment und Wiederherstellung

Lies [Betrieb](../../../docs/BETRIEB.md), die betroffene Ziel-ID und bei
mehreren Netzabhängigkeiten die [Architektur](../../../docs/ARCHITEKTUR.md).
Für Änderungen mit Betriebswirkung die
[Änderungsvorlage](../../../docs/vorlagen/AENDERUNG.md) konkret ausfüllen.
Keine routinemäßige zusätzliche Erlaubnis einführen, wenn die tatsächliche
Aktivierung bereits im aktuellen Auftrag liegt. Ein Analyse- oder
Workspace-Auftrag beauftragt dagegen keine produktive Änderung.

## Vorhandener Altbestand

`synch*.sh` überschreiben direkt Dateien, starten Dienste neu und setzen feste
Schlüsselpfade voraus; nftables-Skripte löschen zusätzlich Conntrack. Diese
Skripte und `nftables-failsafe*.nft` sind weder geprüfter Rollout noch Rückweg.
Auch die Proxmox-Distupgrade-Notiz bestätigt keine Eignung eines Upgrades.

Bereite Kandidaten, vollständige Includes und Syntaxprüfungen mit der tatsächlich
installierten Version vor. Geheimnisse nicht in Befehlszeilen, Git oder Berichte
übernehmen. Änderungen auf das betroffene Gerät und die benötigten Dienste begrenzen.

## Plattformabhängige Voraussetzungen

- **nftables / Routing:** Zuständigkeit von Host, Container und Proxmox-Firewall
  klären. Vorherzustand sichern, unabhängige Konsole prüfen, getesteten Rücklauf
  vorbereiten. Nicht über denselben geänderten Pfad auf Wiederherstellung vertrauen.
- **dnsmasq / Stubby:** Listener und komplette Includes prüfen; DNS-, DHCP- und
  RA-Auswirkungen getrennt abnehmen. Reload-Fähigkeiten der installierten Version
  belegen, statt willkürlich zwischen Reload und Neustart zu wechseln.
- **Proxmox / LXC:** Storage, Mounts, Startabhängigkeiten, Backupumfang und
  Wiederherstellbarkeit prüfen. Snapshots nicht als einzige Sicherung behandeln;
  keine pauschale Privilegierung und keinen Host-Neustart ohne konkreten Bedarf.
- **Cisco / Fritz:** Modellgerechte Aktivierung und Persistenz ermitteln; laufende
  und gespeicherte Konfiguration unterscheiden. Einen Rücklauf durch Neustart
  nicht ohne Prüfung von gespeichertem Zustand und Ausfallwirkung annehmen.

Nach Aktivierung Verwaltung, Nutzfunktionen und die betroffenen erlaubten und
verbotenen Verbindungen von echten Quellen einschließlich IPv6 prüfen. Erst nach
erfolgreicher Abnahme einen vorbereiteten Rücklauf aufheben. Bei Fehlschlag
zurücknehmen und Zustand prüfen, statt unverändert mehrfach zu deployen.

Z07 verlangt auch einen erneuten Lauf ohne unbeabsichtigte Änderung und
nachgewiesene Persistenz. Z02 verlangt eine isolierte Wiederherstellung; dabei
doppelte DHCP-/RA-Server aus dem produktiven Netz fernhalten. Das Ergebnis ist
ein nachvollziehbarer Konfigurationsstand mit Abnahme, Rückweg und Restbefunden.
