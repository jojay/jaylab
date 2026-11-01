---
name: jaylab-segmentierung
description: "Analysiert und überarbeitet physische Segmentierung und nftables im Jaylab einschließlich IPv6. Verwenden für Verkehrsregeln, Isolation und Firewallentwürfe ohne VLANs."
---

# Physische Segmentierung und Firewall

Lies [Architektur](../../../docs/ARCHITEKTUR.md), die relevanten
[Befunde](../../../docs/BEFUNDE.md) und
[Netzfreigaben](../../../docs/NETZFREIGABEN.md). Letztere sind ein Entwurf,
keine bereits abgenommene Liste einzelner Freigaben.

Ermittle vor einer Änderung den wirklichen Paketpfad: physischer Port, Bridge,
Host/Container-Netzraum, nftables-Hooks, Proxmox-Firewall und Rückroute.
Getrennte IP-Netze und DHCP-Tags ersetzen keine getrennten Broadcast-Domänen.
Verkehr auf gemeinsamem Layer 2 kann die Router-Forward-Regeln umgehen.
Halte am Architekturziel ohne VLANs fest; bei unzureichenden physischen Pfaden
die Grenze und mögliche physische Alternativen ausweisen.

## Prüfpunkte für diesen Bestand

- `router/nftables/nftables.nft` ist Dateibestand. Laufende Regeln mit Handles,
  Zählern, Adreßfamilien und Version vergleichen, etwa `nft -a list ruleset`.
- Breite interne Freigabe für `192.168.0.0/18`, Reihenfolge, NAT-Filtermischung
  und `ip protocol 22` prüfen. Regelwirkung aus dem vollständigen Hookpfad
  ableiten; ein einzelnes `accept` bestätigt keine Erlaubnis aller späteren Hooks.
- Die vorhandene `ip`-Tabelle bestätigt keine IPv6-Absicherung. `inet`/`ip6`,
  ICMPv6, Neighbor Discovery, RA, Präfixe und mögliche Fritz-Nebenpfade aufnehmen.
- Neue Verbindungen, etablierte Antworten, ungültige Zustände und Anti-Spoofing
  an tatsächlich bekannten Eingängen unterscheiden. Notwendige Discovery- und
  Druckerfreigaben auf belegte Quelle/Ziel/Dienste begrenzen.
- `flush ruleset` kann Regeln anderer Zuständigkeiten entfernen. Eigentum und
  Ladeverfahren festlegen, statt pauschal alle Tabellen zu ersetzen.

Entwickle aus tatsächlichem Bedarf eine ausdrückliche Freigabenmatrix und die
zugehörigen positiven/negativen Tests von echten Quellen jeder betroffenen Zone.
Kandidaten mit der Zielversion und `nft -c -f DATEI` prüfen. Syntaxprüfung beweist
keine Isolation; umgekehrt sind Timeouts ohne bekannte Dienstbereitschaft kein
hinreichender Nachweis der Filterwirkung.

Für eine beauftragte Aktivierung den Skill `jaylab-deployment` lesen. Keine
Live-Regeln im Rahmen einer reinen Analyse ändern. Z04 nur nach Nachweis der
benötigten Dienste und der verbotenen neuen Verbindungen abschließen.
