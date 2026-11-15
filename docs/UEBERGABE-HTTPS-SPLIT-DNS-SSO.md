# Übergabe für den Beginn der Umsetzung

Stand: 15. November 2026. Diese Übergabe hält die beschlossenen Planungswerte
und die vor der Umsetzung noch zu prüfenden Voraussetzungen fest.

Fortsetzung: Die [aktuelle Phase-0-Aufnahme](PHASE0-HTTPS-SPLIT-DNS-SSO.md)
bestätigt den Bestand und dokumentiert Restprüfungen. Der
[datenlose HTTPS-Pilot](PILOT-HTTPS-SPLIT-DNS.md) läuft als CT 131 unter
`192.168.10.18`. DNS-01, Browser-HTTPS, Split-DNS, Gastneustart und isolierter
PBS-Restore sind abgenommen. [Grafana](AENDERUNG-GRAFANA-HTTPS-2026-11-15.md)
wurde anschließend wieder gestartet und über Caddy angebunden; bestehender
Admin-Login und zwei Dashboards wurden geprüft. Auch die
[Grafana-Tunnelroute](AENDERUNG-GRAFANA-TUNNEL-2026-11-15.md) zeigt inzwischen
mit TLS-Prüfung auf Caddy; Mobilfunkabnahme steht noch aus. Die neue
[Authentik-Basis](AENDERUNG-AUTHENTIK-BASIS-2026-11-15.md) läuft als VM 132
unter `.10.19`; `login.jaylab.org` führt lokal über Caddy. Anmeldung von `jay`
bestätigt, TOTP eingerichtet. Native Datenbank- und vollständige isolierte
VM-Wiederherstellung sind geprüft. Der [Grafana-SSO-Pilot](AENDERUNG-GRAFANA-SSO-2026-11-15.md)
ist aktiviert; die funktionierende SSO-Anmeldung wurde vom Betreiber am
15. November 2026 bestätigt. Auch die lokale Anmeldung mit `admin` ohne SSO
ist vom Betreiber bestätigt. Ergänzende Rollen-, Sitzungs- und Ausfalltests
bleiben offen.
Die [drei Proxmox-Knoten](AENDERUNG-PROXMOX-HTTPS-SSO-2026-11-15.md) sind
unter `pve`, `pve2` und `pve3.jaylab.org` auf Port 8006 mit eigenen
ACME-Zertifikaten und dem erneuerten Authentik-Realm angebunden. Zertifikate
und SSO sind auf allen drei Knoten vom Betreiber bestätigt. Bestehende
Benutzer/ACLs blieben unverändert. Gastkonsole, PAM-Notzugang und Ausfalltests
bleiben offen, ebenso der Abgleich der alten öffentlichen Proxmox-Tunnelroute.
Die ursprünglichen Entscheidungen bleiben erhalten.

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
- **Authentik:** als vollständige Neuinstallation in VM 132 umgesetzt,
  Server und Worker 2026.8.5 mit PostgreSQL 16.16. Eigene Linux-VM,
  versionierte Compose-Konfiguration mit Image-Digests, 2 vCPU, 4 GiB RAM
  und 32 GiB virtuelle Platte. Eingebetteter Outpost, kein Docker-Socket.
- **DNS:** vorhandenen dnsmasq-LXC weiterverwenden; keinen neuen Unbound-Gast
  installieren. Für den Pilotnamen `address` und `local` zusammen prüfen,
  damit AAAA-/HTTPS-Abfragen keinen öffentlichen Nebenpfad ergeben.
- **Platzierung:** `proxmox` oder `proxmox3` nach aktueller Bestandsprüfung,
  nicht der Routerhost `proxmox2`. Caddy ist inzwischen CT 131 auf `proxmox`,
  `.10.18`; Authentik ist VM 132 auf demselben Host, `.10.19`.
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
- Cloudflare-DNS-API-Zugang inzwischen eingerichtet: `caddy-dns-jaylab`
  mit `Zone:Read` und `DNS:Edit` ausschließlich für `jaylab.org`.
  [Anlage, Prüfung und geschützte Ablage](CLOUDFLARE-CADDY-DNS-ZUGANG.md)
  sind dokumentiert. Bei der Pilotaktivierung sicher in den neuen Gast
  übertragen worden. Geheimnisse nicht in Chat, Git oder Prozeßargumenten ablegen.
- Aktuelle Ressourcen, freie Gast-IDs, LAN-Adressen, Netzpfade und
  Sicherungsziele prüfen. Die bisherigen Ressourcenwerte sind nur eine
  Momentaufnahme. Der Storage-Abfrage zufolge gab es IPv6-iSCSI-Zeitüberschreitungen.
- Grafana CT 102 war anfangs gestoppt; inzwischen läuft der Dienst mit
  erneuertem Backend-Zertifikat und geprüftem Admin-/Dashboardzugang.
  Autostart ist gesetzt. Der erste SSO-Pilot erhält das vorhandene
  Viewer-Konto und den lokalen Administrator; automatische Anmeldung bleibt aus.
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
