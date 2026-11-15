# Änderung: lokale Authentik-Basis, Phase 4

## Umfang

Neue eigene Debian-VM 132 `authentik` auf `proxmox`, 2 vCPU, 4096 MiB RAM,
32 GiB `local-lvm`, eine Netzkarte an der vorhandenen `vmbr0`, IPv4
`192.168.10.19/24`, Gateway `.10.3`, DNS `.10.6`. Keine bestehenden Gäste,
Bridges, Routen oder Switchregeln verändern. `login.jaylab.org` bleibt lokal;
keine Tunnelroute und kein öffentlicher Web-DNS-Eintrag für diesen Namen.

## Voraussetzungen und Kandidat

Am 15. November erneut geprüft: VM-ID 132 und `.10.19` fehlen in Gast-,
DNS-, Lease- und Reservierungsbestand; drei ARP-Proben ohne Konflikt.
Host hat rund 56 GiB verfügbaren RAM; Thinpool real rund 49 Prozent belegt.
Überbuchung der virtuellen Plattengrößen ist bekannt, kein Kapazitätsnachweis
für beliebiges Wachstum. PBS auf anderem Host steht bereit.

Offizielles Debian-13-Cloudimage `genericcloud`, Bau `20261111-2659`, über
HTTPS aus dem datierten Herstellerverzeichnis geladen und gegen die
Hersteller-SHA512 geprüft:
`3247873136ba09b060fab45e9c115239f81c1d401fce00b8fa9b872013f7135d6a40b12462ab5ac03b9fa4ed5955dd0e8d1c900109a939ad7a0a4dafe7dea47b`.
Eigene NoCloud-Start-CD mit Netz-/Benutzerkonfiguration und vorhandenem
öffentlichen Verwaltungsschlüssel; keine privaten Schlüssel oder Tokens
auf diesem Medium. Neuen Gast-Hostschlüssel erst über QEMU-Gastagent und
gebundenen Proxmox-SSH-Zugang übernehmen.

Offizielle Authentik-Fassung 2026.8.5, veröffentlicht am 21. Oktober 2026.
Die offizielle Compose-Vorlage enthält Server, Worker und PostgreSQL 16.
Vor Aktivierung Images zusätzlich über Digests festlegen. Den Docker-Socket
für den vorgesehenen eingebetteten Outpost nicht in den Worker durchreichen.
Secrets getrennt von Git, nur geschützt im Gast und DPAPI-lokal ablegen.

## Prüfung und Rückweg

Zuerst VM-Netz, QEMU-Gastagent, SSH-Hostschlüssel und IPv4-only-Betrieb prüfen.
Dann Compose-Syntax, Datenbank, Server/Worker, lokales HTTPS und Anmeldung
abnehmen. Vor Anwendungsanbindung native PostgreSQL-Sicherung und isolierten
Restore sowie vollständige VM-Sicherung prüfen. Die bestehenden lokalen
Anmeldewege und ERPNext-Maschinenzugänge bleiben erhalten.

Bei Fehlern nur eigene Authentik-DNS-/Caddy-Ergänzungen zurücknehmen und die
neue VM stoppen; ihren Datenbestand für Untersuchung und Wiederherstellung
erhalten. Keine vorhandene Identitätsdatenbank ersetzen. Reguläres Benutzerkonto
erst nach Betreiberangabe anlegen; getrennten lokalen Notzugang vorsehen.
Breite DNS-Verteilung, Netzisolation und externer IdP-Zugang bleiben eigene
Abnahmeschritte.

Quellen: [offizielle Compose-Installation](https://docs.goauthentik.io/install-config/install/docker-compose/),
[automatisierte Ersteinrichtung](https://docs.goauthentik.io/install-config/automated-install/).
Arbeitsbelege: `.local/changes/2026-11-15-authentik/`.

## Ausführung und bisherige Abnahme

VM 132 läuft auf `proxmox`; MAC `BC:24:11:21:17:88`, Verwaltung über
`jayadmin` und den vorhandenen SSH-Schlüssel. Den neuen Hostschlüssel über
QEMU-Gastagent ausgelesen und vor direktem SSH gebunden. Cloud-init ohne
Fehler abgeschlossen; Debian 13.7, Zeit synchronisiert, nur IPv4 am Gast.
Die anfänglich falsche Bootreihenfolge wurde vor dem Betrieb auf `scsi0`
korrigiert. `onboot: 1`, Startreihenfolge 25 mit 30 Sekunden Wartezeit;
ein vollständiger Host-Kaltstart ist noch nicht geprüft.

Docker 29.9.3, Compose 5.7.1, Authentik 2026.8.5 und PostgreSQL 16.16
installiert. Die [Compose-Datei](../pilot/authentik/compose.yml) bindet die
Images an Digests. Kein Docker-Socket im Worker, keine fremde Anwendung.
Server, Worker und PostgreSQL sind gesund. HTTP 9000 bleibt auf Loopback;
HTTPS 9443 ist an `.10.19` gebunden. Nur `.10.18/32` wird als Proxyquelle
vertraut. Dies bestätigt noch keine Segmentisolation des Backend-Ports.

Backend-TLS mit vorhandenem Automation-CA-Vertrauen und neuem, ausschließlich
im Gast erzeugtem privaten Schlüssel. SAN `login.jaylab.org` und `.10.19`,
gültig bis 15. November 2027; Zertifikat-SHA256
`F327FC0DA015A89BEC9F845210117ABA8080181D40ADA0DF1A029E5828782EE0`.
Authentik wählt dieses Zertifikat über seine namensgebundene Oberfläche.
Caddy prüft Namen und CA, ohne TLS-Ausnahme. Browser-TLS über DNS-01;
Windows-curl bestätigt TLS-Prüfergebnis 0, Ziel `.10.18`, Anmeldeseite HTTP 200.

`/etc/dnsmasq.d/92-jaylab-authentik.conf` liefert lokal A `.10.18`, AAAA und
HTTPS ohne Antwortdaten. Vollständige Includes vor Aktivierung geprüft,
Altdateien bytegleich erhalten und gesichert. Keine öffentliche Tunnelroute
für den IdP angelegt.

Reguläres Konto `jay` mit der vom Betreiber genannten E-Mail-Adresse
angelegt, ohne Administratorrechte. E-Mail und Einrichtungslink bleiben
außerhalb von Git. Getrennter Notzugang `akadmin`; neues zufälliges Kennwort
und Bootstrapzugang unter `.local/access/authentik/` mit Benutzer-DPAPI und
eingeschränkten ACLs gesichert. Kennwortdateien im Gast nur für root lesbar.
Ein kontogebundener, beim Aufruf verbrauchter Einrichtungslink ist 30 Minuten
gültig. Eigener Ablauf ohne E-Mail-Versand und ohne Kontowahl; Zugriff ohne
Token wurde mit `ak-stage-access-denied` abgewiesen. Benutzeranmeldung von
`jay` durch Betreiber und API bestätigt; TOTP anschließend eingerichtet.
Die Verwaltungskonto-MFA und der vollständige Notzugangstest bleiben offen.
Grafana ist inzwischen der erste gesondert dokumentierte SSO-Pilot.

Native PostgreSQL-Sicherung mit `pg_dump -Fc` und Restore in PostgreSQL 16.16
mit `--network none` erfolgreich. Benutzer-, Brand-, Zertifikats-, Flow- und
Richtlinientabellen stimmen bytegleich überein; ausschließlich den eigenen
Testcontainer anschließend entfernt. Native Dumps täglich 22:50 Uhr
Europe/Berlin, sieben Tage lokale Aufbewahrung. Ein zusätzlicher Export aus
Dump, Dienstkonfiguration, Geheimnissen, Zertifikaten und Medien wurde außerhalb
der VM DPAPI-verschlüsselt gespeichert und testweise im Speicher entschlüsselt.
Dieser Zugriff benötigt das bestehende Windows-Benutzerprofil.

PBS-Vollsicherung `vm/132/2026-11-15T15:52:22Z` erfolgreich. Eigener Job
`authentik-132-daily`, täglich 23:00 Uhr Hostzeit Europe/Berlin, nur VM 132,
Aufbewahrung keep-last 5, keep-daily 7, keep-monthly 1. Keine Benachrichtigungen
versandt. Die vorhandene PBS-Ablage verwendet weiterhin keine clientseitige
Verschlüsselung; ihr Zugriff muß geschützt bleiben. Vollständiger isolierter
VM-Restore in ID 134 erfolgreich: keine Netzkarte, `.10.19/32` nur auf
Loopback, alle drei Dienste gesund, HTTPS 200 mit TLS-Prüfergebnis 0 und
sechs Konfigurations-/Schlüsseldateien bytegleich. Beim ersten Offline-Start
vor Einrichtung der Loopback-Adresse konnte der Server seinen Datenbanknamen
nicht auflösen; gezieltes Neuerzeugen dieses Containers nach Einrichtung
der Adresse behob den Fehler. Nur die eigene Testkopie danach entfernt.
Dies ersetzt keinen normalen Host-Kaltstarttest. RPO und RTO sind nicht vereinbart.

Manipulierte Forwarded-Header wurden beim Weg über Caddy überschrieben:
Authentik protokollierte echten Client `.10.241`, Host `login.jaylab.org`
und Schema `https` statt der eingespeisten Fremdwerte.

Offen für vollständige SSO-Abnahme: MFA/Notzugang, Neustartprüfung,
WebSocket-Test, vollständige Rollen-/Sitzungstests sowie
der je Anwendung konkrete Rückweg. Externes SSO benötigt einen gesondert
geklärten Weg zum zunächst lokalen IdP. Der Grafana-Mobilfunktest ist noch
nicht als bestanden bestätigt.
