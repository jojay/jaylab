# Pilot: HTTPS und Split-DNS ohne Fachdaten

Stand: 15. November 2026. Aktivierte Änderung zu Z05/Z07/Z09 nach
[Betrieb](BETRIEB.md), gestützt auf die [Phase-0-Aufnahme](PHASE0-HTTPS-SPLIT-DNS-SSO.md).
**Aktiviert und technisch abgenommen.** Der anschließende Auftrag „setze den
Plan fort“ umfaßt die Aktivierung. CT 131 läuft unter `.10.18`; DNS-01,
Windows-/Browser-HTTPS, Split-DNS, Neustart und isolierter PBS-Restore sind
geprüft. Die [konkrete Änderung](AENDERUNG-HTTPS-PILOT-2026-11-15.md) und der
anschließende [Grafana-Pilot](AENDERUNG-GRAFANA-HTTPS-2026-11-15.md) halten
Umfang und Rückwege fest. Der anschließende
[Grafana-Tunnelschritt](AENDERUNG-GRAFANA-TUNNEL-2026-11-15.md) ist gesondert
dokumentiert; Authentik und SSO folgen später.

## Umfang und Kandidaten

Ein eigener Testname `https-pilot.jaylab.org` liefert nur einen festen Text.
Er erhält keine Tunnelroute und keinen öffentlichen Web-A-/AAAA-Eintrag.
DNS-01 setzt nur die für die Zertifikatsprüfung erforderlichen TXT-Daten.
Ein Zertifikat ist keine Freigabe für öffentliche Erreichbarkeit.

| Ressource | Aktivierter Wert |
| --- | --- |
| Host / Storage | proxmox / local-lvm; gesonderte Sicherung auf PBS auf proxmox3 |
| Gast | CT 131, Debian 13, unprivileged, 1 CPU, 1024 MiB RAM, 8 GiB Rootfs; nativ ohne Nesting |
| Netz | `vmbr0` → `enp1s0`, IPv4 `192.168.10.18/24`, Gateway `.10.3`, DNS `.10.6`; MAC `BC:24:11:1F:D0:AF` |
| Pilotclient | Arbeitsplatz `.10.241`, Ethernet Index 19, DNS nur `.10.6`; vorher `.10.6` und `8.8.8.8`; kein IPv6 am Adapter |
| Dienst | nativer Caddy, Dienstbenutzer `caddy`, TCP 443 an genau der bestätigten Pilot-IPv4; Admin-API nur Loopback |
| IPv6 | Kein AAAA, kein öffentlicher oder automatisch abgeleiteter IPv6-Listener; später getrennte Abnahme |

Der Gast bekommt keine zweite Netzkarte, keine VLAN-Tags, kein Docker,
kein Nesting, keine Geräteweiterreichung und keine pauschal gelockerte
AppArmor-Konfiguration. Die bestehende Hostbridge wird nicht verändert.
Die externe Port-/Zonenzuordnung ist offen; der Pilot enthält deshalb keine
Fachdaten und wird nicht als Nachweis einer Segmentisolation verwendet.

Dateien im [Pilotverzeichnis](../pilot/https/):

- [Caddyfile](../pilot/https/Caddyfile): expliziter ACME-Issuer mit DNS-01,
  öffentlicher Challenge-Resolver, fester Testtext, getrennt vorgebbarer Speicher.
- [Umgebungsvorlage](../pilot/https/pilot.env.example): zunächst Staging;
  [Produktion](../pilot/https/pilot-production.env.example) mit eigenem
  Verzeichnis. Keine Tokens enthalten.
- [systemd-Unit](../pilot/https/caddy-pilot.service): eigene Unit ohne
  `--environ`, Syntaxprüfung vor Start, Loopback-Verwaltung aus dem Caddyfile.
- [DNS-Include](../pilot/https/90-jaylab-https-pilot.conf): nur `address` und
  `local` für den Pilotnamen. Kein Zonen-Wildcard für `jaylab.org`.
- [Buildstände](../pilot/https/build-versions.json): Go, xcaddy, Caddy und
  Cloudflare-Modul festgelegt. Der normale Paketbuild darf diesen Build
  bei Aktualisierungen nicht unbemerkt ohne DNS-Modul ersetzen.

Die DNS-Regeln umfassen bei dnsmasq auch Unterdomänen des konkreten
Pilotnamens. ACME prüft die öffentlichen Challenge-Daten deshalb über die
expliziten Resolver; andere Namen unter `jaylab.org` bleiben unberührt.

## Ausgeführter Ablauf und Wiederverwendung

Die folgenden Schritte beschreiben die ausgeführte Anlage. CT 131 und der
Token existieren bereits; keine zweite Ressource anlegen. Vor einer Änderung
Soll-/Istvergleich durchführen und nur einen nachgewiesenen Unterschied ändern.

1. IDs/IPs erneut gegen Cluster, Gastkonfigurationen, Reservierungen, Leases,
   DNS und ARP prüfen. Debian-Template aus geprüftem Proxmox-Katalog auswählen,
   Version und Prüfsumme festhalten. Aktuell liegt auf proxmox unter anderem
   Debian 12.12 im Cache; dessen Herkunft wurde hier nicht nachgewiesen.
   Erst dann den eigenen CT mit den obigen Ressourcen anlegen. Im Gast keine
   ungeprüfte SLAAC-/DHCPv6-Konfiguration übernehmen; effektive IPv6-Adressen
   und Listener kontrollieren. Bestehende Gäste/Hostnetze bleiben unverändert.
2. Root-/Konsolenzugang über Host und `pct exec 131` prüfen; einen neuen
   Gast-SSH-Hostschlüssel über diesen vertrauenswürdigen Weg binden. Nur den
   vorhandenen öffentlichen Verwaltungsschlüssel eintragen. Den privaten
   Schlüssel an seinem bisherigen Ort belassen.
3. Versionierten Build erstellen bzw. den geprüften Binärstand übertragen.
   SHA256, `go version -m`, `caddy version` und `caddy list-modules` ablegen.
   Erforderlich ist die genaue Zeile `dns.providers.cloudflare`.
   Vor jedem Upgrade neuen Kandidaten bauen, prüfen und alten Binärstand
   samt Konfiguration für die Rücknahme erhalten; niemals `@latest` verwenden.
4. Im neuen Gast Benutzer `caddy`, `/etc/caddy` und die persistenten
   Verzeichnisse `/var/lib/caddy-pilot/staging` sowie `production` anlegen.
   Datenverzeichnisse nur für den Dienstbenutzer les-/schreibbar halten.
   Caddyfile/Unit installieren, Umgebung nach `/etc/caddy/pilot.env`.
   Den auf die Zone begrenzten Token ausschließlich in der geschützten Datei
   `/etc/caddy/cloudflare.env` (`root:root`, Modus 0600) bereitstellen.
   Der [geprüfte Token `caddy-dns-jaylab`](CLOUDFLARE-CADDY-DNS-ZUGANG.md)
   liegt bereits in der lokalen DPAPI-Ablage; keine erneute Anlage nötig.
   Diese enthält `CF_API_TOKEN=...`; niemals den Wert in Befehlsargumente,
   Chat, Buildprotokolle oder Git übernehmen.
5. Unit mit `systemd-analyze verify /etc/systemd/system/caddy-pilot.service`
   prüfen und im tatsächlichen unprivilegierten LXC testen. Bei einem
   Schutzoptionsfehler dessen Ursache prüfen; keine pauschale Privilegierung.
   Zuerst Let’s-Encrypt-Staging, dann Produktion mit eigenem Speicher abnehmen.
   Ein Wechsel der EnvironmentFile erfordert einen Dienstneustart; ein
   bloßer Caddy-Reload ändert die Umgebung des laufenden Prozesses nicht.
6. Zuerst HTTPS vom Pilotclient mit `curl --resolve` prüfen. Bei Staging nur
   eine separat geprüfte Staging-Vertrauenskette für den Test verwenden;
   kein `-k` als erfolgreiche TLS-Abnahme werten. Das Produktionszertifikat
   muß ohne Sondervertrauen gültig sein. Erst danach den DNS-Include aktivieren.
7. Auf CT 101 vor Aktivierung Hauptdatei, alle Includes und Default-Datei
   erneut sichern und ihre Änderungen mit dem Phase-0-Stand vergleichen.
   Das neue Include muß vorher fehlen. Vollständigen Kandidaten einschließlich
   absoluter Includes prüfen. Bei geänderter Umgebung nicht den alten Test
   als Nachweis übernehmen. Der bestehende Dienst verwendet
   `/etc/dnsmasq.conf` und `/etc/dnsmasq.d` über `CONFIG_DIR`.
8. Nur die neue Datei nach `/etc/dnsmasq.d/90-jaylab-https-pilot.conf` übernehmen.
   Nach `/usr/share/dnsmasq/systemd-helper checkconfig` genau einen geplanten
   `systemctl restart dnsmasq` ausführen. Die installierte Reload-Aktion ist
   nur SIGHUP und lädt diesen neuen Konfigurationsbestand nicht vollständig.
   Kurze DNS-/DHCP-/RA-Unterbrechung beim Neustart berücksichtigen.
9. Nur am Pilotgerät nach Sicherung seiner genauen DNS-Einstellung den
   öffentlichen Zweitresolver entfernen. Betriebssystem, Browser-DoH, VPN
   und Proxy getrennt prüfen. Keine allgemeine DHCP-/RA-Verteilung ändern.
10. Gast-Autostart, Dienst-Autostart und separaten PBS-Backupjob für genau
    den neuen CT einrichten. Vor Produktivbetrieb vollständigen Restore
    isoliert prüfen. Bei Authentik später zusätzlich nativen PostgreSQL-Dump
    und dessen Restore vorsehen; hier noch keinen IdP bereitstellen.

## Prüfkommandos und Abnahme

Auf dem Pilotclient, nachdem die Kandidaten-IP tatsächlich vergeben wurde:

```sh
curl --noproxy '*' --resolve https-pilot.jaylab.org:443:192.168.10.18 \
  --silent --show-error --write-out '\nZiel=%{remote_ip} HTTP=%{http_code}\n' \
  https://https-pilot.jaylab.org/
dig @192.168.10.6 https-pilot.jaylab.org A
dig @192.168.10.6 https-pilot.jaylab.org AAAA
dig @192.168.10.6 https-pilot.jaylab.org TYPE65
dig @192.168.10.6 https-pilot.jaylab.org A +tcp
dig @192.168.10.6 dfderp.jaylab.org A
dig @1.1.1.1 https-pilot.jaylab.org A
curl --noproxy '*' --silent --show-error \
  --write-out '\nZiel=%{remote_ip} HTTP=%{http_code}\n' https://https-pilot.jaylab.org/
```

Für Windows `curl.exe` verwenden; `dig` kann über WSL gezielt den Resolver
prüfen. Der abschließende Browser-/Windows-Aufruf muß jedoch die tatsächliche
Clientauflösung prüfen, nicht nur WSL oder `--resolve`.

| Prüfung | Erwartet / bisheriger Nachweis |
| --- | --- |
| Vollständige DNS-Kandidatensyntax | Bestanden auf dnsmasq 2.91, produktive Quelldateien per Hash unverändert |
| Isolierte DNS-Antworten UDP/TCP | 8/8 bestanden; Testname A `.10.18`, AAAA/HTTPS NODATA, ERPNext weiterhin auflösbar |
| DNS-Rückweg | Host-IP mit unverändert gebundenem SSH-Schlüssel und `pct exec 101` geprüft |
| Caddy-Modul / Konfiguration | Caddy v2.11.9 / Modul v0.2.4; Syntax, systemd-Schutzoptionen und DNS-01 im unprivilegierten Gast bestanden |
| Echtes HTTPS | Staging mit separat geladenen offiziellen Test-CA-Dateien bestanden; Produktion unter Windows ohne Sondervertrauen HTTP 200, Ziel `.10.18`, SAN korrekt; Edge zeigt den Testtext |
| Resolverpfad | Begrenzter Mitschnitt sieht `.10.241` ↔ `.10.6` für A, AAAA und HTTPS; keine Weiterleitung des Testnamens; UDP und TCP geprüft |
| IPv6 | AAAA/HTTPS NODATA im Betrieb; erzwungenes IPv6 am Windows-PC scheitert ohne Ersatzpfad; echter Dual-Stack-Clienttest bleibt offen |
| Unbeteiligte Dienste | Ursprüngliche DNS-/DHCP-/RA-Dateien per SHA256 unverändert; ERPNext öffentlich und lokal auflösbar; keine Tunnelroute geändert |
| WAN-Ausfall | Wiederhergestellter Gast ohne Netzkarte liefert mit vorhandenem Zertifikat HTTPS 200; dies ersetzt nicht den noch offenen LAN-/DNS-/Browser-Test bei WAN-Ausfall |
| Persistenz und Restore | Dienst- und Gastautostart bestätigt; nach Neustart SSH/Caddy aktiv, keine fehlgeschlagenen Units; vollständiger PBS-Restore isoliert bestanden |

## Betriebsnachweise und Restpunkte

Das Template `debian-13-standard_13.6-1_amd64.tar.zst` stammt aus dem
signiert geprüften Proxmox-Katalog. `pveam download` bestätigte die Prüfsumme:
`4c0c27ca6ceab5ef0b84db57825a00f26157ef1854bafe97297813e1cbe8ecb8cc9c453cab6b3b0efe1ba193a50c47ece1e41d950e411b8730b835b71e9e754b` (SHA512).
Drei gezielte ARP-Proben sowie Gast-, DNS-, Lease- und Reservierungsabgleich
ergaben vor Vergabe keinen Konflikt. Ein abgeschaltetes unbekanntes Gerät
läßt sich damit nicht ausschließen.

Der IPv6-Modus `manual` verhinderte beim ersten Start keine SLAAC-Adressen.
Im neuen Pilotgast ist deshalb IPv6 auf `eth0` ausdrücklich abgeschaltet.
SSH verwendet ausschließlich IPv4 und Schlüsselanmeldung; Caddy bindet
explizit `.10.18:443`, die Admin-API `127.0.0.1:2019`. Port 80 und UDP 443
werden nicht geöffnet. Drei vom Debian-Template verlangte, hier unnötige
Mountunits werden im Container übersprungen; keine AppArmor-Lockerung und
kein Nesting. Nach diesen gezielten Anpassungen startet der Gast fehlerfrei.

Produktionszertifikat des Testnamens: Let’s Encrypt YE2, SAN
`https-pilot.jaylab.org`, gültig bis 13. Februar 2027; Erneuerung durch Caddy.
Staging-Vertrauen wurde nur einer einzelnen curl-Prüfung übergeben, nicht in
Windows oder den Browser importiert. Der DNS-Token liegt im Gast als
`/etc/caddy/cloudflare.env`, `root:root`, 0600. Die Cloudflare-CLI bestätigte
nach ACME, daß kein Challenge-TXT des Testnamens zurückblieb.

PBS-Job `caddy-pilot-131-daily`: täglich 22:45 Hostzeit, nur CT 131,
`proxmox-backupserver`, Aufbewahrung 5 letzte / 7 tägliche / 1 monatliche
Sicherung. Wiederhergestellter Stand `ct/131/2026-11-15T14:54:13Z`, Namespace
`containerbackup`. Testklon CT 133 vor erstem Start ohne Netzkarte, eigene
Loopback-Adresse; HTTPS und sieben Dateien einschließlich Token und privatem
Zertifikatsschlüssel identisch geprüft, ohne Geheimnisse auszugeben.
Testklon anschließend gestoppt und nach Eigentumsprüfung entfernt.
Der PBS-Speicher verwendet den vorhandenen unverschlüsselten Sicherungsmodus;
Zugriff auf diesen Datastore ist daher auch Zugriff auf die gesicherten Secrets.

Der Thinpool enthält bereits überbuchte virtuelle Größen und hat keine
automatische Erweiterung konfiguriert. Tatsächlich blieb ausreichend freier
Platz; die bestehende Storage-Konfiguration wurde nicht verändert.
Die Kapazitätsüberwachung bleibt ein Betriebsrestpunkt.

Rohbelege: `.local/changes/2026-11-15-https-pilot/`, insbesondere
`dns-capture.jsonl`, `client-dns-result.json`, `final-reboot.txt`,
`backup-final.log`, `restore.log` und `restore-cleanup.json`.

## Gezielter Rückweg

Bei DNS-Fehlern über den bereits geprüften IP-Zugang vom Arbeitsplatz:

```powershell
wsl.exe --exec ssh -F /mnt/c/Users/ajjay/Documents/GitHub/jaylab/.local/access/ssh_config_wsl `
  -o HostName=192.168.10.7 -o HostKeyAlias=proxmox2.jaylab.local jaylab-proxmox2
```

Auf diesem Host **nur nach Abgleich, daß die Datei zum Pilot gehört**:

```sh
pct exec 101 -- rm -- /etc/dnsmasq.d/90-jaylab-https-pilot.conf
pct exec 101 -- /usr/share/dnsmasq/systemd-helper checkconfig &&
  pct exec 101 -- systemctl restart dnsmasq &&
  pct exec 101 -- systemctl is-active dnsmasq
```

Nur nach erfolgreicher Syntaxprüfung neu starten; bei einem Fehler die
Ursache mit der gesicherten Fassung vergleichen. Keine fremden Includes
oder den gesamten DNS-Bestand unbesehen überschreiben. Resolvereinstellung
des Pilot-PCs exakt auf den zuvor erfaßten Zustand zurücksetzen und dessen
DNS-Cache leeren; im aktuellen Stand sind es `.10.6` und `8.8.8.8`.
Interne Namen, ERPNext-Auflösung sowie DHCP/RA prüfen.

Bei Caddy-Fehlern zuerst DNS und Pilotclient zurücknehmen, danach im eigenen
CT `systemctl stop caddy-pilot`. Bei einem Buildwechsel alten Binärstand,
Caddyfile und Umgebung wiederherstellen; Zertifikatsspeicher nicht löschen.
Der neue Gast wird bei Fehlern zunächst gestoppt, nicht automatisch zerstört.
Eine Löschung verlangt erneuten Eigentums-/Datenabgleich und geprüfte Sicherung.
Es gibt in diesem Schritt keine geänderte Tunnelroute zurückzunehmen.

Der nachgewiesene Rückweg genügt für den isolierten DNS-/Dienstschritt.
Er ist kein unabhängiger Rückweg für spätere Routing-, Bridge-, Switch-
oder Firewalländerungen.

## Herstellergrundlagen

[Caddy-Cloudflare-Modul](https://github.com/caddy-dns/cloudflare),
[Caddy-Optionen](https://caddyserver.com/docs/caddyfile/options) und
[Dienstbetrieb](https://caddyserver.com/docs/running) wurden für die Kandidaten
geprüft. Release- und Modulkennungen stammen aus den offiziellen GitHub-
Quellen; der Go-Download wurde gegen die SHA256-Angabe von `go.dev` geprüft.
