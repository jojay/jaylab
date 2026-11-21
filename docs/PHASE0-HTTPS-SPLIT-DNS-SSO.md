# Phase 0: bestätigter Bestand und Pilotvorbereitung

Stand: 15. November 2026. Grundlage: [Übergabe](UEBERGABE-HTTPS-SPLIT-DNS-SSO.md)
und [Implementierungsplan](Implementierungsplan-Heimnetz-HTTPS-Split-DNS-SSO.md).
Der beauftragte Beginn von Phase 0 ist durchgeführt; die vollständige Phase-0-
Abnahme bleibt wegen der unten genannten Restprüfungen offen. Die folgenden
Tabellen halten den Bestand **vor der Aktivierung** fest. Anschließend wurde
der [Pilot](PILOT-HTTPS-SPLIT-DNS.md) auf ausdrücklichen Fortsetzungsauftrag
aktiviert und geprüft: CT 131, `.10.18`, lokale Pilot-DNS-Einträge und nur
lokaler DNS am Arbeitsplatz. [Grafana](AENDERUNG-GRAFANA-HTTPS-2026-11-15.md)
läuft ebenfalls wieder; sein tatsächlich vorgefundenes System ist Ubuntu
24.04 / Grafana 12.4.2, nicht die alte Templatebeschreibung. Anschließend wurde
nur die [Grafana-Tunnelroute](AENDERUNG-GRAFANA-TUNNEL-2026-11-15.md) mit
aktivierter TLS-Prüfung auf Caddy umgestellt. Aktuelle Einzelbelege stehen
in den Änderungsberichten.

## Nachweise und Arbeitsstand

Der Git-Arbeitsbaum war vor Beginn sauber. Bestehende Dateien, Schlüssel,
Hostschlüsselbindungen, Kennwörter und Maschinenzugänge blieben erhalten.
Die WSL-Profile erzwingen weiterhin Hostschlüsselprüfung und Schlüsselanmeldung.
Die Sandbox sperrte zunächst WSL und Windows-Netzabfragen; die anschließend
genehmigten lesenden Aufrufe funktionierten. Das war kein Geräteausfall.

Rohbelege und lokale Prüfwerkzeuge liegen ausschließlich unter
`.local/phase0-20261115/`. Die wichtigsten Dateien sind `host1.txt`,
`host3.txt`, `router.json`, `dns-active.txt`, `dnsqueries.jsonl`, `fritz.json`,
`fritz-cable-extra.json`, `tunnel.json` und `tunnel-guest.txt`.
`placement.txt` enthält zusätzlich die ausführliche Bridge-Aufnahme.
Die Sicherung `dns-before.tar.gz` enthält Hauptdatei, Include-Verzeichnis,
Default-Datei, drei `/home`-Includes und Dienstdefinition; das Archiv ist lesbar.
Das ist eine Konfigurationssicherung auf dem Arbeitsplatz, kein vollständiger
LXC-Restore-Nachweis und kein Ersatz für eine getrennte, geschützte Sicherung.

## Aktuell gemessen

| Bestandteil | Bestätigter Zustand | Grenze des Nachweises |
| --- | --- | --- |
| Drei Proxmox-Knoten | `proxmox` `.10.4`, `proxmox2` `.10.7`, `proxmox3` `.10.13`; PVE 9.2.21, Kernel 7.0.14-24-pve; root-SSH bzw. Hostaufnahme erfolgreich | Kein frischer `root@pam`-Weblogin |
| DNS | CT 101 auf proxmox2, dnsmasq 2.91 aktiv; IPv4 je Segment `.6`, entsprechende ULA; Stubby inaktiv | Verteilte Konfiguration ersetzt keinen DHCP-/RA-Mitschnitt auf jedem Client |
| Router | CT 103 auf proxmox2; IPv4-/IPv6-Forwarding aktiv; IPv4-Default über `192.168.20.5` | Keine IPv6-Default-Route im Router-LXC; Isolation nicht nachgewiesen |
| Routerhost | Sechs aktive NICs `enp1s0` bis `enp6s0`, jeweils Bridges `vmbr0` bis `vmbr5`; Hostforwarding aus | Externe Gegenports und Vertrauensgrenzen bleiben offen |
| DNS-Verteilung | Admin, General, IoT und Media nennen lokale `.6` plus `1.1.1.1`; Gäste `8.8.8.8` plus `1.1.1.1`; DNS-RA-Lifetime 0, RDNSS/DHCPv6 `[fe80::]` | Kein allgemeines Split-DNS gewährleistet; Familienoptionen nicht aus anderen Tags ableiten |
| Arbeitsplatz | Ethernet `192.168.10.241/24`, DNS `192.168.10.6`, `8.8.8.8`; keine IPv6-Adresse und kein IPv6-DNS an diesem Adapter gemeldet | Kein IPv6-Pilotnachweis; Browser-DoH/VPN/Proxy noch nicht geprüft |
| Fritzboxen | Zertifikatsgebundene Anmeldung an 6670 Cable und 7530 AX erfolgreich, jeweils FRITZ!OS 8.25; DHCPv4 laut LANHostConfigManagement aus | WLAN-Gastnetz, RA-Verteilung und Meshpfade nicht vollständig aufgenommen |
| Öffentliche IPv4 | Cable meldet `109.91.25.25`, WAN `Connected` | Bestätigt die Anschlußadresse, keinen externen Negativtest |
| Portzuordnungen | Cable-TR-064 meldet 0 IPv4-PortMapping-Einträge | Keine Aussage über IPv6-Freigaben, Exposed Host oder jede andere Freigabeart |
| IPv6 | DNS-LXC lernt `2a02:908:c250:9d00::/64` auf fünf Schnittstellen und RA-Defaults vom selben Link-Local-Router; statischer Default zusätzlich zum Router-LXC | Delegation des gesamten `/59`, Hin-/Rückrouten und Filter noch nicht bewiesen; `/59` bleibt Betreiberangabe |
| Bestehende Filter | Router-LXC weiterhin IPv4-INPUT/FORWARD mit unbedingtem Accept, kein ip6-/inet-Filter in diesem Netzraum | Proxmox-Filter und externe Pfade gesondert; keine Behauptung vollständiger Netzoffenheit |
| VLAN-Bestand | `proxmox` enthält bereits `bridge-vlan-aware yes` und `bridge-vids 2-4094` in beiden Bridge-Konfigurationen | Altbestand, keine hier eingeführten VLANs; tatsächliche Segmentisolation ungeklärt |
| Domain | NS `athena.ns.cloudflare.com`, `venkat.ns.cloudflare.com`; CAA ohne Daten | Kein vollständiger Cloudflare-Zonenexport |
| Split-DNS | Grafana und ERPNext intern weiterhin Cloudflare-Antworten; öffentlich A/AAAA/HTTPS vorhanden | Pilot noch nicht aktiviert |
| Neue Namen | `login.jaylab.org`, `pve.jaylab.org`, `https-pilot.jaylab.org` öffentlich NXDOMAIN für A/AAAA/HTTPS; Zufallsname ebenfalls NXDOMAIN | Kein vollständiger Ausschluß aller Wildcards oder Dashboardrouten |
| Cloudflared | CT 124 auf proxmox2, `192.168.40.241/32`, nur Link-Local-IPv6 am Gastinterface, Version 2026.10.0-1; Token-Fernverwaltung aktiv | Letzte geladene Journal-Konfiguration vom 12. November ist kein heutiger Dashboardexport |
| Grafana | CT 102 auf proxmox weiterhin gestoppt, `onboot: 0`, 8-GiB-Rootfs; DNS `.40.248` | Backendversion, Host-Header, Zertifikatskette und Anmeldung nicht abnehmbar |
| ERPNext | CT 106 auf proxmox, `192.168.40.106/32`; Frappe 16.56.0 und ERPNext 16.55.0 aus installiertem Code | Vollständige Liste aller API-Verbraucher fehlt |
| ERPNext-Anmeldung | Bestehender MCP-API-Zugang erfolgreich; Social Login Key `office_365` aktiviert, Basis `https://login.microsoftonline.com`, Callback `/api/method/frappe.integrations.oauth2_logins.login_via_office365` | Konfiguration und API geprüft, kein frischer interaktiver Entra-Login |
| Caddy/Authentik | Kein so benannter Gast im aktuellen Clusterbestand; Authentik-Neuinstallation laut Betreiber; alter Alias weiterhin nach `.40.226` | Keine Behauptung, daß auf keinem anderen System eine Binärdatei existiert |

Abgekürzte IPv4-Adressen beginnen mit `192.168`. Die Bridge-/LXC-Zuordnung
wurde mit der tatsächlichen Konfiguration verglichen; passende Nummern allein
wurden nicht als Netzpfadnachweis verwendet.

Die zuletzt geladenen Tunnelrouten bleiben unverändert:

| Name | Origin | Besonderheit |
| --- | --- | --- |
| `dfderp.jaylab.org` | `http://erpnext.jaylab.local` | HTTP zum Origin |
| `dfderp-last.jaylab.org` | `http://erpnext-last.jaylab.local` | Altinstanz |
| `grafana.jaylab.org` | `https://grafana.jaylab.local:3443` | `noTLSVerify: true` |
| `paperless.jaylab.org` | `https://paperless.jaylab.local` | `noTLSVerify: true` |
| `proxmox.jaylab.org` | `https://proxmox.jaylab.local:8006` | `noTLSVerify: true` |

Der öffentliche Proxmox-Pfad ist vor einer späteren SSO-/Tunnelumstellung
gezielt zu behandeln. Ein neuer interner Name beseitigt ihn nicht.

## Ressourcen und noch nicht vergebene Kandidaten

| Wert | proxmox | proxmox3 |
| --- | --- | --- |
| RAM verfügbar, Momentaufnahme | etwa 56,3 GiB | etwa 21,1 GiB |
| Lokaler Thinpool | etwa 147,4 GiB, 47,91 % belegt | etwa 758,3 GiB, 21,86 % belegt |
| Rolle im Entwurf | Caddy und später Authentik | PBS-Gast VM 115, getrennt vom Anwendungshost |

`proxmox/local-lvm` ist für die Startgrößen 8 GiB und 32 GiB ausreichend.
Thinpool-Belegung ist keine Garantie für spätere Vollbelegung aller vorhandenen
virtuellen Platten. Wachstum und Sicherungen vor Anlage erneut prüfen.
PBS `proxmox-backupserver` meldete aktiv und etwa 63,9 GiB frei. Vorhandene
Backupjobs verwenden feste Gastlisten; neue IDs wären nicht automatisch erfaßt.
PBS liegt auf einem anderen Host, aber im selben Cluster.

Die Storage-Abfrage löste erneut iSCSI-Loginversuche mit Fehlern/Zeitüberschreitungen
aus; außerdem wurde `synstation-backup` als nicht online gemeldet. Keine
Storage-Konfiguration wurde geändert. Diesen Weg nicht für den Pilot voraussetzen.

Vorschläge: **CT 131 / `192.168.10.18` für Caddy**, später **VM 132 /
`192.168.10.19` für Authentik**, beide auf proxmox. IDs fehlen im Clusterbestand
und in den Gastkonfigurationen; die IPs fehlen in den aufgenommenen Gastnetzen,
Hosts, Reservierungen und Leases und liegen außerhalb des Admin-DHCP-Bereichs
`.100`–`.240`. PTR-Anfragen ergaben NXDOMAIN. Es erfolgte keine Reservierung
oder Vergabe. ARP-Duplikatprüfung fehlt (`arping` auf proxmox nicht vorhanden);
statisch konfigurierte, schlafende Geräte sind damit nicht ausgeschlossen.
Die Admin-Bridge ist nur ein Vorschlag für den datenlosen Pilot, keine endgültige
Platzierung öffentlich erreichbarer Proxy-/IdP-Dienste zwischen Vertrauenszonen.

## Bereits bestandene Vorbereitung

- DNS-Syntax gegen den vollständigen, in ein temporäres Verzeichnis kopierten
  Haupt-/Include-Bestand einschließlich des neuen Pilot-Includes erfolgreich.
  Absolute `/home`-Includes wurden auf die Kopien umgebogen. Vorher-/Nachher-
  SHA256 aller produktiven Quelldateien stimmen überein (`dns-full-syntax.json`).
- Der konkrete Pilotname wurde auf Loopback-Port 1053 mit der installierten
  dnsmasq-Version geprüft: A auf den Kandidaten, AAAA/HTTPS NODATA, ERPNext
  weiter öffentlich auflösbar, jeweils UDP und TCP: 8/8 bestanden.
  Kein DHCP/RA, Testprozeß beendet (`pilot-dns-isolated.json`).
- Rückweg zum DNS-LXC über Host-IP `.10.7`, gebundenen Hostschlüssel und
  `pct exec 101` bestätigt; Zugang zum Pilothost über `.10.4` ebenfalls.
  Dieser Weg ist vom DNS-Dienst, nicht vom gemeinsamen Routing/Switch abhängig.
- Caddy v2.11.9 mit Cloudflare-Modul v0.2.4 lokal gebaut; Modulnachweis
  erfolgreich. `caddy validate` besteht für Staging und Produktion mit
  künstlichem Tokenplatzhalter und getrennten lokalen Prüfverzeichnissen.
  Buildmetadaten, SHA256 und Kandidaten liegen im
  [Pilotpaket](PILOT-HTTPS-SPLIT-DNS.md); lokale Belege in `build.log`,
  `build/build-modules.txt` und `caddy-validation.log`. Echte DNS-01-Ausstellung
  und Dienststart im neuen LXC gehören zur späteren Abnahme.

## Restprüfungen nach Abhängigkeit

Vor Pilotaktivierung: Adreßkonflikte ausschließen und Zuordnung festschreiben,
Debian-Template samt Herkunft/Prüfsumme festlegen, neuen Gastzugang und
Sicherung einrichten. Der zunächst fehlende Cloudflare-DNS-Zugang wurde
anschließend auf ausdrücklichen Auftrag über die neu installierte `cf`-CLI
als eigener Token `caddy-dns-jaylab` eingerichtet und geprüft: `Zone:Read`
und `DNS:Edit` nur für `jaylab.org`. Belege, geschützte Ablage und Rückweg:
[Caddy-DNS-Zugang](CLOUDFLARE-CADDY-DNS-ZUGANG.md). Sein Wert wurde nicht
ausgegeben; die Übertragung in den künftigen Gast bleibt Teil der Aktivierung.

Vor fachlicher Grafana-Abnahme: Wiederanlauf, Backend-TLS, `root_url`, Host-
Header und lokaler Notzugang. Vor breiter DNS-/SSO-/Tunnelumstellung zusätzlich:
Fritzbox-IPv6-Freigaben, tatsächliche `/59`-Delegation, externe IPv4-/IPv6-
Negativtests, unabhängiger Netz-Wiederherstellungszugang, frischer Proxmox-
Weblogin, vollständige API-Verbraucher, Cloudflare-Dashboard-/Access-Export
und Client-RA-/DoH-/VPN-Prüfung. Diese Punkte verhindern nicht die lokale
Vorbereitung des datenlosen Piloten.
