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
| [Inventar](inventory/infrastruktur.json) | Maschinenlesbare Geräte, Segmente und sechs noch zuzuordnende Ports |
| [Ziele](docs/ZIELE.md) | Prioritäten, Abhängigkeiten und überprüfbare Abschlußkriterien |
| [Befunde](docs/BEFUNDE.md) | Erste Risiken aus den Dateien; noch kein vollständiges Live-Audit |
| [Netzfreigaben](docs/NETZFREIGABEN.md) | Entwurf der Verkehrsregeln und ihrer Abnahme |
| [Betrieb](docs/BETRIEB.md) | Bestandsaufnahme, Deployment und Wiederherstellung |
| [Zugangsbericht](INFRASTRUKTUR-ZUGAENGE.md) | Messungen vom 31. Oktober und 1. November 2026 |

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

Mit `$jaylab-bestandsaufnahme` Ziel **Z01** bearbeiten: Zugänge nachweisen und
die sechs Ports von `proxmox2` bis zu Bridges, LXC-Schnittstellen, Switchports
und Fritz-Geräten verfolgen. Unabhängig davon können lokale Konfigurationen
gegen die Befunde geprüft werden. Produktive Änderungen folgen erst im Rahmen
eines entsprechenden Auftrags mit konkretem Rückweg.
