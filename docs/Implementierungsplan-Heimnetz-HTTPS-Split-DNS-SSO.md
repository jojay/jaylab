# Implementierungsplan für HTTPS, Split-DNS und SSO im Heimnetz

## Auftrag für Codex

> Setze diesen Plan phasenweise um. Beginne mit der Bestandsaufnahme im Projektordner und ermittle, welche Systeme du von deiner Umgebung aus erreichen kannst. Verwende die vorhandene Infrastruktur und übernimm bestätigte Werte aus der laufenden Konfiguration. Ermittle vor jeder Umstellung den Istzustand, den konkreten Konfigurationsunterschied und den passenden Rückweg. Arbeite zuerst an einem Pilotgerät. Prüfe nach jedem Schritt die angegebenen Abnahmekriterien und protokolliere die Ergebnisse. Wenn dir der Zugriff auf ein System fehlt, bereite die genaue Änderung samt Prüfkommando für dieses System vor und fahre mit den unabhängigen Schritten fort.

Ziel ist, daß Webanfragen und die zugehörigen DNS-Abfragen im Heimnetz lokal bleiben. Weboberflächen bekommen automatisch erneuerte TLS-Zertifikate von Let’s Encrypt. Der vorhandene Cloudflare Tunnel dient dem gezielten Fernzugriff. authentik übernimmt die zentrale Anmeldung für unterstützte Dienste.

Für den Beginn einer neuen Umsetzungssitzung die
[Übergabe mit Entscheidungen und offenen Voraussetzungen](UEBERGABE-HTTPS-SPLIT-DNS-SSO.md)
lesen. Frühere Messungen vor einem Eingriff erneut bestätigen.

## Sollzustand

| Name | Ziel im lokalen DNS | Ziel im öffentlichen DNS | Anmeldung |
|---|---|---|---|
| `grafana.jaylab.org` | Caddy, Port 443 | Vorhandene Tunnelroute, falls Grafana weiterhin von außen benötigt wird | authentik über Generic OAuth |
| `login.jaylab.org` | Caddy, Port 443 | Nur veröffentlichen, wenn externe OIDC-Anmeldungen oder die Anbindung an Cloudflare Access gebraucht werden | Lokales authentik-Konto |
| `dfderp.jaylab.org` | Caddy, Port 443 | Bestehenden Eintrag und Tunnelroute erfassen und bei Bedarf beibehalten | Bestehende Anmeldung, danach authentik mit Testkonto |
| `pve.jaylab.org` | Proxmox-Knoten, Port 8006 | Kein öffentlicher Dienst-Eintrag und keine Tunnelroute | Proxmox-Realm für authentik, `root@pam` als lokaler Notzugang |

Die Namen für Grafana und Proxmox sind Vorschläge. `jaylab.local` kann parallel als vorhandene Gerätenamensdomäne dienen. Verwende für HTTPS den Namen aus der Tabelle, der zum Zertifikat paßt.

### Festgelegte Betriebsformen

Die [LXC-/VM-Bewertung](LXC-ODER-VM-NEUE-DIENSTE.md) wurde vom Betreiber
übernommen. Für die Umsetzung gelten folgende Entscheidungen:

| Bestandteil | Betriebsform | Anfängliche Dimensionierung |
|---|---|---|
| Caddy mit Cloudflare-DNS-Modul | Eigener Debian-LXC, `unprivileged: 1`, nativer systemd-Dienst ohne Docker | 1 CPU-Kern, 1 GiB RAM, 8 GiB verwaltetes Root-Dateisystem |
| Authentik-Server, Worker und PostgreSQL | Gemeinsam in einer eigenen Linux-VM mit Docker Compose | 2 vCPU, 4 GiB RAM, etwa 32 GiB virtuelle Platte |
| Authentik-Outpost | Zunächst eingebetteter Outpost der Authentik-Installation | Kein zusätzlicher Gast |
| Lokales DNS | Bestehenden dnsmasq-LXC weiterverwenden | Kein neuer Unbound-Gast |

Die Größen sind Startwerte und vor Bereitstellung gegen den aktuellen
Ressourcenbestand zu prüfen. Caddy und Authentik bleiben getrennte Gäste.
`proxmox` oder `proxmox3` anhand der dann belegten Ressourcen und Rückwege
auswählen; den Routerhost `proxmox2` für diese neuen Gäste nicht vorsehen.
VM-/CT-IDs und LAN-Adressen erst nach aktueller Belegungsprüfung vergeben.

Für die neuen Gäste zunächst lokalen Proxmox-Speicher und eine gesonderte
Sicherung vorsehen. Die bei der Bewertung gemessenen IPv6-iSCSI-Zeitüberschreitungen
sind kein geprüfter Betriebsweg für die neuen Anwendungen. Bestehende
Storage-Konfiguration dabei nicht beiläufig ändern. Eine Sicherung außerhalb
des jeweiligen Hosts und ein isolierter Restore bleiben erforderlich.

### Feste Anschlußadressen und IPv6-Präfix berücksichtigen

Die [Architektur](ARCHITEKTUR.md) und die
[Anschlußdokumentation](INTERNET-DOMAIN-TUNNEL.md) nennen folgende
Betreiber-/Anbieterangaben. Ihre aktuelle Zuweisung und Weiterleitung sind
vor einem Deployment gesondert zu messen:

| Angabe | Wert | Rolle in diesem Plan |
|---|---|---|
| Feste öffentliche IPv4 | `109.91.25.25` | Anschlußadresse für die Prüfung direkter WAN-Zugriffe; mögliche spätere Adresse eines gesondert beauftragten VPN-Endpunkts |
| Statisches IPv6-Präfix | `2a02:908:c250:9d00::/59` | Adreßraum für geroutete LAN-Netze und Prüfung direkter IPv6-Nebenpfade |
| Separat angezeigte IPv6-Anschlußadresse | `2a02:8070:a00::3e6a` | Anschlußangabe mit ungeklärter genauer Rolle; keine vorgegebene Caddy-, Authentik- oder Gatewayadresse |

Das `/59` enthält 32 `/64`-Netze von `2a02:908:c250:9d00::/64` bis
`2a02:908:c250:9d1f::/64`. Erst die tatsächlich nachgewiesene Delegation bzw.
Route von der Fritzbox zu `proxmox2` entscheidet, welche davon für die
physisch getrennten LAN-Segmente verwendet werden können. Bestehende ULA-
Adressen erhalten; keine VLANs einführen und dasselbe Präfix nicht ungeprüft
über mehrere Vertrauenszonen verteilen. Die alten Segmentnummern nicht
einfach in den öffentlichen Präfix übernehmen: `…:9d30::/64` liegt außerhalb
dieses `/59`.

Für den vorgesehenen Webzugriff bleibt Cloudflare Tunnel der Fernzugangsweg.
Dafür und für ACME DNS-01 sind keine eingehenden WAN-Freigaben für 80, 443
oder 8006 nötig. Öffentliche Webnamen deshalb nicht zusätzlich auf
`109.91.25.25` oder globale Backend-IPv6-Adressen zeigen lassen. Intern zeigen
sie auf Caddys nachgewiesene LAN-Adressen; für einen Proxmox-Direktzugang auf
die dafür festgelegte Verwaltungsadresse. Feste LAN-Adressen der neuen Gäste
sind getrennt von den öffentlichen Anschlußangaben zu vergeben.

Die festen Adressen sind damit Teil der Netz- und Sicherheitsplanung, auch
wenn der Tunnel sie nicht als öffentliches Origin benötigt. Direkte Zugriffe
über IPv4-Portweiterleitungen und global adressierte IPv6-Backends dürfen
den vorgesehenen Anmeldeschutz nicht umgehen. Ein eigener direkter
VPN-Endpunkt würde eine gesonderte Endpunkt-, DNS- und Firewallplanung
benötigen; er wird durch diesen Plan nicht automatisch eingerichtet.

## Phase 0 · Bestandsaufnahme

- [ ] Erfasse Router, DHCPv4-Server, IPv6-Router-Advertisements, aktuelle DNS-Resolver, VLANs und gegebenenfalls Gastnetze. Halte fest, welcher Resolver unter IPv4 und IPv6 tatsächlich an die Clients verteilt wird.
- [ ] Gleiche die aktuelle öffentliche IPv4 mit `109.91.25.25` und das
  zugeteilte IPv6-Präfix mit `2a02:908:c250:9d00::/59` ab. Erfasse an
  Fritzbox, `proxmox2` und Router-LXC die tatsächliche Präfixdelegation,
  Hin-/Rückrouten und bisher verwendeten `/64`-Netze. Die separate
  Anschlußadresse `2a02:8070:a00::3e6a` nicht als LAN-Ziel übernehmen.
- [ ] Erfasse bestehende IPv4-Portweiterleitungen und IPv6-Freigaben für
  Caddy, Authentik, Proxmox und die Backends. Ordne jede vorhandene globale
  Backend-Adresse einem tatsächlichen Segment und Filterpfad zu.
- [ ] Ermittle die LAN-Adressen von Resolver, Proxmox, Caddy-LXC, Authentik-VM, Grafana, ERPNext und `cloudflared`. Prüfe, auf welchem Host der Tunnel läuft und ob er lokal oder im Cloudflare-Dashboard verwaltet wird.
- [ ] Ermittle die autoritativen Nameserver von `jaylab.org`, die vorhandenen öffentlichen Dienst-Einträge, Wildcard-Einträge und veröffentlichte Tunnelrouten. Prüfe, ob Cloudflare zugleich der DNS-Anbieter ist. Ein Cloudflare Tunnel allein belegt das nicht.
- [ ] Erfasse die aktuelle Grafana-Route zu `https://grafana.local:3443` und den Einsatz von `noTLSVerify`. Prüfe das tatsächliche Zertifikat und den vom Backend erwarteten Host-Header.
- [ ] Erfasse die aktuelle ERPNext-/Frappe-Version, den externen Basisnamen, den aktiven Entra-Login und vorhandene API-Verbraucher. Prüfe den direkten lokalen Proxmox-Login in einer frischen Sitzung.
- [ ] Sichere die für die jeweilige Phase betroffenen Konfigurationen. Verwende vorhandene Versionsverwaltung oder Exporte. Halte Token, Client-Secrets, Tunnel-Zugangsdaten und private Schlüssel aus Git und Arbeitsprotokollen heraus.

**Ergebnis:** Eine ausgefüllte Zuordnung mit Hostnamen, internen Zielen, DNS-Verteilung, Anschluß-/Präfixzuordnung und Tunnelrouten. Betreiberangaben und aktuell gemessene Werte sind getrennt belegt; unbestätigte Dienstadressen werden nicht vergeben.

## Phase 1 · Lokales DNS mit einem Pilotgerät erproben

- [ ] Verwende den vorhandenen dnsmasq-LXC für gezielte Host-Überschreibungen. Lege für den Pilotnamen `grafana.jaylab.org` einen A-Eintrag auf Caddys feste LAN-IPv4-Adresse an. Ergänze AAAA nur, wenn Caddy über eine stabile interne IPv6-Adresse erreichbar sein soll. Für diese Umsetzung keinen zweiten Resolver installieren.
- [ ] Verwende für ein lokales AAAA-Ziel eine nachgewiesen erreichbare
  ULA-Adresse oder eine stabile Adresse aus dem tatsächlich gerouteten
  LAN-`/64` innerhalb des zugeteilten `/59`. Weder das gesamte `/59` noch die
  separate IPv6-Anschlußadresse ist ein gültiges Hostziel. Prüfe, daß auch ein
  lokales globales IPv6-Ziel über den LAN-Pfad erreicht wird.
- [ ] Beantworte für den überschriebenen Namen alle angefragten Typen lokal. Bei dnsmasq die gezielte `address`-Regel durch die passende `local`-Regel ergänzen, damit auch nicht lokal belegte Typen nicht öffentlich aufgelöst werden. Wenn kein lokaler AAAA- oder HTTPS-Record konfiguriert ist, muß der Resolver ohne Adresse bzw. ohne Daten antworten. Andere Namen unter `jaylab.org` sollen weiter normal auflösbar sein. Das Verhalten wurde mit dnsmasq 2.91 isoliert geprüft; vor Aktivierung die tatsächlichen Includes und Antworten erneut prüfen.
- [ ] Stelle vorerst nur das Pilotgerät und bei Bedarf die beteiligten Server auf den lokalen Resolver ein. Prüfe auch DNS-over-HTTPS im Browser, Androids „Privates DNS“, VPN-Profile und explizite Web-Proxys auf alternative Auflösungswege.
- [ ] Prüfe bei einem Router mit DNS-Rebind-Schutz, ob die eigene lokale Antwort durchgelassen wird. Falls eine Ausnahme nötig ist, beschränke sie auf die betroffenen Namen bzw. die eigene Zone.

**Abnahme:** A liefert Caddys interne IPv4. AAAA liefert Caddys interne IPv6 oder keine Daten. HTTPS liefert keinen öffentlichen Diensteintrag. DNS-Protokoll oder Mitschnitt zeigt, daß der Resolver diese Namen selbst beantwortet. Der öffentliche DNS-Eintrag des bestehenden Fernzugriffs ist weiterhin funktionsfähig.

**Rückweg:** DNS-Einstellung des Pilotgeräts zurücksetzen und den neuen Host-Eintrag entfernen.

## Phase 2 · Caddy und Let’s Encrypt für Grafana

- [ ] Stelle Caddy im festgelegten eigenen Debian-LXC mit `unprivileged: 1` und fester LAN-Adresse bereit. Installiere Caddy nativ als systemd-Dienst mit eigenem Dienstbenutzer. Docker, Host-Docker-Socket und Geräteweiterreichung sind hierfür nicht vorgesehen. Prüfe die tatsächliche Unit samt Schutzoptionen; zusätzliche LXC-Features nur bei belegtem Bedarf aktivieren, nicht pauschal Privilegien erweitern oder AppArmor abschalten.
- [ ] Verwende für das belegte Cloudflare-DNS einen versionierten Caddy-Build mit `dns.providers.cloudflare` und einen auf `jaylab.org` begrenzten API-Token mit `Zone:Read` und `DNS:Edit`. Bewahre den Token in der geschützten lokalen Dienstkonfiguration auf. Lege einen reproduzierbaren Aktualisierungsweg fest und prüfe nach jedem Binärwechsel mit `caddy list-modules`, daß das DNS-Modul erhalten ist.
- [ ] Konfiguriere ACME mit DNS-01. Prüfe die Ausstellung im Let’s-Encrypt-Staging und beziehe danach das Browser-vertrauenswürdige Produktionszertifikat. Verwende für Staging einen separaten Testzustand oder getrennten Zertifikatsspeicher. Wenn der interne Resolver die Abfrage der öffentlichen Challenge-Daten beeinflußt, verwende für Caddys DNS-01-Prüfung einen Resolver mit öffentlicher DNS-Sicht. Client-Anfragen benutzen weiter den internen Resolver.
- [ ] Richte Grafana als erste Proxy-Route ein. Verwende eine feste interne Backend-Adresse oder einen eigenen internen Backend-Namen. Wenn `grafana.local:3443` über HTTPS weiterläuft, konfiguriere in Caddy die passende Vertrauenskette und bei Bedarf `tls_server_name`. Vermeide eine Proxy-Schleife über den Frontend-Namen. Gleiche Grafanas `root_url` mit der vorgesehenen Browseradresse ab.
- [ ] Validiere die Caddy-Konfiguration vor dem Reload. Halte den Zertifikatsspeicher persistent. Prüfe die Protokolle auf Probleme bei Ausstellung und Erneuerung.
- [ ] Sichere Konfiguration, Zertifikatsspeicher und benötigte Volumes des
  LXC. Zusätzliche Datenvolumes als von Proxmox verwaltete Volumes vorsehen;
  gewöhnliche Host-Bind-Mounts nicht als automatisch mitgesichert behandeln.
  Automatischen Start und Wiederherstellung des LXC prüfen.

**Abnahme:** HTTPS ist ohne Zertifikatswarnung erreichbar. Der Zertifikatsname stimmt, die Verbindung geht an Caddys LAN-IP und Grafana lädt vollständig. Prüfe das Backend separat, wenn es HTTPS verwendet.

**Rückweg:** Vorherige Caddy-Konfiguration und gegebenenfalls Grafanas vorherige `root_url` wiederherstellen.

## Phase 3 · Tunnel und DNS im Heimnetz umstellen

- [ ] Führe die bestehende öffentliche Grafana-Route, sofern sie gebraucht wird, auf Caddys LAN-Endpunkt. Wenn der Tunnel als Service-URL die IP-Adresse nutzt, setze `originServerName` auf `grafana.jaylab.org` und stelle sicher, daß der HTTP-Host auf die richtige Caddy-Route zeigt. Setze `noTLSVerify: false`, sobald der HTTPS-Endpunkt geprüft ist. Verwende als Tunnelziel einen internen Endpunkt, der sich zuverlässig unabhängig vom öffentlichen Tunnel-DNS auflösen läßt.
- [ ] Prüfe den Fernzugriff über Mobilfunk. Falls Cloudflare Access aktiv ist, geht der LAN-Aufruf direkt zu Caddy und damit an Cloudflare Access vorbei. Prüfe daher die Anmeldung und Berechtigungen in der Anwendung auf beiden Wegen.
- [ ] Verteile über DHCPv4 und IPv6-Router-Advertisements (RDNSS), soweit unterstützt auch über DHCPv6, ausschließlich lokale Resolver mit identischen Überschreibungen. Verwende einen zweiten lokalen Resolver, falls Ausfallsicherheit nötig ist.
- [ ] Aktiviere die weiteren Host-Einträge erst, wenn das jeweilige HTTPS-Ziel bereitsteht. Prüfe mindestens einen Arbeitsplatzrechner und ein Mobilgerät nach Aktualisierung der Netzwerkeinstellungen.
- [ ] Falls du DNS netzseitig durchsetzen willst, begrenze ausgehendes klassisches DNS (TCP/UDP 53) der Clients auf deine Resolver und prüfe gegebenenfalls externen DNS-over-TLS-Verkehr. DNS-over-HTTPS und VPNs können sich dieser Portregel entziehen. Prüfe sie daher zusätzlich auf den verwalteten Geräten. Teste Firewall-Regeln zuerst in einem Pilotnetz.

**Abnahme:** Derselbe Name führt im Heimnetz nachweislich zur LAN-IP, von außen zum Tunnel. Die DNS- und HTTPS-Tests sind auf IPv4 und IPv6 durchgeführt, soweit beide im LAN aktiv sind. Für Dienste mit rein lokalem Zugriff ist keine öffentliche Route erreichbar.

**Rückweg:** Vorherige Tunnel-Route und vorherige Resolver-Verteilung wiederherstellen. DHCP-Leases und DNS-Caches der Testgeräte aktualisieren.

## Phase 4 · authentik und SSO in Betrieb nehmen

### 4.1 · Authentik-Neuinstallation festlegen

**Betreiberangabe vom 15. November 2026:** Es gibt bislang keine
Authentik-Installation. Authentik wird vollständig neu installiert; eine
vorherige Identitätsdatenbank, vorhandene Provider oder deren Migration sind
keine Voraussetzung dieses Plans.

Der DNS-Alias `authentik.jaylab.local` auf `192.168.40.226` und die in Node-RED
vorbereitete OIDC-Konfiguration sind Konfigurationsreste, kein Nachweis einer
Installation. Sie werden bei der Anbindung der jeweiligen Anwendung
kontrolliert berichtigt. Die gemeinsamen k3s-Aliase dabei nicht pauschal
löschen. Einzelbelege und die berichtigte Einordnung stehen in der
[Anwendbarkeitsprüfung](PRUEFUNG-HTTPS-SPLIT-DNS-SSO.md).

- [ ] Eine eigene Authentik-VM mit neuer PostgreSQL-Datenbank vorsehen.
  Proxmox-Host, Storage, freie VM-ID, feste LAN-Adresse und Verwaltungsweg
  anhand des aktuellen Bestands festlegen. Die öffentliche Anschluß-IPv4
  wird der VM nicht zugewiesen. IPv6 nur aus einem nachgewiesenen LAN-Präfix
  gemäß der obigen Adreßplanung verwenden.
- [ ] `https://login.jaylab.org` als gemeinsamen Browser- und OIDC-Namen der
  neuen Installation festlegen. Mit lokaler DNS-Sicht und internem Zugang
  beginnen; eine externe Veröffentlichung folgt erst nach Abschnitt 4.5.
- [ ] Neue Benutzer, Gruppen, Provider und anwendungsspezifische Clients
  einrichten. Die vorbereiteten Node-RED-Clientwerte nicht als registrierte
  Identität übernehmen. Keine Wiederherstellung einer vermeintlichen alten
  Authentik-Installation einplanen.

### 4.2 · Lokale Basis, TLS und Betrieb vorbereiten

- [ ] Authentik neu mit festgelegten Versionen der offiziellen Docker-
  Compose-Konfiguration und PostgreSQL in der vorgesehenen VM installieren.
  Server und Worker bereitstellen. Als Startgröße sind 2 vCPU und 4 GiB RAM
  vorgesehen, dazu zunächst etwa 32 GiB virtuelle Platte; freie Ressourcen
  und Storage vorher nachmessen. QEMU-Gastagent, persistente Anwendungsvolumes
  sowie den automatischen Start der VM und Dienste einrichten. Keine fremden
  Anwendungen in diesen Compose-Host aufnehmen. Der Gastagent ersetzt keinen
  nativen PostgreSQL-Dump und dessen Wiederherstellungsprüfung.
  Keine zusätzliche Netzbrücke zwischen Vertrauenszonen schaffen.
- [ ] Neue Datenbankzugänge, `AUTHENTIK_SECRET_KEY` und Signing-Keys erzeugen.
  Secrets nur in der geschützten lokalen Dienstkonfiguration und vorgesehenen
  sicheren Ablage halten. Vor einer Anwendungsanbindung den gesunden Zustand
  von Datenbank, Server und Worker nachweisen.
- [ ] Caddy-Route und lokale DNS-Antworten für `login.jaylab.org` bereitstellen.
  Zuerst TLS mit passendem Namen prüfen, dann Anmeldung. Browser, Proxmox-Knoten
  und beteiligte Anwendungsserver müssen denselben Issuernamen erreichen.
  Ausgehende ACME-/DNS-API-Verbindungen für Zertifikatserneuerung gesondert
  betrachten; ein gültiges Zertifikat macht eine lokale Anmeldung nicht von
  einer ständig offenen WAN-Verbindung abhängig.
- [ ] Reverse-Proxy-Header für Host, Protokoll und Clientadresse sowie
  WebSocket-Verbindungen prüfen. Von Clients gelieferte entsprechende Header
  am vertrauenswürdigen Proxy überschreiben. In
  `AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS` nur die tatsächlich unmittelbar
  vorgeschalteten Proxyquellen berücksichtigen; keine pauschale Freigabe des
  gesamten Heimnetzes. Caddy-Quelladresse und IPv4-/IPv6-Pfad vorher messen.
- [ ] Den Docker-Socket nicht für den eingebetteten Outpost voraussetzen.
  Falls automatische Outpost-Verwaltung benötigt wird, den tatsächlichen
  Bedarf gesondert festlegen; ein allgemeiner Docker-Socket-Zugriff ist keine
  Voraussetzung für native OIDC-Clients.
- [ ] Server, Worker und Datenbank überwachen: `/-/health/live/` und
  `/-/health/ready/`, Worker-Healthcheck, Zertifikatslaufzeit, Zeitabgleich,
  Datenbank- und Sicherungsfehler. Bei einem Proxy-Outpost zusätzlich dessen
  Ping prüfen. Ein grüner HTTP-Healthcheck ersetzt keinen OIDC-Anmeldetest.

### 4.3 · Konten, Rechte und Wiederherstellung

- [ ] Ein neues lokales authentik-Verwaltungskonto, ein gewöhnliches Testkonto
  und ein unberechtigtes Testkonto anlegen. Verwaltung mit MFA
  absichern und einen offline verwahrten Wiederherstellungsweg prüfen.
  Lokale Kennwortanmeldung und etwa TOTP dürfen im WAN-Ausfall nicht erst eine
  Entra-Anmeldung, externe E-Mail oder einen Cloud-Dienst benötigen.
- [ ] Je Anwendung einen neuen Provider/Client mit eigenen Clientkennungen
  und Secrets, exakt passenden Redirect-URIs und nur den benötigten Scopes
  einrichten. Öffentliches Selbstregistrieren zunächst deaktivieren;
  automatische Benutzeranlage in den Anwendungen ausdrücklich entscheiden.
  Keine Administratorrolle allein aus einer E-Mail-Domäne ableiten.
- [ ] Rollen und Gruppen getrennt von der Anmeldung zuweisen: ein Testkonto
  mit minimalen Rechten und ein unberechtigtes Konto prüfen. Eine erfolgreiche
  Anmeldung bzw. automatische Benutzeranlage verleiht noch keine Proxmox-ACL
  oder ERPNext-Rolle.
- [ ] Je Anwendung einen tatsächlich funktionsfähigen Notzugang festhalten.
  Der vorhandene Node-RED-Lesetoken ist kein administrativer Notzugang.
  Geprüftes Host-SSH und `pct exec` bleiben als unabhängiger Verwaltungsweg
  erhalten; `root@pam` zusätzlich in einer frischen Proxmox-Websitzung testen.

### 4.4 · Anwendungen einzeln anbinden

- [ ] **Grafana:** Generic OAuth einrichten, mit einem Testkonto anmelden und die zugewiesene Rolle prüfen. Dann aus einer neuen Browsersitzung den lokalen Notzugang testen.
- [ ] **Proxmox:** `pve.jaylab.org` intern direkt auf den Knoten zeigen lassen und dort ein eigenes ACME-DNS-Zertifikat für Port 8006 einrichten. Anschließend einen OIDC-Realm hinzufügen. Mit einem Testkonto die ACLs prüfen, ebenso den direkten `root@pam`-Zugang bei abgeschaltetem authentik.
- [ ] **ERPNext:** Zuerst den bisherigen Login und die bestehenden API-Aufrufe dokumentieren. In der installierten Frappe-Version den benutzerdefinierten Social Login Key und die tatsächlich erzeugte Redirect-URI prüfen. Authentik zunächst parallel mit einem bestehenden Testkonto und dessen E-Mail-Zuordnung erproben. ERPNext-Rollen und API-Zugriff mit demselben Testumfang nachprüfen.
- [ ] **Proxmox-Cluster ergänzend:** Für alle drei tatsächlich benutzten
  Knotennamen Zertifikatsnamen, Redirect-URIs und Realm-Verhalten erfassen.
  Einen Pilotknoten zuerst umstellen. Den im Bestand vorhandenen öffentlichen
  Tunnelpfad `proxmox.jaylab.org` ausdrücklich mit dem Ziel „nur intern“
  abgleichen; ein neuer lokaler Name entfernt diesen Nebenpfad nicht.
- [ ] **Node-RED:** Für die vorbereitete OIDC-Strategie einen neuen Provider
  registrieren und Issuer, Clientkennung, Secret und gemessene Callback-URI
  kontrolliert eintragen. Anwendung und Editor nach
  der [Node-RED-Anmeldedokumentation](https://nodered.org/docs/user-guide/runtime/securing-node-red)
  getrennt betrachten: `adminAuth` schützt nicht automatisch alle HTTP-In-
  oder Dashboard-Endpunkte. Den geprüften API-Lesetoken und MQTT-/SHC-
  Anbindungen beim Pilotwechsel funktionsfähig erhalten; Secrets weder in
  Browser-URLs noch in Proxyprotokolle übernehmen.
- [ ] **Zigbee2MQTT und andere Oberflächen ohne native OIDC-Anmeldung:**
  Bei Bedarf einen eigenen Proxy-Provider im Modus Forward auth für genau
  diese Anwendung und einen eingebetteten oder gesonderten Outpost planen.
  Die Caddy-Route für `/outpost.goauthentik.io/*` und WebSockets nach
  Herstellervorlage prüfen. Direkten Zugriff auf den ursprünglichen
  Frontend-Port gesondert begrenzen, damit er die Anmeldung nicht umgeht.
  Die notwendigen IPv4-/IPv6-Regeln benötigen ihren eigenen geprüften Rückweg.
  Domainweite Forward-auth-Regeln nicht als Ersatz für unterschiedliche
  Anwendungsrechte verwenden.
- [ ] **Maschinelle Zugriffe:** MQTT-Clientzertifikate, SHC-Pairing,
  ERPNext-API-Zugänge und den Node-RED-Lesetoken getrennt von Browser-SSO
  erhalten. Caddy/Forward auth darf diese Clients nicht unbeabsichtigt auf
  eine interaktive Loginseite umleiten. Ausnahmen nur für konkret belegte
  Endpunkte mit weiter wirksamer Anwendungsanmeldung vorsehen; keine pauschale
  Freigabe von `/api/*`. Die MQTT-Automatisierungs-CA und das eigenständige
  Bosch-SHC-Vertrauen werden nicht durch Let’s Encrypt für Weboberflächen ersetzt.

### 4.5 · Externen Zugang und Abhängigkeiten prüfen

- [ ] Kläre vor externem SSO, wie der Browser von außen den OIDC-Issuer erreicht. Bei rein lokalem `login.jaylab.org` ist für den externen OIDC-Login ein VPN mit internem DNS nötig. Bei Veröffentlichung den externen Login vollständig testen. Automatisches SSO für öffentlich erreichbare Anwendungen erst aktivieren, wenn der Anmeldeweg auch von außen funktioniert. Der IdP darf nicht hinter einer Cloudflare-Access-Regel liegen, die denselben IdP zum Öffnen der Loginseite voraussetzt. Entra ID kann später zusätzlich angebunden werden und setzt für diesen Anmeldeweg Internetzugriff voraus.
- [ ] Discovery-Dokument, Token-Endpunkt und JWKS aus dem jeweiligen
  Anwendungsserver prüfen. Eine Cloudflare-Browser-Challenge vor diesen
  Maschinenendpunkten ist kein funktionierender OIDC-Backchannel. Externe
  Anmeldung, Anmeldung aus dem LAN und lokaler Betrieb ohne WAN sind eigene
  Abnahmetests. Entra darf als zusätzliche Quelle bestehen bleiben, ohne den
  getesteten lokalen Wiederherstellungsweg zu verdrängen.

### 4.6 · Abnahme, Sicherung und Rücknahme

| Prüfung | Erwartet |
|---|---|
| Frische lokale Sitzung, gewöhnliches Testkonto | Anmeldung über `login.jaylab.org`, nur zugewiesene Anwendungsrechte |
| Unberechtigtes Konto | Kein Zugriff auf die geschützte Anwendung |
| Browser und Anwendungsserver | Gleicher korrekter Issuer, gültige TLS-Kette, passende Discovery-/Callback-Adressen |
| Pilotclient ohne WAN, frische Sitzung | Lokale authentik-Anmeldung und lokale Anwendung funktionieren weiterhin |
| authentik ausgefallen | Geschützte Route öffnet sich nicht anonym; unabhängiger Verwaltungs-/Notzugang funktioniert |
| Abmeldung und Rechteentzug | Wirkung auf IdP-Sitzung und Anwendungssitzung gesondert geprüft |
| ERPNext-, Node-RED- und MQTT-/SHC-Clients | Bestehende maschinelle Anmeldung und nötige Funktionen erhalten |
| Öffentlich freigegebene Anwendung | Vollständige externe OIDC-Anmeldung; kein Zirkelschluß mit Cloudflare Access |
| Direkter Backend-Port, IPv4 und IPv6 | Kein ungeprüfter Umgehungsweg zur vorgesehenen Proxyanmeldung |

- [ ] PostgreSQL mit nativem Datenbank-Dump sichern, außerdem zur gewählten
  Version gehörende Compose-/Umgebungskonfiguration, `AUTHENTIK_SECRET_KEY`,
  eingebundene Dateien und Medien sichern. Signing-Keys bzw. externe
  Schlüsselablagen und Provider-Konfigurationen berücksichtigen. Secrets
  verschlüsselt außerhalb von Git aufbewahren; einen nicht vom IdP abhängigen
  Zugriff auf die Sicherung erhalten.
- [ ] Eine Wiederherstellung mit passender Version und isolierter Datenbank
  testen. PostgreSQL vor dem produktiven authentik-Start wiederherstellen.
  Beim Test keine konkurrierende Instanz an dieselbe produktive Datenbank
  anschließen und keine produktiven DNS-Namen umbiegen. Anschließend den
  tatsächlichen Anmeldungstest einschließlich Benutzerzuordnung wiederholen.
- [ ] Vor jeder einzelnen Anwendungsanbindung deren bisherige Login-/Proxy-
  Konfiguration und die genaue Rücknahme sichern. Vorhandene unabhängige
  Anmeldewege bis zur jeweiligen Abnahme erhalten. Bei einem Fehler die
  betroffene Anbindung zurücknehmen; keine alte Authentik-Instanz als Rückweg
  voraussetzen. Spätere Datenbank-Upgrades nicht durch einen ungeprüften
  Versions-Downgrade rückgängig machen.

**Abnahme:** Lokales SSO funktioniert in frischen Sitzungen, Rollen stimmen, lokale Notzugänge funktionieren und die bisherigen ERPNext-API-Aufrufe bestehen den Test.

**Rückweg:** Je Anwendung den neuen OIDC-Client bzw. Realm deaktivieren und über den getesteten lokalen Zugang weiterarbeiten. Bei ERPNext den bisherigen Anmeldeweg nutzen.

## Phase 5 · Gesamtabnahme und Betrieb

Von einem normalen Heimnetz-Client ausführen, nachdem er die regulären DNS-Einstellungen bezogen hat:

```sh
dig grafana.jaylab.org A
dig grafana.jaylab.org AAAA
dig grafana.jaylab.org HTTPS
curl --noproxy '*' --silent --show-error --output /dev/null \
  --write-out 'Ziel-IP=%{remote_ip} HTTP=%{http_code}\n' \
  https://grafana.jaylab.org/
```

Erwartet wird die LAN-IP von Caddy. Ein regulärer Login-Redirect ist zulässig. Im Browser zusätzlich die Remote-Adresse sowie die Redirect-Ziele prüfen. Mit aktiviertem IPv6 bei Bedarf getrennt mit `curl -4` und `curl -6` testen. Für einen rein über IPv4 konfigurierten Dienst wird bei erzwungenem IPv6 keine Verbindung erwartet.

- [ ] **LAN ohne WAN:** Internetverbindung am Test-Client gezielt sperren oder den WAN-Uplink vorübergehend trennen. LAN und lokales DNS verfügbar halten, Mobilfunk am Testgerät abschalten. In einer neuen Browsersitzung Grafana und die lokale authentik-Anmeldung prüfen. Ein Test mit getrenntem WAN ersetzt die Kontrolle der Remote-Adresse und der DNS-Protokolle im Normalbetrieb nicht.
- [ ] **Mobilfunk:** Öffentlich freigegebene Dienste über den Tunnel testen. Für Proxmox und weitere LAN-Dienste prüfen, daß sie von außen nicht erreichbar sind, auch nicht über einen öffentlichen Wildcard-Tunnel.
- [ ] **Feste Anschlußadressen:** Von einem unabhängigen externen Testpunkt
  gezielt Zugriffe über `109.91.25.25` und die tatsächlich vergebenen globalen
  IPv6-Adressen der betroffenen Backends prüfen. Gesperrte direkte
  Web-/Verwaltungswege einschließlich 8006 müssen auch dann gesperrt bleiben,
  wenn korrekter Host-Header bzw. SNI verwendet wird. Einen IPv4-NAT-Filter
  nicht als Nachweis für IPv6-Schutz behandeln. Nur die belegten Ziele und
  Ports prüfen, keinen pauschalen Scan des `/59` durchführen.
- [ ] **Erneuerung und Wiederherstellung:** Zertifikatslaufzeiten und ACME-Protokolle kontrollieren. DNS-Konfiguration, Caddy-Konfiguration und persistente Daten sowie authentik-Datenbank und -Konfiguration sichern. Einen Wiederherstellungstest für authentik und die Verfügbarkeit der lokalen Notzugänge dokumentieren.
- [ ] **Abschluß:** Je Phase die geänderten Dateien oder Einstellungen, die Testergebnisse und gegebenenfalls die noch offenen Zugriffe festhalten.

## Technische Referenzen

- [Let’s Encrypt · DNS-01](https://letsencrypt.org/docs/challenge-types/)
- [Caddy · Automatic HTTPS](https://caddyserver.com/docs/automatic-https) und [Cloudflare-DNS-Modul](https://github.com/caddy-dns/cloudflare)
- [Unbound · Lokale Zonen](https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html)
- [Cloudflare Tunnel · HTTPS zum lokalen Ziel](https://developers.cloudflare.com/tunnel/troubleshooting/https-origins/)
- [authentik · Reverse Proxy](https://docs.goauthentik.io/install-config/reverse-proxy) und [Grafana-Integration](https://integrations.goauthentik.io/monitoring/grafana/)
- [authentik · Docker Compose](https://docs.goauthentik.io/install-config/install/docker-compose/), [Sicherung und Wiederherstellung](https://docs.goauthentik.io/sys-mgmt/ops/backup-restore) und [Monitoring](https://docs.goauthentik.io/sys-mgmt/ops/monitoring)
- [authentik · Proxmox](https://integrations.goauthentik.io/hypervisors-orchestrators/proxmox-ve/), [Forward auth](https://docs.goauthentik.io/add-secure-apps/providers/proxy/forward_auth/) und [Caddy-Outpost-Anbindung](https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_caddy/)
- [Proxmox VE · Administrationshandbuch](https://pve.proxmox.com/pve-docs/pve-admin-guide.pdf)
- [Frappe · Social Login Key](https://docs.frappe.io/framework/user/en/guides/integration/social_login_key)
