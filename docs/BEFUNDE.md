# Erste Befunde aus dem Dateibestand

Stand: 1. November 2026. Dies ist eine erste Durchsicht, kein vollständiges
Live-Sicherheitsaudit. Die folgenden Punkte sind im Repository sichtbar;
ob sie produktiv wirksam sind, muß anhand der laufenden Konfiguration geprüft werden.

| ID | Gewicht | Fundstelle | Befund und nächste Prüfung |
| --- | --- | --- | --- |
| B01 | hoch | `router/nftables/nftables.nft`, `chain forward` | Frühes `ip saddr 192.168.0.0/18 ip daddr 192.168.0.0/18 accept` erlaubt breit internen Verkehr in dieser Chain. Frühere Hooks können einzelne Pakete verwerfen; dennoch kein belastbarer Nachweis enger Segmentregeln. Vollständigen Paketpfad und Sollmatrix prüfen. |
| B02 | hoch | dieselbe Datei, `table ip filter` | Diese Tabelle betrifft IPv4. dnsmasq verteilt zugleich IPv6. Weitere aktive ip6-/inet-/bridge-Regeln und Proxmox-Firewall sind unbekannt; IPv6-Isolation gesondert nachweisen. |
| B03 | hoch | `router/nftables/synch*.sh` und dnsmasq/stubby `synch.sh` | Direktes Überschreiben, Neustarts, feste fremde Schlüsselpfade und fehlender zuverlässiger Abbruch; nftables-Skripte führen `conntrack -F` aus. Vor Deployment neu entwerfen. |
| B04 | hoch | `router/nftables/nftables-failsafe*.nft` | Dateien beginnen mit `/usr/sbin/fs`; weitere Inhalte sind ungeprüft. Der Dateiname ist kein Wiederherstellungsnachweis. Nicht als Rückweg verwenden. |
| B05 | hoch | `router/dnsmasq/dnsmasq.conf`, `ra-param` | Hohe RA-Priorität und lange Router-Lifetime bis 65535 konfiguriert. Ermitteln, welcher LXC RA sendet und ob er tatsächlich korrekt routet; Wahl und Ausfallzeit des IPv6-Default-Routers messen. |
| B06 | mittel | dnsmasq-Konfiguration und `router/stubby/stubby.yml` | dnsmasq nutzt öffentliche Upstreams; Stubby-Anbindung ist auskommentiert. Stubby nennt dieselben lokalen Adressen ohne abweichenden Port. Möglicher Listenerkonflikt, sofern beide Dienste dort laufen. Listener und gewünschte Resolverkette aufnehmen. |
| B07 | mittel | dnsmasq-Konfiguration und `README_ULA_IPv6.md` | README nennt `fd00:*`, Konfiguration `fd38:21a1:1b97:*`; Bereichs- und Sicherheitsbeschreibungen weichen ebenfalls ab. Dokumentation erst nach Istabgleich berichtigen. ULA allein beweist keine Isolation. |
| B08 | mittel | `router/nftables/nftables.nft`, SSH-Kommentar in `prerouting` | `ip protocol 22` prüft eine IP-Protokollnummer, keinen TCP-Zielport 22. Regeln auf beabsichtigte Semantik und übrige Filterpfade prüfen. |
| B09 | behoben: Zugänge | [Zugangsbericht](../INFRASTRUKTUR-ZUGAENGE.md) | Administrative Anmeldung für alle 13 inventarisierten Komponenten mit geprüften Hostschlüsseln bzw. bestätigten Zertifikaten nachgewiesen; siehe [Einrichtungsstand](ZUGANGSEINRICHTUNG.md). Portzuordnung, Netzpfade und weitergehende Absicherung bleiben eigene Prüfziele. |
| B10 | hoch | Betreiberangabe und dnsmasq-Schnittstellen | Sechs physische Ports stehen sechs logischen Segmenten und einem noch ungeklärten Internet-Uplink gegenüber. Vor Architekturänderung Portbudget und gemeinsame Layer-2-Pfade klären. |
| B11 | mittel | DHCP-Datei und Betreiberangabe | Mehrere Repeater-Namen und MACs im Bestand, laut Betreiber zwei Geräte. Aktuelle Geräteidentität und Mesh-Verkabelung aufnehmen, keine Gerätezahl aus MAC-Einträgen ableiten. |
| B12 | hoch | Live-Aufnahme per vertrauenswürdigem Clusterzugang | CT 101 (DNS) und CT 103 (Firewall) verwenden denselben Ed25519-Hostschlüssel. Getrennte Geräteidentitäten mit Rücksicht auf bestehende Clientbindungen herstellen. |

Die Durchsicht ändert keine dieser Konfigurationen. Bei weiteren Arbeiten
Beobachtung, Auswirkung, Gegenprüfung und Behebung getrennt dokumentieren.

Technische Referenzen für die Prüfung: [nft-Handbuch](https://netfilter.org/projects/nftables/manpage.html)
zu Adreßfamilien, Protokollausdrücken und Prüfmodus sowie
[dnsmasq-Handbuch](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html)
zu Syntaxprüfung, Listenern und Router Advertisements. Installierte Versionen
können andere Fähigkeiten besitzen; deren Handbuch zusätzlich prüfen.
