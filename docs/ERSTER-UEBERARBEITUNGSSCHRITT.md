# U01: Verwaltung gegenüber IoT und Gästen schützen

**Zurückgestellt auf Wunsch des Betreibers am 1. November 2026.** Vorrang hat
die IPv6-/DNS-Fehlerbehebung für Amazon Music und Netflix im WLAN `papalapap`
unter Z05. Dieser Vorschlag bleibt als späterer Arbeitsvorrat erhalten.

Stand: 1. November 2026. Ergebnis des Auftrags, einen ersten Überarbeitungsschritt
auszuarbeiten. **Priorität P0: Die vorhandenen Segmentgrenzen werden derzeit
nicht verläßlich durchgesetzt.** U01 ist ein ausgearbeiteter Arbeitsvorschlag
mit lesenden Live-Belegen; es wurde keine Netzänderung aktiviert.

## Entscheidungsgrundlage

Am 1. November 2026 ab 14:27 MEZ wurden über den bestätigten WSL-SSH-Zugang
auf `proxmox2` Schnittstellen, Bridges, CT-Konfigurationen, Routen, Weiterleitung,
aktive Filter und der Firewall-Ladepfad gelesen. Unbereinigte Ergebnisse bleiben
lokal unter `.local/analysis/first-step-*.json`. Netzraumfilter des DNS-LXC
wurden zusätzlich mit den Werkzeugen des Hosts über `nsenter` gelesen, weil
die Werkzeuge im Container fehlen. Keine Dienste neu gestartet, Regeln geladen,
Pakete installiert, Kabel getrennt oder Testgeräte umadressiert.

| Priorität | Live-Beobachtung | Bedeutung und Grenze des Nachweises |
| --- | --- | --- |
| P0 | CT 103: IPv4- und IPv6-Weiterleitung stehen auf `1`. Die einzige nftables-Tabelle ist `ip filter`; `INPUT` und `FORWARD` haben jeweils Policy `accept` und als erste Regel ein bedingungsloses `accept`. IPv6-Legacy-Filter sind ebenfalls leer. | In diesem Router-Netzraum wird weder der Zugang zum Router noch der weitergeleitete Verkehr eingeschränkt. Das ist weiter offen als die Repository-Hauptdatei. Filter anderer Geräte und Pfade sind damit nicht widerlegt. |
| P0 | `/etc/nftables.conf` in CT 103 enthält denselben offenen Aufbau samt NAT; `nftables.service` lädt diese Datei mit `/usr/sbin/nft -f`. | Ein Dienststart stellt den offenen Aufbau wieder her. Der falsche Shebang `/usr/sbin/fs` verhindert dieses explizite Laden mit `nft -f` nicht. Die Logregeln hinter den bedingungslosen Accept-Regeln liefern dort keine Treffer. |
| P0 | CT 101 erhält `2a02:908:c250:9d00::/64` auf `enp2s0` bis `enp6s0`. Dieselben fremden IPv6-Default-Router erscheinen auf mehreren Schnittstellen; sogar eigene Link-Local-Adressen anderer DNS-Schnittstellen tauchen als Default-Router auf. | Starker Hinweis auf segmentübergreifende RA-/Layer-2-Pfade; mehrere mögliche Rückwege beeinträchtigen auch die Zuverlässigkeit. Noch kein vollständiger Verkabelungsnachweis. |
| P0 | Die MAC `0c:c5:74:9a:eb:5b`, passend zur beobachteten Router-Link-Local-Adresse `fe80::ec5:74ff:fe9a:eb5b`, wird in der Bridge-Lerntabelle über alle sechs physischen NICs gelernt. | Die getrennten Host-Bridges allein belegen keine getrennten externen Broadcast-Domänen. Gerät, Switchpfade und mögliche Schleifen sind noch zuzuordnen. |
| P0 | CT 101 hat keine nftables-Regeln und keine IPv4-/IPv6-Legacy-Regeln. SSH lauscht auf `0.0.0.0:22` und `[::]:22`; DNS auch auf den erhaltenen globalen IPv6-Adressen. | Dieser an alle sechs Bridges angeschlossene Dienst braucht eigenen Verwaltungsschutz. Ein Router-Forward-Filter schützt lokale Eingänge des DNS-LXC nicht. Internet-Erreichbarkeit und offene Rekursion sind damit noch nicht nachgewiesen. |
| P1 | `proxmox2` trägt `192.168.10.7` bis `.12` und entsprechende Admin-ULA-Adressen auf sechs verschiedenen Bridges. Seine IPv4-Default-Route führt über `vmbr1` zu `192.168.10.3`; das Firewall-Admininterface hängt dagegen an `vmbr0`. | Verwaltungs- und Rückwege sind mehrfach angebunden. Die Proxmox-Hostfilter sind allerdings aktiv und enthalten IPv4-/IPv6-Drop-Regeln. Der Host ist deshalb nicht pauschal als ungeschützt einzustufen. |

Die Hostfilter enthalten außerdem Clusterfreigaben für `.10.8` und andere
Clusteradressen. Die zusätzlichen Hostadressen dürfen deshalb nicht als erste
Maßnahme entfernt werden. Vor einer solchen Bereinigung müssen Clusterpfade,
Quorum und Wiederherstellung getrennt geprüft werden.

## Bereits belegter lokaler Paketpfad

Die folgende Tabelle beschreibt den laufenden Host und die LXC-Anschlüsse.
Die Zonenbezeichnungen folgen den LXC-Adressen; Gegenports, Kabelbeschriftung
und tatsächliche externe Trennung sind weiterhin offen.

| Physische NIC auf proxmox2 | MAC | Host-Bridge | Router CT 103 | DNS CT 101 | Vorgesehene Zone |
| --- | --- | --- | --- | --- | --- |
| enp1s0 | 20:7c:14:a0:e2:ee | vmbr0 | enp1s0, 192.168.10.3 | enp1s0, 192.168.10.6 | Admin |
| enp2s0 | 20:7c:14:a0:e2:ef | vmbr1 | enp2s0, 192.168.20.3 | enp2s0, 192.168.20.6 | General / Internetpfad |
| enp3s0 | 20:7c:14:a0:e2:f0 | vmbr2 | enp3s0, 192.168.30.3 | enp3s0, 192.168.30.6 | Familie |
| enp4s0 | 20:7c:14:a0:e2:f1 | vmbr3 | enp4s0, 192.168.40.3 | enp4s0, 192.168.40.6 | IoT |
| enp5s0 | 20:7c:14:a0:e2:f2 | vmbr4 | enp5s0, 192.168.50.3 | enp5s0, 192.168.50.6 | Medien |
| enp6s0 | 20:7c:14:a0:e2:f3 | vmbr5 | enp6s0, 192.168.60.3 | enp6s0, 192.168.60.6 | Gäste |

CT 103 besitzt zusätzlich `enp2s1` mit `192.168.1.3/29` auf `vmbr1` und
`enp2s2` mit `192.168.2.3/28` auf `vmbr2`. Diese sind keine zusätzlichen
physischen Ports und keine getrennte DMZ. Die aktive IPv4-Default-Route des
Routers ist `192.168.20.5` über `enp2s0`. Im Router wurde keine IPv6-Default-Route
gefunden, während der DNS-LXC mehrere besitzt. Host und DNS-LXC haben selbst
IPv4-/IPv6-Weiterleitung `0`; die beobachtete Routerrolle liegt in CT 103.

## Erste Änderungseinheit

Gewünschtes Ergebnis: **Ein Gerät aus IoT oder Gäste kann keine neue
Verwaltungsverbindung zum Adminnetz, Router oder DNS-LXC aufbauen – weder über
IPv4 noch über IPv6 oder einen gemeinsamen Switchpfad.** Anmeldung vom
festgelegten Verwaltungsrechner, DNS/DHCP und die benötigte Internetnutzung
funktionieren weiterhin. Dies ist die erste Grenze; die vollständige
Freigabenmatrix für alle Zonen folgt anschließend.

1. **Betroffene Kabel- und Verwaltungswege belegen.** Zuerst die Admin-, IoT-,
   Gast- und Fritz-Uplinks anhand Cisco-Portstatus, MAC-/Nachbartabellen und
   Verkabelung zuordnen. Klären, wie derselbe RA-Absender an alle sechs NICs
   gelangt. Bei gemeinsamem Layer 2 die betroffenen Zonen physisch trennen;
   ein gemeinsamer ungetrennter Switch darf die Grenze nicht wieder verbinden.
   Eine konkrete Umsteckliste setzt die Gegenportzuordnung voraus. Keine VLANs
   als Ersatz für die vereinbarte physische Trennung einführen.
2. **Rückweg herstellen und ausprobieren.** Die Konsole des betroffenen Hosts
   muß über einen vom geänderten Netzpfad unabhängigen Weg bedienbar sein.
   Darüber CT 101/103 erreichen können. Eine zweite SSH-Sitzung über denselben
   Switch oder `pct exec` über einen danach unerreichbaren Host genügt nicht.
   Aktive und persistente Netz-/Filterkonfigurationen sowie die nötigen
   CT-Daten sichern; Sicherung außerhalb des betroffenen Hosts verfügbar halten.
3. **Begrenzten Filterkandidaten ausarbeiten.** In CT 103 neue Verbindungen aus
   den nachgewiesenen IoT-/Gast-Eingängen zu Adminzielen im Forward-Pfad und
   zur Routerverwaltung im Input-Pfad sperren. Quelle, Eingang und Ziel
   gemeinsam prüfen; eine bloße Absenderadresse ist kein Zonenbeweis. IPv4,
   ULA, globale und Link-Local-Adressen berücksichtigen. Den direkt an die
   Zonen angeschlossenen CT 101 gesondert gegen Verwaltungszugriffe absichern;
   seine DNS-/DHCP-Funktion muß erreichbar bleiben.
4. **Regeln und Ladeverfahren getrennt prüfen.** Als Kandidat eignen sich
   eigens verwaltete `inet`-Tabellen, etwa `jaylab_admin_guard` in CT 103 und
   `jaylab_dns_guard` in CT 101. Das ist ein Entwurf, noch kein vorhandener
   Regelsatz. In CT 101 fehlt derzeit das `nft`-Werkzeug; dessen Bereitstellung
   und die Startintegration gehören zum konkreten Kandidaten. Bestehendes NAT
   und fremde Proxmox-Regeln erhalten. Kein globales
   `flush ruleset`, kein Conntrack-Löschen und kein unbesehener Reload der alten
   Konfiguration, der die neue Tabelle wieder entfernen würde. Nötige Dienste
   und Firewall-Zuständigkeiten vor der endgültigen Regeldatei festlegen.
5. **Im vereinbarten Änderungsfenster aktivieren und abnehmen.** Vorher
   Syntaxprüfung mit der Zielversion und einen getesteten zeitgesteuerten
   Rücklauf vorbereiten. Kabeländerung und Filteränderung als getrennte,
   einzeln rücknehmbare Teilschritte ausführen. Persistenz mit demselben
   geprüften Kandidaten herstellen; danach Wiederladeverhalten prüfen.

Vor der Aktivierung fehlen noch die Gegenport-/Umsteckliste, ein geprüfter
unabhängiger Konsolenweg, die konkreten Verwaltungsquellen und erforderlichen
Dienste sowie Prüfclients in IoT und Gäste. Deshalb enthält dieser Vorschlag
noch keine zum Laden bestimmte Regeldatei. Diese fehlenden Angaben verhindern
die Aktivierung, nicht die hier abgeschlossene Priorisierung und Ausarbeitung.

## Abnahme und Rücknahme

| Tatsächliche Quelle | Test | Erwartung |
| --- | --- | --- |
| Festgelegter Verwaltungsrechner | Neue SSH-/HTTPS-Verbindung zu den betroffenen Verwaltungsdiensten | Funktioniert über den dokumentierten Pfad |
| Prüfclient in IoT und gesondert in Gäste | Neue Verbindung zu einem nachweislich lauschenden Admin-Verwaltungsdienst, jeweils IPv4 und IPv6 | Gesperrt; Filtertreffer oder entsprechender Pfadnachweis vorhanden |
| Dieselben Prüfclients | Router- und DNS-Verwaltung auch über deren zonenlokale, globale und Link-Local-Adressen | Gesperrt; DNS über die vorgesehenen Adressen bleibt nutzbar |
| Dieselben Prüfclients | Versuch eines direkten Layer-2-Nebenpfades mit kontrolliertem Prüfgerät | Kein Umgehen der Grenze durch eigenes Adreßsetzen oder gemeinsamen Switchpfad |
| Je betroffene Zone | DHCP-Neubezug, DNS, erforderliches ICMPv6 und Internet | Funktioniert; genau der vorgesehene Router/Präfix wird gelernt |
| Bestehender Anwendungspfad | dfderp.jaylab.org mit vorgesehener Anmeldung | Funktioniert weiterhin; Connector-/Zielzuordnung vorher feststellen |
| Cluster und Konsole | Clusterzustand, unabhängiger Konsolenzugang und Rücknahmeprobe | Keine Verschlechterung; Wiederherstellung nachgewiesen |

Ein Timeout allein und ein Test nur vom Adminrechner schließen die Abnahme
nicht ab. Fehlendes IPv6 am Prüfclient gilt nicht als bestandener IPv6-Test.
Vorher/Nachher mit neuen Verbindungen prüfen; vorhandene Sitzungen getrennt
betrachten. Eine lokale Syntaxprüfung ersetzt diese Tests nicht.

Rücknahme vorab je Teilschritt genau festlegen: frühere Kabelzuordnung
wiederherstellen; nur die neu eingeführte eigene Filtertabelle entfernen und
den zugehörigen persistenten Ladebestand zurücknehmen. Die vorhandenen
NAT-/Proxmox-Regeln dabei nicht ersetzen. Rücknahme bei Verlust der Verwaltung,
DNS-/DHCP-Ausfall, Clusterstörung oder fehlgeschlagener erforderlicher
Nutzfunktion. Der alte Zustand stellt die Betriebsfähigkeit, aber auch die
hier belegte Schutzlücke wieder her. Bis zur erfolgreichen Abnahme bleibt
der unabhängige Rückweg bereit.

## Anschließende Arbeit

Nach dieser ersten Grenze die übrigen Zonen nach [Freigabenmatrix](NETZFREIGABEN.md)
einschränken, DNS-/RA-Zuständigkeiten bereinigen und das öffentliche `/59`
gezielt weitergeben. Die mehrfachen Host-/Clusteradressen und alten
DMZ-Anschlüsse werden als eigene Änderung behandelt. Cloudflare-Tunnel und
öffentliche DNS-Ziele bleiben während U01 erhalten.

Technische Grundlage: Das [nftables-Handbuch](https://netfilter.org/projects/nftables/manpage.html)
unterscheidet lokale Eingänge und Weiterleitung sowie die Adreßfamilien
`ip`, `ip6` und `inet`; `inet` kann beide IP-Versionen behandeln. Für die
Durchführung gelten [Betrieb und Wiederherstellung](BETRIEB.md).
