# Änderung: DNS-Zuweisung für das Fairphone

## Umfang und Istzustand

CT 101 auf `proxmox2` betreibt dnsmasq 2.91. Das Fairphone erhielt am
22. November 2026 im WLAN `192.168.60.206` über `enp6s0` und meldete
`ERR_NAME_NOT_RESOLVED` für `login.jaylab.org`. Die bisherige DHCP-Option
dieses Netzes nennt ausschließlich öffentliche DNS-Server; diese kennen den
nur intern eingerichteten Namen nicht. Der lokale Resolver `192.168.60.6`
beantwortet ihn mit `192.168.10.18`. Der tatsächlich vom Telefon verwendete
Resolver ist noch nicht unmittelbar nachgewiesen.

## Änderung, Sicherung und Rücknahme

Die IPv4-DHCP-DNS-Option auf `enp6s0` wird für alle dort versorgten Clients
auf ausschließlich `192.168.60.6` gesetzt. IPv6-DNS und Routerankündigungen
bleiben unverändert. Der Dienst muß die Konfiguration durch Neustart einlesen;
Clients übernehmen die neue Option beim nächsten DHCP-Neubezug. Während des
Neustarts sind DNS und DHCP kurz unterbrochen.

Der vollständige Kandidat wurde mit der installierten dnsmasq-Version und den
tatsächlichen übrigen Includes syntaktisch geprüft. Die Vorversion liegt als
Archiv auf `proxmox2` unter `/root/jaylab-dns-fairphone-20261122/before.tar`.
Der numerische Hostzugang und `pct exec 101` sind geprüft. Bei Fehlschlag die
gesicherte `etc/dnsmasq.d/dnsmasq.conf` aus dem Archiv gezielt in CT 101
wiederherstellen, mit `systemd-helper checkconfig` prüfen, dnsmasq neu starten
und Dienst sowie DNS prüfen. Vor einer späteren Rücknahme zwischenzeitliche
Änderungen vergleichen. Das Synchronisationsskript erstellt zusätzlich eine
eigene Sicherung und nimmt bei erkannten Fehlern seine Änderung zurück.

## Abnahme

Nach Aktivierung Dienst, interne und externe DNS-Antworten über UDP/TCP und
IPv4/IPv6 sowie die persistente DHCP-Option prüfen. Das Fairphone muß WLAN neu
verbinden und die Anmeldung in einer frischen Sitzung testen. Ein erfolgreicher
Serverseitentest ersetzt weder die Prüfung des tatsächlich bezogenen DNS-Servers
noch die vollständige Anmeldung am Telefon.

## Aktivierungsstand

Die Änderung wurde am 22. November 2026 mit `synch.sh --config-only`
aktiviert. Der Dienst ist aktiv; die neue DHCP-Option steht auf dem Ziel.
Interne DNS-Abfragen über IPv4 und IPv6 mit UDP und TCP sowie externe
DNS-Abfragen über beide Adreßfamilien waren erfolgreich. Der erneute
Skriptlauf stellte identische Dateien fest und löste keinen Neustart aus.
Die zuvor abweichende Hostdatei und das Paperless-Include blieben unverändert.
Sicherung des Skripts: `/root/jaylab-dnsmasq-sync.2dzuNodg/before` in CT 101.
DHCP-Neubezug und Anmeldung am Fairphone stehen noch aus.
