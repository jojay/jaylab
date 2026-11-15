# Implementierungsplan für HTTPS, Split-DNS und SSO im Heimnetz

## Auftrag für Codex

> Setze diesen Plan phasenweise um. Beginne mit der Bestandsaufnahme im Projektordner und ermittle, welche Systeme du von deiner Umgebung aus erreichen kannst. Verwende die vorhandene Infrastruktur und übernimm bestätigte Werte aus der laufenden Konfiguration. Ermittle vor jeder Umstellung den Istzustand, den konkreten Konfigurationsunterschied und den passenden Rückweg. Arbeite zuerst an einem Pilotgerät. Prüfe nach jedem Schritt die angegebenen Abnahmekriterien und protokolliere die Ergebnisse. Wenn dir der Zugriff auf ein System fehlt, bereite die genaue Änderung samt Prüfkommando für dieses System vor und fahre mit den unabhängigen Schritten fort.

Ziel ist, daß Webanfragen und die zugehörigen DNS-Abfragen im Heimnetz lokal bleiben. Weboberflächen bekommen automatisch erneuerte TLS-Zertifikate von Let’s Encrypt. Der vorhandene Cloudflare Tunnel dient dem gezielten Fernzugriff. authentik übernimmt die zentrale Anmeldung für unterstützte Dienste.

## Sollzustand

| Name | Ziel im lokalen DNS | Ziel im öffentlichen DNS | Anmeldung |
|---|---|---|---|
| `grafana.jaylab.org` | Caddy, Port 443 | Vorhandene Tunnelroute, falls Grafana weiterhin von außen benötigt wird | authentik über Generic OAuth |
| `login.jaylab.org` | Caddy, Port 443 | Nur veröffentlichen, wenn externe OIDC-Anmeldungen oder die Anbindung an Cloudflare Access gebraucht werden | Lokales authentik-Konto |
| `dfderp.jaylab.org` | Caddy, Port 443 | Bestehenden Eintrag und Tunnelroute erfassen und bei Bedarf beibehalten | Bestehende Anmeldung, danach authentik mit Testkonto |
| `pve.jaylab.org` | Proxmox-Knoten, Port 8006 | Kein öffentlicher Dienst-Eintrag und keine Tunnelroute | Proxmox-Realm für authentik, `root@pam` als lokaler Notzugang |

Die Namen für Grafana und Proxmox sind Vorschläge. `jaylab.local` kann parallel als vorhandene Gerätenamensdomäne dienen. Verwende für HTTPS den Namen aus der Tabelle, der zum Zertifikat paßt. Die statischen öffentlichen IPv4- und IPv6-Adressen werden für diesen Aufbau nicht benötigt. Sie bleiben für einen späteren direkten VPN-Endpunkt nutzbar. Für den beschriebenen Tunnelbetrieb sind keine eingehenden WAN-Freigaben für 80, 443 oder 8006 erforderlich. Prüfe die WAN-Firewall für beide IP-Versionen.

## Phase 0 · Bestandsaufnahme

- [ ] Erfasse Router, DHCPv4-Server, IPv6-Router-Advertisements, aktuelle DNS-Resolver, VLANs und gegebenenfalls Gastnetze. Halte fest, welcher Resolver unter IPv4 und IPv6 tatsächlich an die Clients verteilt wird.
- [ ] Ermittle die LAN-Adressen von Resolver, Proxmox, Caddy-VM, Grafana, ERPNext und `cloudflared`. Prüfe, auf welchem Host der Tunnel läuft und ob er lokal oder im Cloudflare-Dashboard verwaltet wird.
- [ ] Ermittle die autoritativen Nameserver von `jaylab.org`, die vorhandenen öffentlichen Dienst-Einträge, Wildcard-Einträge und veröffentlichte Tunnelrouten. Prüfe, ob Cloudflare zugleich der DNS-Anbieter ist. Ein Cloudflare Tunnel allein belegt das nicht.
- [ ] Erfasse die aktuelle Grafana-Route zu `https://grafana.local:3443` und den Einsatz von `noTLSVerify`. Prüfe das tatsächliche Zertifikat und den vom Backend erwarteten Host-Header.
- [ ] Erfasse die aktuelle ERPNext-/Frappe-Version, den externen Basisnamen, den aktiven Entra-Login und vorhandene API-Verbraucher. Prüfe den direkten lokalen Proxmox-Login in einer frischen Sitzung.
- [ ] Sichere die für die jeweilige Phase betroffenen Konfigurationen. Verwende vorhandene Versionsverwaltung oder Exporte. Halte Token, Client-Secrets, Tunnel-Zugangsdaten und private Schlüssel aus Git und Arbeitsprotokollen heraus.

**Ergebnis:** Eine ausgefüllte Zuordnung mit Hostnamen, internen Zielen, DNS-Verteilung und Tunnelrouten. Der Plan enthält keine angenommenen produktiven IP-Adressen.

## Phase 1 · Lokales DNS mit einem Pilotgerät erproben

- [ ] Nutze den vorhandenen lokalen Resolver, falls er gezielte Host-Überschreibungen unterstützt. Andernfalls richte einen lokalen Resolver mit Unbound ein. Lege für den Pilotnamen `grafana.jaylab.org` einen A-Eintrag auf Caddys feste LAN-IPv4-Adresse an. Ergänze AAAA nur, wenn Caddy über eine stabile interne IPv6-Adresse erreichbar sein soll.
- [ ] Beantworte für den überschriebenen Namen alle angefragten Typen lokal. Wenn kein lokaler AAAA- oder HTTPS-Record konfiguriert ist, muß der Resolver für diesen Typ ohne Adresse bzw. ohne Daten antworten. Mit Unbound eignet sich `local-data` mit `transparent`; `typetransparent` würde fehlende Typen öffentlich auflösen. Andere Namen unter `jaylab.org` sollen weiter normal auflösbar sein.
- [ ] Stelle vorerst nur das Pilotgerät und bei Bedarf die beteiligten Server auf den lokalen Resolver ein. Prüfe auch DNS-over-HTTPS im Browser, Androids „Privates DNS“, VPN-Profile und explizite Web-Proxys auf alternative Auflösungswege.
- [ ] Prüfe bei einem Router mit DNS-Rebind-Schutz, ob die eigene lokale Antwort durchgelassen wird. Falls eine Ausnahme nötig ist, beschränke sie auf die betroffenen Namen bzw. die eigene Zone.

**Abnahme:** A liefert Caddys interne IPv4. AAAA liefert Caddys interne IPv6 oder keine Daten. HTTPS liefert keinen öffentlichen Diensteintrag. DNS-Protokoll oder Mitschnitt zeigt, daß der Resolver diese Namen selbst beantwortet. Der öffentliche DNS-Eintrag des bestehenden Fernzugriffs ist weiterhin funktionsfähig.

**Rückweg:** DNS-Einstellung des Pilotgeräts zurücksetzen und den neuen Host-Eintrag entfernen.

## Phase 2 · Caddy und Let’s Encrypt für Grafana

- [ ] Betreibe Caddy auf einem vorhandenen geeigneten Linux-System oder in einer eigenen VM mit fester LAN-Adresse. Nutze bei Cloudflare als autoritativem DNS einen Caddy-Build mit `dns.providers.cloudflare` und einen auf `jaylab.org` begrenzten API-Token mit `Zone:Read` und `DNS:Edit`. Bei anderem DNS-Anbieter verwende dessen passendes Modul. Bewahre den Token in der lokalen Secret-Konfiguration des Dienstes auf.
- [ ] Konfiguriere ACME mit DNS-01. Prüfe die Ausstellung im Let’s-Encrypt-Staging und beziehe danach das Browser-vertrauenswürdige Produktionszertifikat. Verwende für Staging einen separaten Testzustand oder getrennten Zertifikatsspeicher. Wenn der interne Resolver die Abfrage der öffentlichen Challenge-Daten beeinflußt, verwende für Caddys DNS-01-Prüfung einen Resolver mit öffentlicher DNS-Sicht. Client-Anfragen benutzen weiter den internen Resolver.
- [ ] Richte Grafana als erste Proxy-Route ein. Verwende eine feste interne Backend-Adresse oder einen eigenen internen Backend-Namen. Wenn `grafana.local:3443` über HTTPS weiterläuft, konfiguriere in Caddy die passende Vertrauenskette und bei Bedarf `tls_server_name`. Vermeide eine Proxy-Schleife über den Frontend-Namen. Gleiche Grafanas `root_url` mit der vorgesehenen Browseradresse ab.
- [ ] Validiere die Caddy-Konfiguration vor dem Reload. Halte den Zertifikatsspeicher persistent. Prüfe die Protokolle auf Probleme bei Ausstellung und Erneuerung.

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

- [ ] Installiere authentik mit Docker Compose und PostgreSQL in einer VM. Als Startgröße sind 2 vCPU und 4 GB RAM vorgesehen. Lege Caddy-Route und DNS für `login.jaylab.org` an. Prüfe Reverse-Proxy-Header und WebSocket-Verbindungen nach authentik-Dokumentation.
- [ ] Richte zunächst ein lokales authentik-Konto ein. Registriere je Anwendung einen eigenen OIDC-Client mit exakt passender Redirect-URI. Prüfe, daß Browser und Server den Issuer unter demselben Namen erreichen. Lege einen getesteten lokalen Wiederherstellungszugang je Anwendung fest.
- [ ] **Grafana:** Generic OAuth einrichten, mit einem Testkonto anmelden und die zugewiesene Rolle prüfen. Dann aus einer neuen Browsersitzung den lokalen Notzugang testen.
- [ ] **Proxmox:** `pve.jaylab.org` intern direkt auf den Knoten zeigen lassen und dort ein eigenes ACME-DNS-Zertifikat für Port 8006 einrichten. Anschließend einen OIDC-Realm hinzufügen. Mit einem Testkonto die ACLs prüfen, ebenso den direkten `root@pam`-Zugang bei abgeschaltetem authentik.
- [ ] **ERPNext:** Zuerst den bisherigen Login und die bestehenden API-Aufrufe dokumentieren. In der installierten Frappe-Version den benutzerdefinierten Social Login Key und die tatsächlich erzeugte Redirect-URI prüfen. Authentik zunächst parallel mit einem bestehenden Testkonto und dessen E-Mail-Zuordnung erproben. ERPNext-Rollen und API-Zugriff mit demselben Testumfang nachprüfen.
- [ ] Kläre vor externem SSO, wie der Browser von außen den OIDC-Issuer erreicht. Bei rein lokalem `login.jaylab.org` ist für den externen OIDC-Login ein VPN mit internem DNS nötig. Bei Veröffentlichung den externen Login vollständig testen. Automatisches SSO für öffentlich erreichbare Anwendungen erst aktivieren, wenn der Anmeldeweg auch von außen funktioniert. Der IdP darf nicht hinter einer Cloudflare-Access-Regel liegen, die denselben IdP zum Öffnen der Loginseite voraussetzt. Entra ID kann später zusätzlich angebunden werden und setzt für diesen Anmeldeweg Internetzugriff voraus.

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
- [ ] **Erneuerung und Wiederherstellung:** Zertifikatslaufzeiten und ACME-Protokolle kontrollieren. DNS-Konfiguration, Caddy-Konfiguration und persistente Daten sowie authentik-Datenbank und -Konfiguration sichern. Einen Wiederherstellungstest für authentik und die Verfügbarkeit der lokalen Notzugänge dokumentieren.
- [ ] **Abschluß:** Je Phase die geänderten Dateien oder Einstellungen, die Testergebnisse und gegebenenfalls die noch offenen Zugriffe festhalten.

## Technische Referenzen

- [Let’s Encrypt · DNS-01](https://letsencrypt.org/docs/challenge-types/)
- [Caddy · Automatic HTTPS](https://caddyserver.com/docs/automatic-https) und [Cloudflare-DNS-Modul](https://github.com/caddy-dns/cloudflare)
- [Unbound · Lokale Zonen](https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html)
- [Cloudflare Tunnel · HTTPS zum lokalen Ziel](https://developers.cloudflare.com/tunnel/troubleshooting/https-origins/)
- [authentik · Reverse Proxy](https://docs.goauthentik.io/install-config/reverse-proxy) und [Grafana-Integration](https://integrations.goauthentik.io/monitoring/grafana/)
- [Proxmox VE · Administrationshandbuch](https://pve.proxmox.com/pve-docs/pve-admin-guide.pdf)
- [Frappe · Social Login Key](https://docs.frappe.io/framework/user/en/guides/integration/social_login_key)
