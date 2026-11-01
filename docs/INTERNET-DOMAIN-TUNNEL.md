# Internetanschluß, öffentliche Adressen und Cloudflare-Tunnel

Stand: 1. November 2026. Die folgenden Anschluß- und Domainangaben stammen
vom Betreiber, einschließlich des übermittelten Vodafone-Textes und der
Verbindungsanzeige. Sie wurden im Rahmen dieser Ergänzung nicht am Anschluß
nachgemessen. Die Prüfplanung gehört zu [Z09](ZIELE.md).

## Bekannte Angaben

| Gegenstand | Angabe | Beleglage |
| --- | --- | --- |
| Kabelanbieter / Betriebsart | Vodafone, Dual Stack | Übermittelter Anbietertext: feste IPv4 und statisches IPv6-Subnetz |
| Feste öffentliche IPv4 | `109.91.25.25` | Betreiber und Anbietertext; aktuelle Zuweisung noch nicht gemessen |
| Angezeigtes IPv6-Präfix | `2a02:908:c250:9d00::/59` | Vom Betreiber übermittelte Verbindungsanzeige; statische Zuteilung laut Anbieter |
| Angezeigte IPv6-Adresse | `2a02:8070:a00::3e6a` | Separat vom Präfix angezeigte Anschlußadresse; keine Aussage über ihre dauerhafte Bindung |
| Verbindung seit | 05.10.2026, 04:37 Uhr | Wortlaut der Anzeige; Aufnahmezeit und Zeitzone nicht angegeben |
| Angezeigte IPv6-Gültigkeit | Jeweils `78310/78310s` für Adresse und Präfix | Momentaufnahme; kein Nachweis einer späteren Restlaufzeit |
| Optionale Anbieter-DNS-Server | `82.212.62.126`, `82.212.62.127` | Im Anbietertext angeboten; Nutzung im Heimnetz nicht festgestellt |
| Eigene Domain | `jaylab.org` | Betreiberangabe; Registrar und autoritative DNS-Verwaltung noch nicht aufgenommen |
| Zugriff über Cloudflare Tunnel | `dfderp.jaylab.org` mittels `cloudflared` | Betreiberangabe; konkrete Tunnel-/Zielzuordnung und Zugangsschutz noch nicht geprüft |

Die frühere Angabe `2a02:908:c250:9d00::1` ist eine einzelne Adresse innerhalb
des nun bekannten Präfixes. Daraus folgt weder eine Gatewayrolle noch eine
Zuweisung an ein bestimmtes Gerät. Maßgeblich für die Netzplanung ist `/59`.
Die separat angezeigte Anschlußadresse und das Präfix für nachgelagerte Netze
sind getrennt zu erfassen. Zeitlich begrenzte Gültigkeitsanzeigen allein
widerlegen die vom Anbieter zugesagte statische Zuteilung nicht.

## Nutzen für die Segmentierung

Das `/59` enthält rechnerisch `2^(64-59) = 32` Netze der Größe `/64`:
`2a02:908:c250:9d00::/64` bis `2a02:908:c250:9d1f::/64`. Damit steht genügend
Adreßraum für sechs getrennte LAN-Segmente und Reserven zur Verfügung.
Ein eigenes `/64` je LAN ist die Planungsgrundlage; die notwendige physische
Trennung ohne VLANs bleibt bestehen. Die IETF sieht auch für Heimnetze
Adreßraum für mehrere Subnetze vor: [RFC 6177](https://www.rfc-editor.org/rfc/rfc6177.html).

Vor der Vergabe muß geklärt werden, welchen Teil die Fritzbox selbst verwendet
und welchen Bereich sie an den Router auf `proxmox2` weiterdelegiert oder
mit einer nachgewiesenen Rückroute erreichbar macht. Das gesamte `/59` nicht
gleichzeitig an mehreren Schnittstellen ankündigen. Noch keine öffentlichen
Segmentpräfixe als aktiv oder verbindlich vergeben.

Die bestehenden ULA-Netze `fd38:21a1:1b97:*::/64` bleiben als Dateibestand
erhalten. Ihre Segmentnummern nicht einfach an `…:9d00` anhängen: beispielsweise
liegt `2a02:908:c250:9d30::/64` außerhalb des zugeteilten `/59`. ULA und globale
Adressen können im Entwurf nebeneinander berücksichtigt werden; beide brauchen
passende Routen, DNS-Antworten und Firewallregeln.

Die feste IPv4 erleichtert dauerhaft adressierbare, ausdrücklich geplante
Dienste. Sie begründet keine Zuweisung der öffentlichen Adresse an Proxmox
und keinen Wechsel des Fritzbox-Betriebsmodus. NAT, Transitnetz, Routen und
vorhandene Portfreigaben sind zuerst aufzunehmen.

## Zugriff auf dfderp.jaylab.org

Der bestehende Zugriff über `cloudflared` bleibt Grundlage der Planung.
Der Connector baut seine Verbindung zu Cloudflare ausgehend auf; darüber
fließt der Anwendungsverkehr in beide Richtungen. Für diesen Tunnel ist keine
eingehende Portfreigabe am Kabelanschluß nötig. Die feste öffentliche IP ist
keine Voraussetzung dafür: [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/).

Im Dateibestand steht `192.168.40.241 cloudflared` in
`router/dnsmasq/hosts`. Dieser Eintrag ist ein Suchhinweis, kein Nachweis,
daß genau dieser Connector `dfderp.jaylab.org` bedient. Internes Ziel,
Zielport, Anwendung, Tunnelkennung, Connector-Version und Betriebsform sind
noch aufzunehmen. Aus dem Namen `dfderp` keine konkrete Anwendung ableiten.

Der Tunnel allein belegt keine Benutzeranmeldung. Cloudflare Access und dessen
Prüfung am Connector oder Ziel sind gesondert konfigurierbar:
[Cloudflare-Anleitung zum Anwendungsschutz](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/).
Vorhandene Access-Regeln und die Anmeldung der Anwendung prüfen. Direkter
Zugriff auf das interne Ziel über öffentliche IPv4, IPv6 oder interne
DNS-Abkürzungen darf den vorgesehenen Zugangsschutz nicht umgehen.

Den Connector auf seine benötigten internen Ziele begrenzen. Für die
Tunnelverbindung nennt Cloudflare ausgehend Port `7844`, UDP bei QUIC und
TCP bei HTTP/2. Protokoll, Rückfallverhalten und aktuelle Zielbereiche vor einer
Regeländerung anhand der installierten Konfiguration prüfen; DNS und weitere
belegte Betriebsabhängigkeiten gesondert erfassen:
[Cloudflare-Firewallanforderungen](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-with-firewall/).

## Prüf- und Verbesserungsfolge

1. Am Kabelanschluß IPv4-Zuweisung, IPv6-Präfix, Fritzbox-Betriebsmodus,
   Präfixweitergabe, Routen und vorhandene Freigaben lesend aufnehmen.
   An jeder Zone aktuelle globale/ULA-Adressen, RA-Absender, DNS und Rückweg
   feststellen; Fritz-/WLAN-Nebenpfade zur Firewall berücksichtigen.
2. Auf dieser Grundlage je physisch getrenntem Segment ein verfügbares `/64`
   planen. Fritzbox, Router und dnsmasq brauchen eindeutige Zuständigkeiten
   für Delegation, RA, DNS und Default-Route. Verhalten bei Präfixerneuerung,
   Neustart und Ausfall prüfen.
3. IPv4- und IPv6-Filter gemeinsam entwerfen. Öffentliche IPv6-Adressen dürfen
   weder Verwaltung noch andere Zonen unbeabsichtigt erreichbar machen.
   Erlaubte und verbotene neue Verbindungen von echten Quellzonen und von
   außerhalb des Heimnetzes prüfen; notwendiges ICMPv6 erhalten.
4. Für `jaylab.org` autoritative DNS-Verwaltung und tatsächliche Einträge
   erfassen. `dfderp.jaylab.org` bis zum internen Dienst einschließlich TLS,
   Access-/Anwendungsanmeldung und direkter Nebenpfade verfolgen. Keine
   zusätzlichen A-/AAAA-Einträge auf die festen Anschlußadressen ableiten.
   Internes und öffentliches DNS mit bewußten, geprüften Antworten planen.
5. Connector-Start, DNS-/Router-/Anwendungsabhängigkeiten, Überwachung und
   Wiederanlauf untersuchen. Tunnel-Tokens und Zugangsdaten weder protokollieren
   noch ins Repository übernehmen; auch Prozeßargumente und Dienstdateien vor
   einer Ausgabe bereinigen. Rückweg und Sicherung vor einem späteren Rollout
   nach [Betrieb](BETRIEB.md) nachweisen.

Die Anbieter-DNS-Server sind eine Option für die Resolverplanung, kein Auftrag,
dnsmasq oder Stubby umzustellen. Der im Anbietertext genannte
[Vodafone-Weg für Reverse DNS](https://www.vodafone.de/formular-reverse-dns)
wird als Betreiberunterlage festgehalten. Ein PTR-Eintrag ist bei einem
tatsächlich geplanten Dienst gesondert zu bewerten; ein eigener Mailserver
ist bisher kein Ziel.

Diese Ergänzung ändert Dokumentation und Inventar. Die laufende Netz-, DNS-
und Tunnelkonfiguration wird damit nicht geändert.
