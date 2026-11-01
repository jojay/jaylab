# Jaylab: Regeln für Agenten

- Niemals gendern. Deutsche Texte in der Rechtschreibung von vor 1996 verfassen.
- Ziel ist ein sicheres, zuverlässiges und wiederherstellbares Heimnetz auf
  Proxmox/LXC mit dnsmasq, nftables und Cisco-Switches.
- `proxmox2` besitzt laut Betreiber sechs physische Ethernet-Ports und dient
  dem Routing. Segmentierung soll ohne VLANs erfolgen. Keine VLANs, Trunks oder
  gemeinsam gebrückten Vertrauenszonen als stillschweigende Lösung einführen.
- Internet kommt über eine Fritzbox Cable; eine zweite Fritzbox und zwei
  Fritz-Repeater gehören zum WLAN-Aufbau. Modelle und Verkabelung sind offen.
- Einstieg: [README.md](README.md). Architektur und Unsicherheiten stehen in
  [docs/ARCHITEKTUR.md](docs/ARCHITEKTUR.md), Ziele in
  [docs/ZIELE.md](docs/ZIELE.md), Geräte und Portbelegung in
  [inventory/infrastruktur.json](inventory/infrastruktur.json).
- Betreiberangabe, Dateibestand, gemessenen Zustand und Entwurf unterscheiden.
  Repository-Dateien sind kein Nachweis für die laufende Konfiguration.
  Offene Portzuordnungen, LXC-IDs, Benutzer und Gerätemodelle nicht erfinden.
- Bestehende Änderungen des Benutzers erhalten. Keine Geheimnisse, privaten
  Schlüssel, Tokens oder unbereinigten Konfigurationssicherungen einchecken;
  lokale Arbeitsdaten gehören nach `.local/`.
- Analyseaufträge erlauben lesende Diagnose. Dieser Workspace-Aufbau erteilt
  keine pauschale Erlaubnis für spätere Änderungen am laufenden Netz.
  Ein ausdrücklich beauftragtes Deployment innerhalb seines Umfangs ausführen,
  ohne dieselbe Erlaubnis erneut zu verlangen. Vorher konkrete Änderung,
  Prüfung und Rückweg nach [docs/BETRIEB.md](docs/BETRIEB.md) vorbereiten.
- Vor Routing-, Bridge-, Firewall- oder Switch-Änderungen den vom betroffenen
  Pfad unabhängigen Wiederherstellungszugang und den Rückweg nachweisen.
  Bei unbekannter Zuordnung nur die davon abhängige Änderung zurückstellen.
- IPv4 und IPv6 gemeinsam betrachten. Positive und negative Erreichbarkeit
  prüfen; ein offener TCP-Port bestätigt weder Anmeldung noch Isolation.
- Die vorhandenen `synch*.sh` und `nftables-failsafe*.nft` sind Altbestand,
  keine geprüften Deployment- oder Rückfallverfahren. Nicht ungeprüft ausführen.
- SSH-Hostschlüssel abgleichen, Zertifikate prüfen. Cisco-Kompatibilität mit
  `HostKeyAlgorithms=+ssh-rsa` nur zielbezogen verwenden; keine globale Lockerung.
- Nach lokalen Änderungen `pwsh -NoProfile -File scripts/Test-Workspace.ps1`
  ausführen. Das ersetzt keine Syntaxprüfung und Netzprüfung auf dem Zielsystem.

## Projektskills

Lies nur den zum Auftrag passenden Skill unter `.agents/skills/`:

| Auftrag | Skill |
| --- | --- |
| Zugänge, Proxmox/LXC-Bestand, Port- und Bridgezuordnung | `jaylab-bestandsaufnahme` |
| Segmentierung, nftables, IPv4/IPv6-Verkehrsregeln | `jaylab-segmentierung` |
| DNS, DHCP, RA und Stubby | `jaylab-dns-dhcp` |
| Cisco-CLI, Switchports, Fritzbox und WLAN-Mesh | `jaylab-switch-mesh` |
| Rollout, Rücknahme, Proxmox/LXC-Wartung und Wiederherstellung | `jaylab-deployment` |
