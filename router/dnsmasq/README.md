# Laufender dnsmasq-Bestand

Am 15. November 2026 mit CT 101 auf `proxmox2` abgeglichen.
Die Dateien bilden den gemessenen Konfigurationsbestand ab; ein Eintrag
bestätigt weder die Existenz noch die Erreichbarkeit des genannten Gerätes.

| Repository-Datei | Ziel im Gast |
|---|---|
| `dnsmasq.conf` | `/etc/dnsmasq.d/dnsmasq.conf` |
| `dhcphosts.conf` | `/home/dhcphosts.conf` |
| `dnsmasq.cnames.conf` | `/home/dnsmasq.cnames.conf` |
| `hosts` | `/home/hosts` |
| `90-jaylab-https-pilot.conf` | `/etc/dnsmasq.d/90-jaylab-https-pilot.conf` |
| `91-jaylab-grafana.conf` | `/etc/dnsmasq.d/91-jaylab-grafana.conf` |
| `92-jaylab-authentik.conf` | `/etc/dnsmasq.d/92-jaylab-authentik.conf` |
| `93-jaylab-proxmox.conf` | `/etc/dnsmasq.d/93-jaylab-proxmox.conf` |

Der laufende Dienst lädt das Verzeichnis mit
`-7 /etc/dnsmasq.d,.dpkg-dist,.dpkg-old,.dpkg-new`.
Die vier zusätzlichen Includes sind die maßgeblichen Repository-Fassungen
für Split-DNS; die bisherigen Kopien unter `pilot/https/` wurden entfernt.
Die drei Caddy-Namen liefern lokal A `192.168.10.18` (Caddy), AAAA und HTTPS
ohne Antwortdaten. Die Authentik-Backend-Adresse `.10.19` wird nicht als
Browserziel ausgegeben. `pve`, `pve2` und `pve3.jaylab.org` zeigen
mit vollständigem Domainnamen direkt auf `192.168.10.4`, `.7` und `.13`;
auch dort bleiben AAAA und HTTPS ohne Antwortdaten.

Beim Abgleich wurden außerdem bereits auf dem Server vorhandene, bisher im
Repository fehlende DHCP-Einträge für icinga, wiki, dokuwiki, bookstack,
nettest und k3s-2 bis k3s-4 sowie Hosteinträge für waf/web übernommen.
Diese älteren Einträge wurden nicht durch den HTTPS-/SSO-Pilot angelegt;
ihre fachliche Aktualität ist damit nicht bestätigt. Ihre Entfernung wäre
eine eigene geprüfte Betriebsänderung.

Die Hauptkonfiguration ist hinsichtlich aktiver Direktiven identisch;
zusätzliche erklärende Kommentare im Repository bleiben erhalten.
DHCP-/RA-Verteilung wurde bei diesem Abgleich nicht geändert.

## Synchronisierung

Das überarbeitete `synch.sh` synchronisiert genau die acht oben genannten
Dateien. Aus Bash/WSL, unabhängig vom Arbeitsverzeichnis:

```bash
bash router/dnsmasq/synch.sh
```

Standardzugang: Repository-Datei `.local/access/ssh_config_wsl`, Profil
`jaylab-dnsmasq`. Abweichungen lassen sich mit `DNSMASQ_SSH_CONFIG` und
`DNSMASQ_SSH_TARGET` angeben. Hostschlüsselprüfung und Batchmodus bleiben
aktiv; private Schlüssel werden nicht kopiert. `--help` benötigt keinen
Netzzugang. Das Ziel benötigt root, Bash, flock, dig und den vorhandenen
Debian-dnsmasq-systemd-helper.

Das Skript normalisiert CRLF im Übertragungsbestand, überträgt zunächst in
ein eigenes geschütztes Zielverzeichnis und sichert alle verwalteten
Vorversionen samt Dateirechten. Fremde Includes bleiben erhalten. Identische
Dateien lösen keinen Neustart aus. Bei Änderungen werden die Dateien auf
Platte ersetzt und sämtliche tatsächlichen Includes mit `checkconfig`
geprüft, bevor der laufende Dienst neu gestartet wird. Danach werden
Dienstzustand sowie die sechs Split-DNS-Namen über UDP/TCP geprüft.

Bei Fehler oder abfangbarem Abbruch werden die verwalteten Vorversionen
zurückgespielt und dnsmasq erneut geprüft und gestartet. Ein Stromausfall
oder SIGKILL kann diesen Rückweg unterbrechen; die ausgegebene Sicherung
unter `/root/jaylab-dnsmasq-sync.*/before` bleibt für die Wiederherstellung
erhalten. DHCP-/RA-Funktionstests und die externe Sicherung nach
[Betrieb](../../docs/BETRIEB.md) bleiben Teil der jeweiligen Betriebsänderung.

Lokal geprüft: Bash-Syntax, Hilfe sowie simulierte erfolgreiche Übertragung,
Wiederholung ohne Neustart und Rücknahme bei Syntax-/Neustartfehlern.
Das überarbeitete Skript wurde noch nicht gegen das laufende Netz ausgeführt.
