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
| Z01 | P0 | Bestand und Zugänge nachweisen — offen | keine | Geräteversionen, sichere Anmeldung und Rechte belegt; alle sechs Hostports mit MAC, Bridge, LXC/Host, Gegenport und Segment zugeordnet; WAN- und Mesh-Pfade erfaßt |
| Z02 | P0 | Rückweg und Sicherungen nachweisen — offen | Z01 für Live-Teile | Vom Änderungspfad unabhängige Konsole erreichbar; verschlüsselte/externe Sicherungen vorhanden; Router-/DNS-/Switch-Konfiguration und notwendige LXC-Daten testweise isoliert wiederhergestellt; RPO/RTO mit Betreiber festgelegt |
| Z03 | P0 | Segmentarchitektur ohne VLANs entscheiden — offen | Z01 | Physische Broadcast-Domänen und sechs-Port-Budget belegt; keine unbeabsichtigte Bridge oder Mesh-Umgehung; Entwurf und verbleibende Grenzen dokumentiert |
| Z04 | P1 | IPv4-/IPv6-Firewall überarbeiten — offen | Entwurf: Z01/Z03; Rollout: Z02 | Freigaben begründet; IPv4 und IPv6 geprüft; neue unerlaubte Verbindungen abgewiesen; nötige Rückwege und ICMPv6 funktionieren; keine pauschale interne Freigabe |
| Z05 | P1 | DNS, DHCP und RA zuverlässig machen — offen | Z01; Rollout: Z02/Z03 | Zuständigkeiten und Resolverkette eindeutig; keine Listenerkonflikte; interne Namen/PTR, DHCP-Neubezug, IPv6-Default-Router und Ausfallverhalten je Zone nachgewiesen |
| Z06 | P1 | Cisco und Fritz-Mesh absichern — offen | Z01/Z03; Rollout: Z02 | Modellgerechte Verwaltung, minimale Rechte und geprüfte Hostschlüssel; Portrollen und laufende/gespeicherte Konfiguration belegt; WLAN-/Gastpfade ohne Umgehung getestet |
| Z07 | P1 | Wiederholbare Deployments einführen — offen | Z01/Z02 | Alt-Synchronisationsskripte durch geprüfte Verfahren ersetzt; Versions-/Syntaxprüfung, Staging, atomare Aktivierung soweit möglich, getesteter Rückweg und Vorher/Nachher-Protokoll; erneuter Lauf erzeugt keine unbeabsichtigte Änderung |
| Z08 | P2 | Ausfälle und Drift erkennbar machen — offen | Z04–Z07 | Nutzbare Warnungen für DNS-/DHCP-/Internet-/Routerausfälle und Backupfehler; Ressourcengrenzen/Logrotation; Vergleich laufender und gewünschter Konfiguration; Ausfall und Wiederanlauf unter vereinbarten Bedingungen getestet |

## Erster Arbeitsauftrag

Z01 mit `jaylab-bestandsaufnahme` beginnen. Zunächst lesend NICs, Bridges,
LXC-Zuordnung, Routen und Switch-/Fritz-Uplinks erheben. Für unbekannte Geräte
die Angaben aus vertrauenswürdiger Konsole oder bestehender Verwaltung beziehen.
Wenn Anmeldungen noch fehlen, lokale Befunde weiter untersuchen und die genau
benötigte fehlende Information benennen. Keine Zuordnung aus `.7` bis `.12`
oder `enp1s0` bis `enp6s0` ableiten.

## Nachweis zu Z00

Am 1. November 2026 bestanden alle fünf Skills den mitgelieferten
`skill-creator`-Validator. `scripts/Test-Workspace.ps1` prüfte Inventar,
Skill-/UI-Metadaten, lokale Verweise und PowerShell-Syntax erfolgreich.
Eine getrennte fehlerhafte Inventarkopie wurde wegen doppelter Geräte-IDs,
überlappender IPv4-Netze und unbelegter Portbestätigung abgewiesen.
Das TCP-Werkzeug unterschied einen offenen und einen geschlossenen lokalen
Testport, wies eine unbekannte Geräte-ID zurück und übersprang Geräte ohne
Adresse. Diese Nachweise betreffen die Werkzeuge, nicht die laufende Infrastruktur.

## Abschluß einer Änderung

Den betroffenen Zielstatus, Belege, verbleibende Risiken und den nächsten Schritt
aktualisieren. Live-Ergebnisse mit Datum, Zielgerät und Konfigurationsstand
festhalten. Die [Änderungsvorlage](vorlagen/AENDERUNG.md) dient für Eingriffe mit
Auswirkung auf Routing, Namensauflösung, Verwaltung oder Verfügbarkeit.
