# Änderung: Grafana als fachlicher HTTPS-Pilot

## Ergebnis und Umfang

Fortsetzung des beauftragten Plans am 15. November 2026. CT 102 auf `proxmox`
wieder anlaufen lassen und über Caddy CT 131 unter
`https://grafana.jaylab.org/grafana/` anbinden. Vorhandene Dashboards, Konten,
Datenquellen, private Dienstschlüssel und Tunnelrouten erhalten.

## Istzustand und Abhängigkeiten

Rein lesende Prüfung des gestoppten Gastes: Ubuntu 24.04.4 LTS,
Grafana Enterprise 12.4.2; die alte Ubuntu-21.10-Beschreibung ist überholt.
Rootfs 45 Prozent belegt, rund 4,1 GiB frei. SQLite-Prüfung `quick_check`: ok;
acht Dashboards, zwei InfluxDB-Datenquellen, drei Benutzer.
Der DHCP-Eintrag mit MAC `92:2e:0b:ac:a6:07` und bestehender unbegrenzter Lease
ordnet Grafana `192.168.40.248` zu. Diese Adresse wird laut Konfigurationshinweis
auch in einer bestehenden Firewallregel verwendet und bleibt erhalten.

Backend: HTTPS Port 3443, Name `grafana.jaylab.local`, Unterpfad `/grafana`.
Das konfigurierte Zertifikat ist am 18. Februar 2024 abgelaufen. Die alte CA
existiert laut früherer Betreiberklärung nicht mehr; die heute bereits für
Automatisierungsdienste eingerichtete, DPAPI-geschützte CA steht bereit.
Generic OAuth verweist noch auf den nicht vorhandenen alten Authentik-Namen.
Lokale Anmeldung und bestehende Konten werden nicht zurückgesetzt.

## Konkrete Änderung

1. Vollständige PBS-Sicherung des gestoppten CT 102 und gesonderte Sicherung
   der betroffenen Originaldateien auf dem Host, Verzeichnis 0700.
2. Nur öffentlichen CSR aus dem vorhandenen privaten Grafana-Schlüssel
   erzeugen. Mit der bestehenden `Jaylab Automation CA 2026` ein neues
   Serverzertifikat für `grafana.jaylab.local` und `.40.248` ausstellen.
   CA-Schlüssel bleibt verschlüsselt am bisherigen Ort.
3. Neues Backend-Zertifikat als eigene Datei installieren; in `grafana.ini`
   nur `server.cert_file`, `server.domain` und `server.root_url` auf den
   neuen Zertifikatspfad und `https://grafana.jaylab.org/grafana/` ändern.
   Port 3443, HTTPS, Unterpfad und private Schlüssel bleiben erhalten.
4. Gast starten, tatsächliche Adresse bestätigen; bei abweichender Lease
   keine fremde DNS-/Firewallzuordnung ändern. Backend mit CA und richtigem
   TLS-Namen prüfen. Erst dann Caddy-Proxyroute mit ausdrücklichem
   CA-Vertrauen und `tls_server_name grafana.jaylab.local` ergänzen.
5. Browserzertifikat per DNS-01 beziehen. Nach HTTPS-Abnahme nur den
   gezielten Grafana-DNS-Include mit `address` und `local` aktivieren.
   Bestehende Tunnelroute in diesem Schritt nicht umstellen.

## Sicherung und Rücknahme

Hostzugang über `.10.4` und `pct exec`, DNS-Rückweg über `.10.7` und CT 101
sind geprüft. Keine bestehenden Bridges, Routen oder Firewallregeln ändern.
Bei Fehlern eigene Grafana-DNS-/Caddy-Ergänzungen entfernen und die geprüften
vorherigen Fassungen aktivieren. Nur die gesicherte `grafana.ini` zurückspielen;
alte Zertifikate und Schlüssel bleiben vorhanden. CT 102 wieder stoppen,
falls seine Abnahme scheitert. Keine Rücksicherung über fremde Gast-IDs.

## Abnahme und Grenzen

Getrennt prüfen: Backend-TLS, Frontend-TLS, Weiterleitungen und statische
Grafana-Dateien, lokaler DNS-Pfad sowie Anmeldung/Datenquellen. Eine angezeigte
Anmeldeseite ersetzt keinen Dashboard- oder SSO-Nachweis. Der bisherige
OAuth-Verweis wird erst bei der Authentik-Anbindung umgestellt.
Rohbelege: `.local/changes/2026-11-15-grafana/`.

## Ergebnis vom 15. November 2026

Aktiviert: Grafana CT 102 läuft wieder auf seiner bisherigen DHCP-Adresse
`192.168.40.248`. Caddy CT 131 bedient
`https://grafana.jaylab.org/grafana/` über `.10.18`. Das neue Backend-Zertifikat
liegt als `/etc/grafana/grafana-backend-2026.pem` vor; die alten Zertifikate,
Symlinks und privaten Schlüssel blieben erhalten. Nur die drei vorgesehenen
Serverfelder wurden geändert. Backend-TLS ist mit der bestehenden
Automatisierungs-CA und korrektem Namen geprüft; keine Prüfungsabschaltung
in Caddy. Das Backend-Zertifikat gilt bis 15. November 2027 und muß rechtzeitig
mit der vorhandenen geschützten CA erneuert werden; es wird nicht durch
Let’s Encrypt automatisch erneuert. SHA256 des Zertifikats:
`AF5495D78C03BA9BC6B2AF6D26C5E88B9406DD8824E3B1B75378EC9758788648`.

| Prüfung | Gemessen |
| --- | --- |
| Backend direkt aus CT 131 | HTTPS mit CA-/Namensprüfung, `/grafana/api/health`: Datenbank `ok`, Version 12.4.2 |
| Frontend vor DNS-Umschaltung | Windows `curl --resolve`, normales Systemvertrauen, HTTP 200, Ziel `.10.18` |
| Lokales DNS | A `.10.18`, AAAA/HTTPS NODATA; eigene Datei `91-jaylab-grafana.conf`; alle vorherigen Dateien unverändert |
| Frontend nach DNS-Umschaltung | Normale Windows-Auflösung, HTTP 200; Browser lädt Anmeldemaske ohne Zertifikatswarnung |
| Statische Dateien | Zwei CSS- und drei JavaScript-Dateien HTTP 200 über `.10.18` |
| Lokaler Notzugang | Betreiber meldete sich mit bestehendem Konto `admin` an; angemeldete Sitzung im Browser bestätigt |
| Dashboard Proxmox | Lädt Meßreihen und frische Einträge vom 15. November, etwa 16:13 Uhr; einzelne VM-Felder ohne Daten |
| Dashboard BSHC/Aqara | Luftdruck- und Tür-/Fensterverläufe sichtbar; einzelne Statistik-/Ventilfelder weiterhin „No data“ |
| Connectorpfad | CT 124 erreicht Caddy mit gültigem TLS und HTTP 200 |

Kein Kennwort zurückgesetzt, keine Datenquelle oder Dashboarddefinition
geändert. „No data“ einzelner Panels ist kein Nachweis eines TLS-/Proxyfehlers
und bleibt als fachlicher Restbefund bestehen. Die Datenquellen wurden nicht
neu konfiguriert. Generic OAuth zeigt weiterhin auf den alten, nicht vorhandenen
Authentik-Namen und wird erst in Phase 4 ersetzt.

Sicherung vor Änderung: PBS `ct/102/2026-11-15T15:05:26Z`.
Sicherungen nach Aktivierung: `ct/102/2026-11-15T15:11:17Z` und
`ct/131/2026-11-15T15:11:31Z`, jeweils vorhandener Namespace `containerbackup`.
Originaldateien zusätzlich auf `proxmox` unter
`/root/jaylab-grafana-20261115/originals/` (0700; Dateien 0600).
Die ursprünglichen Backupjobs für CT 102 blieben erhalten. Inzwischen ist
`onboot: 1` mit `startup: order=20,up=10` gesetzt; der Grafana-Dienst ist im
Gast aktiviert. Start aus dem gestoppten Zustand und fachliche Funktion sind
geprüft, ein vollständiger Host-Kaltstart noch nicht. Rücknahme dieser
Ergänzung: `pct set 102 --onboot 0 --delete startup` auf `proxmox`.

Die ursprüngliche IPv6-Autokonfiguration des alten Grafana-Gastes blieb
unverändert. Beim Start wurden globale und ULA-Adressen beobachtet; deren
externe Filterwirkung ist nicht als nachgewiesen zu behandeln. Der Caddy-
Pilot selbst bleibt IPv4-only. Der anschließende, getrennt geprüfte
[Tunnel-Routenschritt](AENDERUNG-GRAFANA-TUNNEL-2026-11-15.md) ist dort dokumentiert.

Herstellergrundlagen: [Caddy HTTPS-Upstream und Vertrauensanker](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy#the-http-transport),
[Grafana-Serverkonfiguration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/).
