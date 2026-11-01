# Ziele und Arbeitsstand

Stand: 1. November 2026. Das Gesamtziel ist ein nachvollziehbar segmentiertes,
sicher administrierbares und nach Ausfällen wiederherstellbares Heimnetz.
Diese Ziele sind ein Arbeitsvorrat, keine pauschale Deployment-Erlaubnis.

Statuswerte: **offen**, **in Arbeit**, **blockiert**, **abgeschlossen**.
Nur anhand belegter Abschlußkriterien abschließen. Blockaden auf den abhängigen
Teil begrenzen; lokale Prüfung und Dokumentation können weitergehen.

| ID | Priorität | Ziel / Status | Abhängigkeit | Abschlußkriterium |
| --- | --- | --- | --- | --- |
| Z00 | Grundlage | Agentischen Workspace aufbauen — abgeschlossen | keine | Regeln, Inventar, Ziele, fünf Skills und lokale Prüfungen vorhanden und geprüft |
| Z01 | P0 | Bestand und Zugänge nachweisen — in Arbeit | keine | Geräteversionen, sichere Anmeldung und Rechte belegt; alle sechs Hostports mit MAC, Bridge, LXC/Host, Gegenport und Segment zugeordnet; WAN- und Mesh-Pfade erfaßt |
| Z02 | P0 | Rückweg und Sicherungen nachweisen — offen | Z01 für Live-Teile | Vom Änderungspfad unabhängige Konsole erreichbar; verschlüsselte/externe Sicherungen vorhanden; Router-/DNS-/Switch-Konfiguration und notwendige LXC-Daten testweise isoliert wiederhergestellt; RPO/RTO mit Betreiber festgelegt |
| Z03 | P0 | Segmentarchitektur ohne VLANs entscheiden — offen | Z01 | Physische Broadcast-Domänen und sechs-Port-Budget belegt; keine unbeabsichtigte Bridge oder Mesh-Umgehung; Entwurf und verbleibende Grenzen dokumentiert |
| Z04 | P0 | IPv4-/IPv6-Firewall überarbeiten — offen, U01 zurückgestellt | Entwurf: Z01/Z03; Rollout: Z02 | Freigaben begründet; IPv4 und IPv6 geprüft; neue unerlaubte Verbindungen abgewiesen; nötige Rückwege und ICMPv6 funktionieren; keine pauschale interne Freigabe |
| Z05 | P0 | DNS, DHCP und RA zuverlässig machen — in Arbeit | Z01; Rollout: konkreter Rückweg, Z02/Z03 soweit betroffen | Zunächst IPv6-/DNS-Ursache für Amazon Music und Netflix im WLAN papalapap eingrenzen und beheben; anschließend eindeutige Resolver-/RA-Zuständigkeiten und zonenbezogene Funktions-/Ausfallnachweise |
| Z06 | P1 | Cisco und Fritz-Mesh absichern — offen | Z01/Z03; Rollout: Z02 | Modellgerechte Verwaltung, minimale Rechte und geprüfte Hostschlüssel; Portrollen und laufende/gespeicherte Konfiguration belegt; WLAN-/Gastpfade ohne Umgehung getestet |
| Z07 | P1 | Wiederholbare Deployments einführen — offen | Z01/Z02 | Alt-Synchronisationsskripte durch geprüfte Verfahren ersetzt; Versions-/Syntaxprüfung, Staging, atomare Aktivierung soweit möglich, getesteter Rückweg und Vorher/Nachher-Protokoll; erneuter Lauf erzeugt keine unbeabsichtigte Änderung |
| Z08 | P2 | Ausfälle und Drift erkennbar machen — offen | Z04–Z07 | Nutzbare Warnungen für DNS-/DHCP-/Internet-/Routerausfälle und Backupfehler; Ressourcengrenzen/Logrotation; Vergleich laufender und gewünschter Konfiguration; Ausfall und Wiederanlauf unter vereinbarten Bedingungen getestet |
| Z09 | P1 | Festen Dual-Stack-Anschluß, Domain und Tunnel einordnen — offen | Entwurf: Z01/Z03; Rollout: Z02/Z04/Z05 | Vodafone-Zuweisung und Weitergabe des /59 nachgewiesen; verfügbarer /64-Plan je Zone und Rückrouten belegt; öffentliche/interne DNS- und Tunnel-/Zielzuordnung für dfderp.jaylab.org geprüft; Zugangsschutz ohne direkten IPv4-/IPv6-Nebenpfad und Wiederanlauf getestet |

## Grundlage zu Z09

Die Betreiberangaben zu fester IPv4, statischem IPv6-Präfix, eigener Domain
und bestehendem `cloudflared`-Zugriff sind unter
[Internet, Domain und Tunnel](INTERNET-DOMAIN-TUNNEL.md) erfaßt. Die nachgereichte
Verbindungsanzeige klärt die Präfixlänge auf `/59`; offen bleiben Weitergabe,
Routen, aktive Filter und Tunnel-/Anwendungszuordnung. Z09 ist ein Prüf- und
Planungsziel und erteilt keine Freigabe für öffentliche Dienste oder DNS-Änderungen.

## Erster Arbeitsauftrag

Der Betreiber hat U01 am 1. November 2026 ausdrücklich zurückgestellt.
Vorrang hat Z05: Amazon-Music-Suche in der Android-App und Netflix sind im
normalen WLAN `papalapap` unzuverlässig; im Gast-WLAN funktioniert die Musiksuche
laut Betreiber. IPv6-Routen, Router Advertisements und DNS zunächst vergleichen.
Ein zeitlicher Zusammenhang oder dieser Vergleich allein beweist noch keine
IPv6-Ursache. Belegte Fehler gezielt mit Rückweg beheben und die Anwendungen
anschließend auf dem betroffenen Gerät prüfen.

Der [Vorschlag U01](ERSTER-UEBERARBEITUNGSSCHRITT.md) bleibt erhalten; seine
Sicherheitsbefunde sind durch die geänderte Reihenfolge nicht behoben.

## Nachweis zu Z00

Am 1. November 2026 bestanden alle fünf Skills den mitgelieferten
`skill-creator`-Validator. `scripts/Test-Workspace.ps1` prüfte Inventar,
Skill-/UI-Metadaten, lokale Verweise und PowerShell-Syntax erfolgreich.
Eine getrennte fehlerhafte Inventarkopie wurde wegen doppelter Geräte-IDs,
überlappender IPv4-Netze und unbelegter Portbestätigung abgewiesen.
Das TCP-Werkzeug unterschied einen offenen und einen geschlossenen lokalen
Testport, wies eine unbekannte Geräte-ID zurück und übersprang Geräte ohne
Adresse. Diese Nachweise betreffen die Werkzeuge, nicht die laufende Infrastruktur.

## Teilnachweis zu Z01

Administrative SSH-Zugänge zu den drei Proxmox-Hosts, DNS, Firewall und PBS
sind geprüft. Der [Einrichtungsstand](ZUGANGSEINRICHTUNG.md) dokumentiert die
Arbeitsprofile. Auch die drei Cisco-Switches sind nun mit bestätigten
Hostschlüsseln und CLI-Berechtigungsstufe 15 geprüft erreichbar. Beide Fritzboxen
melden über zertifikatsgebundenes HTTPS/TR-064 `BoxAdmin=readwrite`. Die
OG- und Keller-Repeater sind über geprüfte HTTPS-Websitzungen mit `BoxAdmin=2`
erreichbar; beide Testsitzungen wurden abgemeldet. Damit sind die Zugänge aller
13 inventarisierten Komponenten nachgewiesen. DNS ist CT 101 und
Firewall CT 103 auf proxmox2; PBS ist VM 115 auf proxmox3. Die sechs physischen
Ports waren zu diesem Zeitpunkt noch nicht zugeordnet. Die anschließende
lesende Aufnahme für [U01](ERSTER-UEBERARBEITUNGSSCHRITT.md) belegt nun die
lokalen Ketten von sechs NICs zu Bridges und Router-/DNS-LXC. Externe Gegenports,
Kabelwege und Isolation bleiben offen; Z01 bleibt deshalb in Arbeit.

## Abschluß einer Änderung

Den betroffenen Zielstatus, Belege, verbleibende Risiken und den nächsten Schritt
aktualisieren. Live-Ergebnisse mit Datum, Zielgerät und Konfigurationsstand
festhalten. Die [Änderungsvorlage](vorlagen/AENDERUNG.md) dient für Eingriffe mit
Auswirkung auf Routing, Namensauflösung, Verwaltung oder Verfügbarkeit.
