# Änderung: Node-RED mit HTTPS und Authentik-SSO

## Umfang

Node-RED CT 105 auf `proxmox` ist unter `https://nodered.jaylab.org` mit einem
öffentlich vertrauenswürdigen Frontend-Zertifikat und der vorhandenen nativen
OpenID-Connect-Strategie angebunden. Authentik bleibt lokal unter
`https://login.jaylab.org`. Kein Tunnel, kein öffentlicher A-/AAAA-Eintrag,
keine Änderung an Router, Firewall, Bridge, MQTT, SHC oder Flows.

Der Editorzugriff wird über eine eigene Authentik-Gruppe auf das vorhandene
Betreiberkonto begrenzt. Die bestehende read-only Node-RED-API-Anmeldung,
Projektdateien und maschinellen Verbindungen bleiben erhalten. `adminAuth`
schützt nicht automatisch HTTP-In-Endpunkte; diese werden vor Freigabe gesondert
aufgenommen.

## Ausgangslage

Am 15. November 2026 lesend geprüft:

- CT 105, Node-RED-Dienst aktiv, `192.168.40.223`, HTTPS an Port 1880.
- Node-RED besaß bereits die Strategie `openidconnect`, damals mit dem
  veralteten Issuer `authentik.jaylab.local` und Callback
  `https://nodered.jaylab.local:1880/auth/strategy/callback/`.
- Der neue lokale Issuer `https://login.jaylab.org` ist aus CT 105 erreichbar.
- Caddy CT 131 erreicht das Node-RED-Backend mit gültiger CA- und
  Namensprüfung; GET `/` antwortet HTTP 200.
- Der Node-RED-Lesetoken besteht TLS-Prüfung, GET `/flows` (142 Nodes),
  anonyme/falsche Tokens und Schreibversuche werden abgewiesen; Flows blieben
  unverändert.

## Aktivierte Änderung

- [Caddy-Route](../pilot/https/nodered.caddy): DNS-01-Zertifikat für
  `nodered.jaylab.org`, Proxy zu `192.168.40.223:1880` mit Prüfung des
  Backendnamens `nodered.jaylab.local` und der Automatisierungs-CA.
- [Split-DNS-Include](../router/dnsmasq/94-jaylab-nodered.conf): nur A auf
  `192.168.10.18` und `local`; keine AAAA-/HTTPS-Antwort und keine öffentliche
  DNS- oder Tunnelroute.
- Authentik: vertraulicher Provider `jaylab-nodered`, Anwendung `nodered`,
  strikte Redirect-URI `https://nodered.jaylab.org/auth/strategy/callback/`.
  Die Anwendung ist mit genau einer aktivierten Gruppenbindung auf
  `jaylab-nodered-users` beschränkt; Mitglied ist ausschließlich `jay`.
- Node-RED: Issuer `https://login.jaylab.org/application/o/nodered/`,
  Discovery-Endpunkte desselben Issuers und die oben genannte Callback-URI.
  Neue Client-ID und Secret; Secret bleibt außerhalb von Git und Befehlszeilen.

Node-RED verwendet nun den Issuer
`https://login.jaylab.org/application/o/nodered/`, die zugehörigen
Authentik-Endpunkte und die öffentliche Callback-URI. Die neue Client-ID und
das Secret stehen nicht in Git oder Befehlszeilen. Das Secret liegt lokal
DPAPI-verschlüsselt unter `.local/access/authentik/nodered/client.clixml`;
die Datei `/home/jay/.node-red/settings.js` ist jetzt `jay:jay`, Modus 0600.
Vorher war diese Datei Modus 0644. Die übrigen Einstellungen, Projekte und
Flowdateien blieben unverändert.

Caddy CT 131 bedient die HTTPS-Route über IPv4 `.10.18`. Das
Let’s-Encrypt-Zertifikat hat SAN `nodered.jaylab.org`, Aussteller YE2 und ist
bis 13. Februar 2027 gültig. Caddy prüft den Backendnamen
`nodered.jaylab.local` und die Automatisierungs-CA.

Das DNS-Include ist auf CT 101 aktiv. `nodered.jaylab.org` liefert im internen
DNS nur A `192.168.10.18`; AAAA und HTTPS sind NODATA. Die öffentliche Abfrage
für A, AAAA und HTTPS liefert NXDOMAIN. Es gibt keine öffentliche
Tunnelroute. Router, Firewall, Bridges, DHCP, RA und IPv6-Routen wurden nicht
geändert.

Am Zeitpunkt der Aufnahme enthielt der Node-RED-Flowbestand keine `http in`-
Nodes. `httpNodeRoot` ist `/`, `httpNodeAuth` ist nicht gesetzt. Die gemessene
Node-RED-Listenerliste enthält Port 1880 nur auf IPv4; das ist keine Aussage
über Netzisolation außerhalb dieses Dienstes.

## Sicherung und Rücknahme

Vor Änderungen wurde Authentik nativ gesichert. Die Sicherung und die
geschützten Originale liegen unter:

- VM 132: `/root/.local/jaylab/nodered-sso-20261115T181736Z/authentik-before.dump`
- Host `proxmox`: `/root/.local/jaylab/nodered-sso-20261115T181736Z/nodered-settings.js.before`
- Host `proxmox`: Caddy-Route und öffentliche CA-Kopie im selben Verzeichnis
- Host `proxmox2`: `/root/.local/jaylab/nodered-sso-20261115T181736Z/94-jaylab-nodered.conf`

Authentik-Dump und Node-RED-Originaldatei sind jeweils mit Modus 0600
geschützt; die übrigen Sicherungen liegen in geschützten Host-Verzeichnissen.
Das OIDC-Secret liegt zusätzlich DPAPI-verschlüsselt auf dem Arbeitsplatz.
Der Hash der gesicherten Node-RED-
Einstellungen war vor der Änderung
`a836e773c85e63ba34c8df083455be0e779cbb6a96eab3b7013a8103d33c3298`;
der aktive Stand ist
`03b78895260720466344bf558c6e74cde6b258ae9c23413b45138d6ca113a5e8`.

Gezielter Rückweg: Node-RED mit der gesicherten Originaldatei zurücksetzen,
aber den sicheren Modus 0600 beibehalten, dann den Dienst prüfen. Nur die
neue Caddy-Route und CA-Kopie entfernen, Caddy validieren und reloaden. Nur
`94-jaylab-nodered.conf` entfernen, den vollständigen dnsmasq-Bestand mit
`systemd-helper checkconfig` prüfen und dnsmasq neu starten. Authentik-
Gruppenbindung lösen und Anwendung/Provider deaktivieren; keine Konten
löschen. Vor jedem Rückschreiben aktuelle Hashes vergleichen. Die bereits
geprüfte SSH-Verwaltung des Hosts und `pct exec` bleiben unabhängig von den
Webdiensten.

## Abnahme

| Quelle / Ziel | Ergebnis | Status |
|---|---|---|
| Windows-Client, internes DNS | A `.10.18`, HTTPS HTTP 200, TLS-Prüfung 0 | Bestanden |
| Caddy → Node-RED | Backend-TLS mit CA-/Namensprüfung, GET `/` HTTP 200 | Bestanden |
| OIDC-Discovery/Start | Discovery gültig; Browser erreicht Authentik; Redirect 302 mit richtiger Client-ID und Callback | Bestanden |
| Frische authentisierte Sitzung | Anmeldung und Rückkehr zum Editor | Noch nicht vom Betreiber bestätigt |
| Gruppenzugriff | Nur `jaylab-nodered-users` mit Mitglied `jay` gebunden | Konfiguration geprüft; Negativanmeldung nicht ausgeführt |
| Node-RED-API | GET `/flows` 200; anonym, falscher Token und Schreiben je 401 | Bestanden; 142 Nodes, unverändert |
| Bestehende Automatisierung | MQTT-TLS und SHC-GET nach Neustart | Bestanden |
| DNS | A intern; AAAA/HTTPS NODATA über UDP/TCP; öffentlich NXDOMAIN | Bestanden |

## Abschluß und offener Nachweis

HTTPS, Split-DNS, OIDC-Provider und die Gruppenbeschränkung sind aktiviert.
Der Browser zeigt „Sign in with authentik“ und erreicht den Authentik-
Anmeldefluß mit passender Callback-URI. Eine frische Anmeldung mit dem
Betreiberkonto und die anschließende Editor-/WebSocket-Sitzung wurden nicht
abgeschlossen; Kennwort oder TOTP wurden nicht zurückgesetzt. Daher bleibt die
interaktive SSO-Abnahme offen. HTTP-In-Endpunkte waren bei dieser Aufnahme
nicht vorhanden; vor ihrer späteren Einführung ist die Erreichbarkeit erneut
zu bewerten.
