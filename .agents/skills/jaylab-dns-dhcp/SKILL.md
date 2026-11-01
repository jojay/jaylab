---
name: jaylab-dns-dhcp
description: "Prüft und überarbeitet dnsmasq, DHCP, IPv6-RA und die Stubby-Resolverkette im Jaylab. Verwenden bei Namensauflösung, Adreßvergabe und Default-Router-Problemen."
---

# DNS, DHCP und IPv6-Router im Jaylab

Lies die relevanten [Befunde](../../../docs/BEFUNDE.md) sowie
`router/dnsmasq/dnsmasq.conf`, dessen eingebundene Dateien und bei Resolverfragen
`router/stubby/stubby.yml`, jeweils vom Repository-Stamm aus.
Laufende Konfiguration, Startparameter und Includes gesondert feststellen.

## Nicht offensichtliche Zusammenhänge

- dnsmasq nennt sechs logische Schnittstellen und `.6` als Dienstadresse;
  die Gateways sind `.3`. DNS-/DHCP-Server und tatsächlicher Router müssen
  deshalb nicht derselbe Netzraum sein.
- RA-Priorität und Lifetime können einen falschen Default-Router lange wirksam
  machen. Ermitteln, wer RA sendet, wer weiterleitet und welche Fritz-Geräte
  zusätzlich DHCP/RA anbieten. RA-Lifetime nicht als bloße DNS-Einstellung behandeln.
- ULA-Dokumentation und Konfiguration widersprechen sich. Der Dateibestand
  verwendet `fd38:21a1:1b97::/48`; die tatsächlichen Clientpräfixe erst aufnehmen.
  Weder ULA noch DHCP-Tags bestätigen Segmentisolation.
- dnsmasq nutzt derzeit laut Datei öffentliche DNS-Upstreams; die lokale
  Stubby-Anbindung ist auskommentiert. Stubby nennt dieselben Listeneradressen
  ohne gesonderten Port. Mit tatsächlichen Dienstzuständen und `ss -lntup`
  klären, ob ein Portkonflikt besteht, bevor eine Resolverkette geändert wird.
- Öffentliche DNS-Adressen in DHCP-Optionen sind keine garantierte geordnete
  Ausfallschaltung. Interne Namensauflösung und gewünschte DNS-Politik damit prüfen.

Nach Versionsermittlung je Zone Adreßbereich, Reservierungen, Router-/DNS-Optionen,
Leasezustand, Bindeadressen, Includes, DNSSEC, Uhrzeit und Resolverpfad prüfen.
DHCP-Neubezug von einem geeigneten Testclient beobachten, ohne den Verwaltungsclient
blind neu zu adressieren. DNS sowohl über UDP als auch TCP, interne A/AAAA/PTR,
externe Namen und Fehler-/Ausfallverhalten prüfen. RA, Default-Route und tatsächlichen
IPv6-Verkehr getrennt prüfen; DHCPv6 allein belegt keine Default-Route.

Kandidatenbestand mit `dnsmasq --test` gegen die vollständigen vorgesehenen
Includes prüfen. Auf bereitgestellte Pfade achten: Die lokale Hauptdatei bindet
absolute `/home/...`-Dateien ein. Nicht nur die Hauptdatei austauschen und dabei
alte Includes erfolgreich testen. Keine zweite produktive DHCP-/RA-Instanz
für einen Test starten.

Für Aktivierung `jaylab-deployment` lesen. Ergebnis sind belegte Zuständigkeiten,
eine eindeutige Resolverkette und die zonenbezogenen Abnahmetests für Z05.
