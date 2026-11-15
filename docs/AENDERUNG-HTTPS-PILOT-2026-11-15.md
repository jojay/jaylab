# Änderung: HTTPS-Pilot CT 131, Z05/Z07/Z09

## Ergebnis und Umfang

Beauftragt durch „setze den Plan fort“ am 15. November 2026: den vorbereiteten
datenlosen HTTPS-Pilot aktivieren. Neuer unprivilegierter Debian-LXC auf
`proxmox`, CT 131, 1 CPU, 1 GiB RAM, 8 GiB `local-lvm`, `192.168.10.18/24`
auf bestehender `vmbr0`, Gateway `.10.3`, DNS `.10.6`. Caddy beantwortet nur
`https-pilot.jaylab.org` mit festem Text. Keine Tunnelumstellung in diesem Schritt.

## Istzustand und Abhängigkeiten

Die [Phase-0-Aufnahme](PHASE0-HTTPS-SPLIT-DNS-SSO.md) und der
[Pilotablauf](PILOT-HTTPS-SPLIT-DNS.md) enthalten Bestand und Kandidaten.
Am 15. November erneut bestätigt: CT 131 fehlt; lokaler Thinpool hat rund
76 GiB frei, PBS auf anderem Host ist aktiv und hat rund 64 GiB frei.
Die bekannten iSCSI-Zeitüberschreitungen betreffen nicht das gewählte Rootfs.
`vmbr0` führt zu `enp1s0`; die weitere physische Zonenzuordnung bleibt offen.
Darum enthält der Gast nur Testdaten. Der Arbeitsplatz hat derzeit kein IPv6.

## Konkrete Änderung

1. Debian `debian-13-standard_13.6-1_amd64.tar.zst` aus dem signiert geprüften
   Proxmox-Katalog laden; `pveam download` prüft die Archivprüfsumme.
2. Adreßbelegung erneut prüfen, CT ausschließlich bei freier ID anlegen.
   Kein Nesting, keine zusätzlichen Mounts, keine Änderung der Hostbridge.
3. Die Dateien aus `pilot/https/` und den dort festgelegten Caddy-Build
   installieren; Token aus DPAPI über den gebundenen SSH-Zugang übertragen.
4. DNS-01 zuerst mit Staging, dann mit Produktions-CA prüfen; getrennte
   Zertifikatsspeicher. HTTPS vor DNS-Umschaltung über `curl --resolve` prüfen.
5. Vollständigen DNS-Bestand sichern und Kandidaten prüfen. Ausschließlich
   `90-jaylab-https-pilot.conf` hinzufügen, Syntax prüfen und dnsmasq einmal
   neu starten. Dies unterbricht DNS/DHCP/RA kurzzeitig.
6. Pilotclient, Persistenz, gesonderten PBS-Backupjob und isolierten Restore
   prüfen. Noch keinen fachlichen Grafana- oder SSO-Erfolg daraus ableiten.

## Sicherung und Rücknahme

Rohbelege liegen unter `.local/changes/2026-11-15-https-pilot/`.
Der DNS-Host ist über `192.168.10.7` mit unveränderter SSH-Hostschlüsselbindung
und `pct exec 101` erreichbar; der neue Gast über Host `.10.4` und `pct exec 131`.
Diese Wege hängen nicht von der DNS-Änderung ab. Es werden keine bestehenden
Routing-, Bridge-, Firewall- oder Switchregeln geändert.

Bei mißlungener Abnahme nur das nach Eigentums-/Hashabgleich eigene DNS-Include
entfernen, `systemd-helper checkconfig` ausführen und dnsmasq neu starten.
Eine geänderte Client-DNS-Einstellung exakt zurücksetzen. Im eigenen CT den
Dienst `caddy-pilot` stoppen; Zertifikate und Gast für die Untersuchung erhalten.
Vorhandene Dienste und Zugangsdaten bleiben erhalten. Genaue Befehle stehen
im [Pilotablauf](PILOT-HTTPS-SPLIT-DNS.md#gezielter-rückweg).

## Abnahme und Abschluß

Aktivierung und Meßergebnisse werden im Pilotablauf fortgeschrieben.
Maßgeblich sind echtes HTTPS ohne Zertifikatsausnahme, lokales A und leere
AAAA-/HTTPS-Antworten, unveränderte Fremdnamen, Gast-/Dienstpersistenz,
PBS-Sicherung und isolierte Wiederherstellung. Ausstehende Prüfungen werden
ausdrücklich als offen geführt.
