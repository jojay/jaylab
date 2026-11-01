# Jaylab

Dieser Workspace begleitet die schrittweise Überarbeitung des bestehenden
Heimnetzes hinsichtlich Sicherheit und Zuverlässigkeit. Proxmox/LXC, dnsmasq,
nftables, programmierbare Cisco-Switches und das Fritz-WLAN bleiben der Ausgangspunkt.
Die Segmentierung soll mit getrennten physischen Ethernet-Pfaden ohne VLANs erfolgen.

## Einstieg

| Datei | Zweck |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Dauerhafte Arbeitsregeln für Agenten |
| [Architektur](docs/ARCHITEKTUR.md) | Betreiberangaben, Dateibestand, Grenzen und offene Fragen |
| [Internet, Domain und Tunnel](docs/INTERNET-DOMAIN-TUNNEL.md) | Feste Vodafone-Adressen, IPv6-/59, jaylab.org und Prüfplanung für cloudflared |
| [Inventar](inventory/infrastruktur.json) | Maschinenlesbare Geräte, Segmente und sechs noch zuzuordnende Ports |
| [Ziele](docs/ZIELE.md) | Prioritäten, Abhängigkeiten und überprüfbare Abschlußkriterien |
| [Erster Überarbeitungsschritt](docs/ERSTER-UEBERARBEITUNGSSCHRITT.md) | Live belegter Handlungsbedarf und U01: Verwaltung gegenüber IoT und Gästen schützen |
| [Befunde](docs/BEFUNDE.md) | Erste Risiken aus den Dateien; noch kein vollständiges Live-Audit |
| [Netzfreigaben](docs/NETZFREIGABEN.md) | Entwurf der Verkehrsregeln und ihrer Abnahme |
| [Betrieb](docs/BETRIEB.md) | Bestandsaufnahme, Deployment und Wiederherstellung |
| [Zugangsbericht](INFRASTRUKTUR-ZUGAENGE.md) | Messungen vom 31. Oktober und 1. November 2026 |
| [Zugangseinrichtung](docs/ZUGANGSEINRICHTUNG.md) | Geprüfte Verwaltungszugänge zu allen 13 inventarisierten Komponenten |

Die fünf projektspezifischen Skills liegen in `.agents/skills/`. Diese Ablage
entspricht dem von der [offiziellen OpenAI-Dokumentation beschriebenen Aufbau](https://developers.openai.com/blog/skills-agents-sdk).
Ob die laufende Sitzung neu hinzugefügte Skills sofort in ihrer Auswahl zeigt,
muß in der jeweiligen Sitzung geprüft werden; die Dateien sind auch unmittelbar lesbar.

## Lokale Prüfung

```powershell
pwsh -NoProfile -File scripts/Test-Workspace.ps1
```

Diese Prüfung arbeitet ohne Netzverbindungen. Sie prüft Inventarkonsistenz,
Skill-Metadaten, Verweise und PowerShell-Syntax. Sie bewertet keine laufende Firewall.

Für eine ausdrücklich gewünschte, lesende TCP-Prüfung der inventarisierten Ziele:
In PowerShell 7 vom Repository-Stamm aus ausführen.

```powershell
& ./scripts/Test-InfrastrukturZugang.ps1 -DeviceId cisco16,cisco8,cisco162
```

Ausgabe ist ein JSON-Protokoll mit UTC-Zeit, Ziel und Ergebnis. Das Skript
verwendet keine Zugangsdaten, verändert keine Geräte und bestätigt keine Anmeldung.
Ein Netzverbot der Ausführungsumgebung ist kein Nachweis für einen Gerätefehler.

## Nächster Arbeitsschritt

Der Betreiber hat [U01](docs/ERSTER-UEBERARBEITUNGSSCHRITT.md) zurückgestellt.
Aktuell hat **Z05** Vorrang: IPv6 und DNS für die unzuverlässige Amazon-Music-Suche
und Netflix im WLAN `papalapap` untersuchen und gezielt berichtigen. Der
funktionierende Zugriff im Gast-WLAN dient als Vergleich. Der Zugangsteil von
Z01 und die lokale NIC-/Bridge-/LXC-Zuordnung sind nachgewiesen; die externen
Netzpfade bleiben teilweise offen. Z09 behandelt weiterhin den festen
Dual-Stack-Anschluß und den bestehenden Cloudflare-Tunnel.
