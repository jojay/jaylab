---
name: jaylab-switch-mesh
description: "Prüft Cisco-Kommandozeilenzugänge, physische Switchpfade und Fritzbox-/Repeater-Mesh im Jaylab. Verwenden für Portrollen, Verwaltungszugänge und WLAN-Segmentgrenzen."
---

# Cisco und Fritz-Mesh

Lies [Architektur](../../../docs/ARCHITEKTUR.md) und bei SSH-Aufträgen die
Cisco-Nachprüfung im [Zugangsbericht](../../../INFRASTRUKTUR-ZUGAENGE.md).
Inventarisierte Ziele sind `cisco16` (.10.1), `cisco8` (.10.2), `cisco162`
(.10.16); die abgekürzten Adressen gehören zu `192.168.10.0/24`.

## Cisco-Kommandozeile

Die Erstprüfung benötigte zielbezogen `-o HostKeyAlgorithms=+ssh-rsa`.
Der aktuelle Stand zu Betreiberabgleich, bestätigten Fingerabdrücken und
Anmeldungen steht in der [Zugangseinrichtung](../../../docs/ZUGANGSEINRICHTUNG.md)
und im Inventar. Bereits belegte Bestätigungen nicht erneut verlangen. Keine globale
Algorithmuslockerung, kein `StrictHostKeyChecking=no` und keine automatische
Übernahme eines per Netzscan gewonnenen Schlüssels.

Vor CLI- oder Automationsbefehlen Benutzer, Rechte, genaues Modell, Firmware
und CLI-Dialekt feststellen. Nicht von IOS, NETCONF, RESTCONF oder SSH-Exec
ausgehen. Erst lesend Version, Interfaces, Linkpartner, MAC-Tabelle, Verwaltung,
running/startup-Konfiguration und unterstützte Automationswege erheben.
Konkrete Befehle aus dem eingebauten Hilfesystem oder dem passenden Herstellerhandbuch
der ermittelten Version ableiten. Rohkonfigurationen können Geheimnisse enthalten.

Für Segmentierung über physische Pfade VLANs und Trunks nicht als stillschweigende
Lösung einsetzen. Prüfen, ob mehrere angeschlossene Zonen auf dem Switch oder
über Uplinks tatsächlich getrennt bleiben. Neue Management-ACLs und Portänderungen
erst nach Nachweis von Gegenport, Verwaltungsweg und unabhängigem Rückweg planen.

## Fritzbox und zwei Repeater

Die Kabel-Fritzbox stellt laut Betreiber Internet bereit; die zweite Fritzbox
gehört zum WLAN-Mesh. Die ermittelten Modelle und Adressen stehen im Inventar;
die tatsächlichen Mesh-Rollen und Uplinks sind weiterhin zu prüfen. Aus den
zahlreichen DHCP-Namen/MACs keine zusätzlichen physischen Repeater ableiten.

Erfasse Gerät/Version, Betriebsmodus, Mesh-Master/-Repeater, Funk- oder LAN-Uplink,
SSID/Gastzugang, IP-Zone, DHCP-/DNS-/RA-Rolle, Routen und Portfreigaben.
Gast-SSID und physisches Gastsegment nicht gleichsetzen. Den tatsächlichen Weg
eines WLAN-Clients zum Internet und zu internen Geräten prüfen, einschließlich
IPv6 und möglichem direktem Zugang zur Kabel-Fritzbox.

Belege die Port-/Mesh-Zuordnung im Inventar und den Einfluß auf Z03/Z06.
Firmwarewechsel oder Änderungen am Mesh sind eigene Betriebsänderungen;
im beauftragten Umfang mit `jaylab-deployment` vorbereiten und ausführen.
