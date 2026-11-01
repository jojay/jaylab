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

Am 1. November 2026 antworteten alle drei Geräte über SSH; die Aushandlung
gelang mit zielbezogenem `-o HostKeyAlgorithms=+ssh-rsa`. Ihre beobachteten
Fingerabdrücke sind noch nicht unabhängig bestätigt. Keine globale
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
gehört zum WLAN-Mesh. Modelle und Zuordnung der zwei tatsächlichen Repeater
zu den zahlreichen DHCP-Namen/MACs müssen noch aufgenommen werden.

Erfasse Gerät/Version, Betriebsmodus, Mesh-Master/-Repeater, Funk- oder LAN-Uplink,
SSID/Gastzugang, IP-Zone, DHCP-/DNS-/RA-Rolle, Routen und Portfreigaben.
Gast-SSID und physisches Gastsegment nicht gleichsetzen. Den tatsächlichen Weg
eines WLAN-Clients zum Internet und zu internen Geräten prüfen, einschließlich
IPv6 und möglichem direktem Zugang zur Kabel-Fritzbox.

Belege die Port-/Mesh-Zuordnung im Inventar und den Einfluß auf Z03/Z06.
Firmwarewechsel oder Änderungen am Mesh sind eigene Betriebsänderungen;
im beauftragten Umfang mit `jaylab-deployment` vorbereiten und ausführen.
