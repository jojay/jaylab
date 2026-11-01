---
name: jaylab-bestandsaufnahme
description: "Erhebt Zugänge, Proxmox-/LXC-Bestand und physische Netzpfade im Jaylab. Verwenden für Istaufnahme und Port-/Bridgezuordnung vor einem Umbau."
---

# Bestandsaufnahme im Jaylab

Lies [Architektur](../../../docs/ARCHITEKTUR.md),
[Inventar](../../../inventory/infrastruktur.json) und den für die Ziele relevanten
Teil des [Zugangsberichts](../../../INFRASTRUKTUR-ZUGAENGE.md).
Frühere Messungen sind datierte Belege, keine aktuelle Erreichbarkeitsgarantie.

- Proxmox2 hat laut Betreiber sechs physische Ports. Die sechs dnsmasq-Namen
  `enp1s0` bis `enp6s0` und die Adressen `.7` bis `.12` belegen keine
  physischen Ports oder zusätzlichen Nodes.
- Stelle je Ziel Transport, vertrauenswürdige Geräteidentität, Anmeldung,
  lesbare Daten und benötigte administrative Rechte getrennt fest. Bei fehlender
  Anmeldung mit unabhängiger Dateiprüfung weiterarbeiten; keine Kennwortversuche
  oder ungeprüfte Übernahme von Hostschlüsseln.
- Für TCP-Transport eignet sich das lokale Skript
  [Test-InfrastrukturZugang.ps1](../../../scripts/Test-InfrastrukturZugang.ps1).
  Es beweist keine Anmeldung oder Segmentisolation.

## Proxmox und LXC lesend aufnehmen

Nach erfolgreicher Anmeldung zunächst Version und tatsächliche Schnittstellen
ermitteln, etwa mit `pveversion -v`, `ip -br link`, `ip -br addr`, `ip route`,
`ip -6 route`, `bridge link`, `bridge vlan show`, `pct list` und `qm list`.
Nur mit passenden Rechten und vorhandenen Befehlen arbeiten. `bridge vlan show`
erfaßt auch einen unerwarteten VLAN-Bestand; es beauftragt keine VLAN-Einführung.
`/etc/network/interfaces` samt Includes sowie für tatsächlich ermittelte CT-IDs
`pct config ID` vergleichen. Geräte-MAC und wenn verfügbar Linkpartnerdaten
mit Verkabelung und Switchports abgleichen; keine Interfaces herunterfahren,
um ein Kabel zu identifizieren.

Ermittle den tatsächlichen Ort von Routing, NAT, nftables, dnsmasq und RA;
betrachte Host, Container-Netzräume und Proxmox-Firewall. LXC-Konfiguration,
Bridges, Privilegien, erforderliche Fähigkeiten, Startreihenfolge, Mounts und
Storage-Abhängigkeiten belegen. Nicht pauschal Privilegien erweitern.

Ergebnis ist pro Port die belegte Kette NIC/MAC → Bridge → LXC/Host-Schnittstelle
→ Gegenport → Zone einschließlich WAN- und WLAN-Nebenpfaden. Für jeden Wert
Quelle und Datum erfassen; unbestätigte Werte bleiben `null`/`false` im Inventar.
Sensible Rohdaten nur lokal ablegen. Ziele Z01/Z03 anhand tatsächlicher Belege
aktualisieren und die kleinste noch fehlende Information benennen.
