# Änderung: bestehende Grafana-Tunnelroute auf Caddy

## Ergebnis und Umfang

Phase 3 des beauftragten Plans, ausschließlich `grafana.jaylab.org` im
bestehenden Tunnel `dfderp`. Lokale Grafana-Anmeldung als `admin`, Dashboards,
Frontend-TLS und Backend-TLS sind geprüft. Der tatsächliche Connector CT 124
erreicht Caddy `.10.18:443` mit normaler Zertifikatsprüfung und HTTP 200.

## Konkreter Unterschied

| Feld der Grafana-Ingressregel | Vorher | Nachher |
| --- | --- | --- |
| `service` | `https://grafana.jaylab.local:3443` | `https://192.168.10.18:443` |
| `originRequest.noTLSVerify` | `true` | `false` |
| `originRequest.originServerName` | nicht gesetzt | `grafana.jaylab.org` |
| `originRequest.httpHostHeader` | nicht gesetzt | `grafana.jaylab.org` |

Alle übrigen Ingressregeln und globalen Tunneloptionen werden vollständig
übernommen. Keine Änderung an Cloudflare Access, öffentlichen DNS-Einträgen,
ERPNext, Paperless, Proxmox oder dem zweiten Tunnel. Verwaltungsprofil der
vorhandenen `cf`-CLI verwenden; der neue DNS-Token bekommt keine weiteren Rechte.

## Sicherung und Rückweg

Vorher vollständige API-Konfiguration und exakten Rücknahme-Body in der
zugriffsgeschützten lokalen Ablage
`.local/changes/2026-11-15-grafana/tunnel/` sichern. Die fernverwaltete
Konfiguration ist maßgeblich, nicht eine alte lokale `config.yml`.
Vor PUT Versionsstand erneut vergleichen; bei zwischenzeitlicher Änderung
abbrechen. Kandidat zuerst mit CLI-Dry-run prüfen, nach PUT erneut lesen
und sämtliche Felder vergleichen. Bei fehlerhafter Übernahme oder gestörter
Grafana-Erreichbarkeit genau den gesicherten Body zurückspielen und prüfen.

CLI: `cf tunnels config update 1ba7cb00-a20f-45dc-9d81-3ca1a7a6d5ae
--body @ROLLBACK-BODY.json`; Account über vorhandene Profil-/Umgebungsauswahl.
Keinen Token in Befehlsargumente schreiben. Der bisherige Backend-Endpunkt
bleibt für den Rückweg funktionsfähig.

## Abnahme

Geladene Connector-Version und Grafana-Ziel prüfen, öffentlichen Cloudflare-
Pfad getrennt vom LAN-Pfad testen, bestehende Access-Schutzwirkung erhalten.
Eine Mobilfunkprüfung durch den Betreiber bleibt ein eigener Nachweis.
Allgemeine DHCP-/RA-Verteilung und netzweite DNS-Erzwingung gehören nicht
zu diesem einzelnen Routenschritt.

## Ergebnis

Am 15. November 2026 mit der vorhandenen PowerShell-CLI `cf` aktiviert:
Version 47 → 48 im Tunnel `dfderp`, ID
`1ba7cb00-a20f-45dc-9d81-3ca1a7a6d5ae`. CLI-Dry-run bestanden, vollständiger
Rücklesevergleich entspricht exakt dem Kandidaten; alle sechs Ingressregeln
erhalten, nur die vier vorgesehenen Grafana-Felder abweichend.
Das bereinigte Journal des laufenden CT 124 bestätigt das neue Ziel und
`noTLSVerify: false` tatsächlich geladen.

Der getrennt erzwungene öffentliche Cloudflare-Pfad wurde vor und nach der
Änderung geprüft: gültiges TLS, HTTP 302 zum bisherigen
`jaylaborg.cloudflareaccess.com`. Damit bleibt der anonyme Zugang durch Access
geschützt. Das ist kein angemeldeter Fernzugriffstest. Die Mobilfunkprüfung
des Betreibers ist angefordert; allgemeine DNS-Verteilung bleibt unverändert.

Belege: geschützte Ablage `tunnel/before.json`, `rollback-body.json`,
`candidate-body.json`, `after.json`, `activation.json`; daneben
`tunnel-loaded.json` und `tunnel-public-before/after.json` in der genannten
lokalen Änderungsablage. Diese vollständigen API-Exporte gehören nicht nach Git.
