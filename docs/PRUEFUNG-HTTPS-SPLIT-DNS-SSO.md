# Anwendbarkeit des HTTPS-/Split-DNS-/SSO-Plans

Prüfung vom 15. November 2026 zum
[Implementierungsplan](Implementierungsplan-Heimnetz-HTTPS-Split-DNS-SSO.md).
**Der Ansatz ist für Jaylab geeignet, aber noch kein unmittelbar ausführbarer
Deploymentstand.** Die vorhandene DNS-Infrastruktur reicht grundsätzlich aus.
Vor der Umsetzung sind Betriebsort und Adressen von Caddy, Grafanas
Wiederanlauf, die Bereitstellung der neuen Authentik-VM sowie die bestehende
öffentliche Proxmox-Route zu klären. Der Authentik-Teil wurde nach der
Betreiberklarstellung auf eine vollständige Neuinstallation berichtigt.
Zusätzlich wurden die festen Anschlußadressen, die IPv6-Präfixplanung und
die zugehörigen Abnahmetests ausdrücklich in den Plan aufgenommen.

## Aktuell belegter Bestand

| Gegenstand | Beleg bzw. Betreiberangabe | Bedeutung für den Plan |
| --- | --- | --- |
| Lokaler Resolver | CT 101 auf proxmox2, dnsmasq 2.91 aktiv, je Segment `.6` | Bestehenden Dienst weiterverwenden; Unbound ist für diesen Zweck nicht erforderlich |
| Verteilte IPv4-DNS-Server | Mehrere DHCP-Bereiche nennen lokale `.6` und `1.1.1.1`; Gäste nennen `8.8.8.8` und `1.1.1.1` | Der spätere lokale DNS-Pfad ist noch nicht überall gewährleistet |
| Arbeitsplatz | Ethernet-DNS `192.168.10.6` und `8.8.8.8`; WLAN-Konfiguration `.20.6` | Ein zusätzlicher öffentlicher Resolver kann die lokale Sicht umgehen; kein garantierter geordneter Rückfall |
| IPv6-RDNSS | dnsmasq kündigt `[fe80::]` an, Router-Lifetime der DNS-Schnittstellen 0 | Korrektur vom 1. November erhalten; Client-/Fritz-RA-Pfade weiter prüfen |
| Domain | Öffentliche NS `athena.ns.cloudflare.com` und `venkat.ns.cloudflare.com` | Cloudflare ist als autoritatives DNS belegt; DNS-01 mit passendem Modul grundsätzlich möglich |
| Feste öffentliche IPv4 | `109.91.25.25`, Betreiber-/Anbieterangabe aus Architektur und Inventar, aktuelle Zuweisung hier nicht nachgemessen | In WAN-/Nebenpfadprüfung aufnehmen; keine automatische direkte Webveröffentlichung |
| Statisches IPv6-Präfix | `2a02:908:c250:9d00::/59`, Betreiber-/Anbieterangabe; Delegation an `proxmox2` noch zu prüfen | 32 mögliche `/64` berücksichtigen, konkrete LAN-Zuordnung erst nach Routingnachweis |
| Öffentliche Dienstnamen | Grafana, ERPNext und `proxmox.jaylab.org` haben Cloudflare-A/AAAA und HTTPS-Records | Nicht nur A überschreiben; sonst können Browser weiter öffentliche Hinweise erhalten |
| Neue Zielnamen | `login.jaylab.org` und `pve.jaylab.org`: öffentlich NXDOMAIN für A, AAAA und HTTPS | Vorschläge sind noch keine existierenden Dienste; für DNS-01 ist ein öffentlicher Web-A-Eintrag nicht nötig |
| Split-DNS heute | Lokales DNS liefert für `grafana.jaylab.org` und `dfderp.jaylab.org` ebenfalls Cloudflare-Antworten | Gewünschter lokaler Webpfad besteht noch nicht |
| Tunnel | CT 124 auf proxmox2, `.40.241/32`, cloudflared 2026.10.0-1, aktiv, Start mit Token | Fernverwaltet; eine Änderung der alten lokalen `config.yml` ist nicht der nachgewiesene Verwaltungsweg |
| Zuletzt geladene Tunnelrouten | Journal-Konfiguration vom 12. November enthält ERPNext, Paperless, Grafana, ERPNext-Altstand und Proxmox | Bestehende Ressourcen vollständig erhalten bzw. ausdrücklich migrieren; keine Annahme „Proxmox ist schon nur intern“ |
| Grafana | CT 102 auf proxmox gestoppt; DNS `grafana.jaylab.local` zeigt auf `.40.248` | Backend, Version und Zertifikat an Port 3443 sind aktuell nicht abnehmbar |
| ERPNext | CT 106, `.40.106/32`, HTTP 80; installierter Code Frappe 16.56.0, ERPNext 16.55.0 | Tatsächlichen v16-Login und Social-Login-Callback prüfen; aktive Entra-Anmeldung noch nicht unabhängig bestätigt |
| Authentik | Laut Betreiber bislang keine Installation; Alias über k3s nach `.40.226` und vorbereitete Node-RED-OIDC-Werte vorhanden | Neuinstallation mit neuer Datenbank und neuen Clients; DNS-/OIDC-Reste beweisen keine alte Instanz |
| Node-RED/MQTT/Zigbee2MQTT | Neue Automatisierungs-CA und geprüfte Maschinenzugänge vorhanden | Browser-SSO darf diese Anbindungen nicht ersetzen oder unterbrechen |

Die abgekürzten Dienstadressen `.40.x` bedeuten `192.168.40.x`.
Ein Caddy-Betriebsort mit festgelegter Adresse, Ressourcen und Rückweg ist
im bisher geprüften Bestand nicht bestätigt. Daraus folgt nicht, daß nirgends
Caddy installiert ist. Die übrigen nicht aktiven Windows-Adapter und deren
voreingestellte IPv6-DNS-Werte beweisen keine tatsächlich benutzten Resolver.

Die gesonderte [LXC-/VM-Bewertung](LXC-ODER-VM-NEUE-DIENSTE.md) empfiehlt
Caddy nativ in einem unprivilegierten LXC und Authentik samt PostgreSQL in
einer eigenen Compose-VM. Der Betreiber hat diese Aufteilung übernommen;
sie ist nun im Implementierungsplan festgelegt. Die Bewertung enthält
Ressourcenmessungen und die Abgrenzung zwischen Herstellerweg und
Betriebsentscheidung für Jaylab.

## Vor einem Deployment zu ergänzen oder zu entscheiden

### 1. DNS: dnsmasq konkretisieren und die Auslieferung prüfen

Phase 1 kann mit dnsmasq ausgeführt werden. Seit Version 2.86 reicht eine
`address`-Regel allein nicht, um weitere Abfragetypen am öffentlichen DNS
vorbeizuhalten. Für jeden ausgewählten Dienstnamen zusätzlich eine passende
`local`-Regel vorsehen; nicht pauschal ganz `jaylab.org` lokal abschneiden.
Unbound mit `transparent` wäre eine mögliche Alternative, ist aber hier kein
notwendiger Umbau. Beide Verhaltensweisen sind dokumentiert:
[dnsmasq-Handbuch](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html),
[Unbound lokale Zonen](https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html).

Das Verhalten wurde mit der installierten dnsmasq-Version isoliert geprüft:
temporärer DNS-only-Prozeß auf `127.0.0.1:1053`, keine DHCP-/RA-Funktion,
keine Änderung produktiver Dateien. Eine `address`-Regel für den Pilotnamen
mit Dokumentationsadresse `192.0.2.123` und zusätzlicher `local`-Regel lieferte
über UDP und TCP jeweils A lokal, AAAA NODATA und HTTPS NODATA. Der andere
Zonenname `dfderp.jaylab.org` blieb öffentlich auflösbar. **8 von 8 Prüfungen
bestanden**, Testprozeß anschließend beendet. Die Dokumentationsadresse ist
keine freigegebene Caddy-Adresse.

Vor Phase 3 die tatsächlich empfangenen DHCP-/RA-Daten von Pilot-PC und
Mobilgerät messen. Die Gäste-Zone nicht stillschweigend auf interne Verwaltung
umschalten; für sie eine ausdrückliche DNS-/Zugriffsentscheidung treffen.
Öffentliche Upstreams des lokalen Resolvers für andere Namen sind von der
Verteilung öffentlicher Resolver direkt an Clients zu unterscheiden.
Die bisherigen IPv6-Korrekturen und physische Segmentierung ohne VLANs
bleiben erhalten.

### 2. Caddy und Pilot: erst ein tatsächlich verfügbares Ziel

Grafana ist ein geeigneter fachlicher Pilot, sobald sein Wiederanlauf
beauftragt und Backend/TLS geprüft sind. Der im Plan genannte Kurzname
`grafana.local` ist nicht die im Tunneljournal belegte Adresse; dort steht
`https://grafana.jaylab.local:3443`. Vorhandene Proxy-/TLS-Einstellungen nicht
aus dem gestoppten Container ableiten. Alternativ kann ein gesonderter
Testname ohne Fachdaten nach Kollisionsprüfung zunächst nur DNS und Caddy
abnehmen; das ersetzt nicht Grafanas spätere Funktionsprüfung.

Caddy-Dienst, persistenter Zertifikatsspeicher, feste interne Adresse,
Sicherung und Zugangsschutz sind noch konkret zuzuordnen. DNS-01 benötigt
keine eingehenden WAN-Freigaben. Der Cloudflare-DNS-Token muß separat mit
Zonenlese- und DNS-Änderungsrechten für `jaylab.org` bereitgestellt werden;
der laufende Tunnel-Token ist dafür kein Ersatz.
[Caddy DNS-01](https://caddyserver.com/docs/automatic-https),
[Cloudflare-Modul](https://github.com/caddy-dns/cloudflare).

Die Anbindung darf nicht pauschal Proxy-/IdP-Zugriff aus IoT oder Gästen auf
die Proxmox-Verwaltung öffnen. Quelle, Ziel, Port und Rückweg für IPv4 und
IPv6 vor einer späteren Netzänderung belegen. Ein neuer Reverse Proxy
stellt keine physische Segmentisolation her.

### 3. Tunnel: Fernverwaltung und vorhandene Proxmox-Veröffentlichung

Die zuletzt geladene Konfiguration enthält unter anderem:

| Öffentlicher Name | Geladenes Origin | TLS-Besonderheit |
| --- | --- | --- |
| `dfderp.jaylab.org` | `http://erpnext.jaylab.local` | Bisher HTTP zum internen Origin |
| `grafana.jaylab.org` | `https://grafana.jaylab.local:3443` | `noTLSVerify: true` |
| `paperless.jaylab.org` | `https://paperless.jaylab.local` | `noTLSVerify: true` |
| `dfderp-last.jaylab.org` | `http://erpnext-last.jaylab.local` | Altinstanz getrennt zuordnen |
| `proxmox.jaylab.org` | `https://proxmox.jaylab.local:8006` | `noTLSVerify: true` |

Diese Tabelle stammt aus dem bereinigt gelesenen Connectorjournal und ist
kein vollständiger Export aktueller Cloudflare-Access-Richtlinien. Öffentliche
A-/AAAA-/HTTPS-Antworten für Proxmox sind zusätzlich aktuell belegt. Ein
anonymer HTTPS-Aufruf aus dem Connector-Netzraum erhielt bei Proxmox, Grafana
und ERPNext jeweils Cloudflare-HTTP 403. Das unterscheidet weder WAF/Bot-Schutz
von Access noch beweist es die externe Anmeldung über Mobilfunk.

Der Plan verlangt Proxmox ausschließlich intern. Deshalb die bereits
bestehende öffentliche Route unter ihrem tatsächlichen Namen ausdrücklich
in den Migrationsumfang aufnehmen und erst nach geprüftem unabhängigem
Verwaltungsweg gezielt ändern. Der neue Name `pve.jaylab.org` beseitigt diese
Route nicht. Account-Zugang, Tunnelkennung und aktuellen Dashboardstand vor
jeder Änderung lesend bestätigen. Keine Änderungen allein in der alten
lokalen `config.yml` als Tunneldeployment behandeln.

Die im Plan vorgesehenen getrennten Origin-Namen, TLS-Namenprüfung und
Host-Header sind richtig; ein auf den Tunnel zurückauflösender öffentlicher
Name darf nicht zum Origin werden.
[Cloudflare-Origin-Dokumentation](https://developers.cloudflare.com/tunnel/troubleshooting/https-origins/).

### 4. Authentik: Neuinstallation, Issuer und Notzugänge

Die frühere Schlußfolgerung einer vorhandenen Authentik-Installation war aus
den DNS-/OIDC-Einträgen nicht ableitbar. Maßgeblich ist die Klarstellung des
Betreibers: **Es gibt bislang keine Authentik-Installation.** Phase 4 plant
deshalb nun verbindlich eine Neuinstallation in einer eigenen VM mit
PostgreSQL, Server, Worker, neuen Secrets, Signing-Keys, Benutzerkonten und
anwendungsspezifischen Clients. Eine Suche nach einer alten Datenbank und
eine Identitätsmigration entfallen.

`https://login.jaylab.org` ist der vorgesehene gemeinsame Name. Bei Node-RED
werden die vorbereiteten `.local`-Issuer- und Clientwerte durch die tatsächlich
neu registrierten Werte ersetzt. Die bestehenden unabhängigen Zugänge und
Maschinenanbindungen bleiben bis zur Abnahme erhalten. Lokales Proxyvertrauen,
MFA, minimale Rollen, Proxmox-Cluster, Node-RED, Zigbee2MQTT und die
Negativtests sind Bestandteil der Planung.

Native OIDC-Anbindung und Proxy-Forward-auth sind unterschiedliche Verfahren.
Für Anwendungen ohne OIDC kann ein eigener Single-application-Provider
geeignet sein; direkte Backend-Pfade müssen dann Teil der Abnahme sein.
Notzugänge und nichtinteraktive APIs bleiben getrennt erhalten.
Grundlagen: [authentik Proxyintegration](https://docs.goauthentik.io/install-config/reverse-proxy),
[Proxmox-Anbindung](https://integrations.goauthentik.io/hypervisors-orchestrators/proxmox-ve/),
[Forward auth](https://docs.goauthentik.io/add-secure-apps/providers/proxy/forward_auth/).

Die vorgesehenen 2 vCPU/4 GB sind eine Planungsgröße, kein Ressourcenbeleg.
Nach der Neuinstallation werden PostgreSQL und die zugehörigen
Konfigurationen/Secrets gesichert und ein isolierter Restore geprüft.
Diese zukünftige Wiederherstellbarkeit ist von der entfallenen Annahme
einer bereits existierenden Identitätsdatenbank zu unterscheiden.
[Offizielle Sicherungsanleitung](https://docs.goauthentik.io/sys-mgmt/ops/backup-restore).

### 5. Feste Anschlußadressen und IPv6-Präfix

Der ursprüngliche Plan erwähnte statische öffentliche Adressen nur pauschal
als für den Tunnel nicht erforderlich. Das war als Berücksichtigung der
[Architektur](ARCHITEKTUR.md) unvollständig. Der Plan nennt nun ausdrücklich
die feste IPv4 `109.91.25.25`, das statische Präfix
`2a02:908:c250:9d00::/59` und die davon getrennt zu behandelnde angezeigte
IPv6-Anschlußadresse `2a02:8070:a00::3e6a`.

Das `/59` enthält 32 `/64` von `…:9d00::/64` bis `…:9d1f::/64`. Die
tatsächlich nutzbaren LAN-Netze hängen von der noch zu belegenden Delegation
und den Routen zwischen Fritzbox, `proxmox2` und Router-LXC ab. Deshalb
werden keine Segmentpräfixe oder VM-IPv6-Adressen erfunden. Die bisherigen
ULA-Adressen und die Vorgabe physischer Trennung ohne VLANs bleiben bestehen.
Die separate Anschlußadresse ist keine vorgegebene Dienstadresse.

Für Weboberflächen bleibt der geplante externe Weg der bestehende Tunnel;
die öffentlichen DNS-Einträge werden nicht zusätzlich auf die feste IPv4
oder direkt auf Backend-GUA-Adressen gelegt. Caddy und die neue Authentik-VM
erhalten gesondert belegte LAN-Adressen. Eine stabile, im LAN geroutete GUA
kann dort als lokales AAAA-Ziel dienen, sobald Erreichbarkeit und Filterung
geprüft sind. Andernfalls bleibt der Dienst zunächst IPv4-basiert.

Die festen Anschlußangaben sind außerdem Prüfziele für direkte Nebenpfade:
IPv4-Portweiterleitungen und IPv6-Freigaben dürfen die beabsichtigte
Tunnel-/Anwendungsanmeldung nicht umgehen. Phase 0 enthält nun die
Bestandsprüfung, Phase 5 die gezielte externe Gegenprobe einschließlich
korrektem Hostnamen/SNI. Ein späterer direkter VPN-Endpunkt bleibt eine
gesonderte Planung. Die aktuelle öffentliche Adreßzuweisung wurde bei dieser
Dateikorrektur nicht neu gemessen; die Werte bleiben Betreiber-/Anbieterangaben.

### 6. Weitere Abnahmegrenzen

Proxmox-root-SSH ist nachgewiesen, eine neue `root@pam`-Websitzung mit
ausgefallenem IdP nicht. Eine erfolgreiche Shellanmeldung erfüllt diesen
Abnahmepunkt nicht. Für ERPNext die tatsächliche v16-Providerkonfiguration,
Benutzerzuordnung und API-Verbraucher vor einem SSO-Wechsel prüfen.
Der bestehende Entra-Login ist im Plan genannt, in dieser Prüfung jedoch
nicht authentifiziert nachgewiesen.
[Frappe Social Login Key](https://docs.frappe.io/framework/user/en/guides/integration/social_login_key).

Ein kontrollierter WAN-Ausfalltest sollte zunächst nur den Pilotclient
betreffen. Das physische Trennen des gemeinsam genutzten WAN-Uplinks ist
für diese Planprüfung nicht erfolgt. Eine lange Offline-Lauffähigkeit
braucht zusätzlich Betrachtung der Zertifikatserneuerung und sämtlicher
externen Login-/MFA-Abhängigkeiten.

## Empfohlene Reihenfolge für einen späteren Umsetzungsauftrag

1. Anschlußadressen und IPv6-Delegation abgleichen; Caddy-Betriebsort,
   Quell-/Zielpfade, feste LAN-Adresse und Zugang zur Cloudflare-Zone
   festlegen; bestehende öffentliche Proxmox-Route zuordnen.
2. Verfügbaren Pilotbackend bestätigen bzw. einen Testendpunkt ohne Fachdaten
   vorbereiten. Bestehende produktive Tunnelziele erhalten.
3. DNS-01 im getrennten Staging-Zustand, danach geprüftes Produktions-TLS.
4. dnsmasq-Überschreibung nur für den Pilotnamen und einen kontrollierten
   Pilotclient erproben; A/AAAA/HTTPS und Gegenprobe anderer Zonennamen.
5. Authentik vollständig neu mit PostgreSQL, Server und Worker installieren,
   neue Konten und Provider anlegen, anschließend Anwendung für Anwendung
   mit lokalem Notzugang und Negativtests anbinden. Die spätere Sicherung und
   isolierte Wiederherstellung der neuen Installation prüfen.
6. Erst danach Resolver-Verteilung und Tunnelrouten schrittweise umstellen
   und vom Mobilfunk sowie den vorgesehenen lokalen Quellzonen abnehmen.

Die Prüfung hat keine produktiven DNS-, Caddy-, IdP-, Tunnel- oder
Firewalländerungen aktiviert. Die vorausgegangene Zigbee2MQTT-Reparatur ist
im [eigenen Bericht](ZIGBEE2MQTT-ZUGANG-UND-EMPFANG.md) dokumentiert.
