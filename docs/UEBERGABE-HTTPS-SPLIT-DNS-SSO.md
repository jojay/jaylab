# Übergabe für den Beginn der Umsetzung

Stand: 15. November 2026. Diese Übergabe hält die beschlossenen Planungswerte
und die vor der Umsetzung noch zu prüfenden Voraussetzungen fest.

## Verbindliche Grundlage

1. Repository-Regeln in `AGENTS.md` und die passenden Jaylab-Skills lesen.
2. Den [Implementierungsplan](Implementierungsplan-Heimnetz-HTTPS-Split-DNS-SSO.md)
   als Umsetzungsgrundlage verwenden. Die
   [Anwendbarkeitsprüfung](PRUEFUNG-HTTPS-SPLIT-DNS-SSO.md) ergänzt datierte
   Belege und offene Zugänge.
3. Bestehende Änderungen mit `git status --short` aufnehmen und erhalten.
   Die Unterlagen sind im gemeinsamen Workspace verfügbar; ein Git-Commit
   dieser Änderungen wurde nicht beauftragt. Messungen vor jedem Eingriff
   erneut bestätigen.

## Vom Betreiber übernommene Entscheidungen

- **Caddy:** eigener Debian-LXC, `unprivileged: 1`, nativ als systemd-Dienst,
  ohne Docker. Startwerte 1 CPU-Kern, 1 GiB RAM, 8 GiB verwaltetes Root-Dateisystem.
  Cloudflare-DNS-Modul über den versionierten Build-/Aktualisierungsweg erhalten.
- **Authentik:** bislang nicht installiert. Vollständige Neuinstallation
  mit Server, Worker und PostgreSQL gemeinsam in einer eigenen Linux-VM,
  offizielle versionierte Compose-Konfiguration. Startwerte 2 vCPU, 4 GiB RAM
  und etwa 32 GiB virtuelle Platte. Zunächst eingebetteter Outpost.
- **DNS:** vorhandenen dnsmasq-LXC weiterverwenden; keinen neuen Unbound-Gast
  installieren. Für den Pilotnamen `address` und `local` zusammen prüfen,
  damit AAAA-/HTTPS-Abfragen keinen öffentlichen Nebenpfad ergeben.
- **Platzierung:** `proxmox` oder `proxmox3` nach aktueller Bestandsprüfung,
  nicht der Routerhost `proxmox2`. IDs und LAN-Adressen noch nicht vergeben.
  Lokalen Gastspeicher mit gesonderter Sicherung vorsehen; iSCSI-Meldungen
  erst gesondert untersuchen.
- **Netz:** physische Trennung ohne VLANs beibehalten. Feste öffentliche IPv4
  `109.91.25.25` und statisches IPv6-Präfix `2a02:908:c250:9d00::/59` sind
  Betreiber-/Anbieterangaben. Tatsächliche Zuweisung, Delegation und Filterung
  vor Nutzung nachweisen. Keine öffentliche Anschlußadresse an eine VM vergeben.
- **Fernzugriff:** bestehender Cloudflare Tunnel bleibt Grundlage. Keine
  zusätzlichen direkten WAN-Webfreigaben ableiten. `login.jaylab.org`
  zunächst lokal; seine externe Veröffentlichung ist noch nicht beschlossen.

## Vor dem ersten Deployment klären

- Geprüfte SSH-Profile liegen lokal unter `.local/access/ssh_config_wsl`,
  Hostschlüsselbindungen unter `.local/access/known_hosts`. Zugang und Rechte
  neu prüfen; private Schlüssel an ihrem bisherigen Ort belassen.
  Vorgehen: [Zugangseinrichtung](ZUGANGSEINRICHTUNG.md).
- Einen passenden Cloudflare-DNS-API-Zugang mit `Zone:Read` und `DNS:Edit`
  für `jaylab.org` nachweisen. Der vorhandene Tunnel-Token ist kein Ersatz.
  Geheimnisse nicht in Chat, Git oder Prozeßargumenten ablegen.
- Aktuelle Ressourcen, freie Gast-IDs, LAN-Adressen, Netzpfade und
  Sicherungsziele prüfen. Die bisherigen Ressourcenwerte sind nur eine
  Momentaufnahme. Der Storage-Abfrage zufolge gab es IPv6-iSCSI-Zeitüberschreitungen.
- Grafana CT 102 war bei der letzten Prüfung gestoppt. Den tatsächlichen
  Backend-Zustand und seine TLS-Kette vor fachlicher Pilotabnahme prüfen.
  Für einen vorbereitenden Caddy-Test nur einen gesonderten Testendpunkt ohne
  Fachdaten verwenden; bestehende produktive Tunnelrouten erhalten.
- Cloudflared wird per Token fernverwaltet. Die zuletzt geladene Konfiguration
  enthielt auch `proxmox.jaylab.org`; dessen Schutz und spätere gezielte
  Umstellung sind ausdrücklich zu behandeln. Eine Änderung der alten lokalen
  `config.yml` ist kein nachgewiesenes Deployment dieser Tunnelrouten.

## Beginn und Grenzen

Mit Phase 0 beginnen: aktuelle Belege, Ressourcen-/Adresszuordnung,
konkrete Kandidaten, Sicherungen und Rückwege vorbereiten. Anschließend
Pilot-DNS, Caddy und TLS nach Plan abnehmen, bevor allgemeine DNS-Verteilung,
SSO oder Tunnelrouten umgestellt werden. Neue Gäste nicht mit einem
Neuaufbau des bestehenden Netzes verbinden.

Die vorhandenen Maschinenzugänge und Automatisierungsanbindungen erhalten.
Die InfluxDB-Anmeldung ist mangels bereitgestelltem regulärem Zugang noch
offen. Zigbee2MQTT ist wieder angebunden; ein positiver Live-Funknachweis
erfordert noch einen gezielt ausgelösten Sender. Diese offenen Prüfungen
sind keine Voraussetzung für die Vorbereitung der neuen Caddy-/Authentik-Gäste.

Vor Routing-, Bridge-, Firewall- oder Switch-Änderungen den vom betroffenen
Pfad unabhängigen Wiederherstellungszugang nachweisen. Nur die davon
abhängigen Schritte zurückstellen, falls dieser Nachweis fehlt.
