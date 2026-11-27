# Änderung: Zigbee2MQTT intern auf HTTPS unter jaylab.org

Stand: 27. November 2026.

## Umfang

Zigbee2MQTT (CT 121 auf `proxmox`, HTTP-Frontend auf Port 8080) wird für die
interne Nutzung von `http://zb2mqtt.jaylab.local:8080/#/` auf
`https://zb2mqtt.jaylab.org` mit einem öffentlich vertrauenswürdigen
Let’s-Encrypt-Zertifikat umgestellt. Die Terminierung erfolgt über den
bestehenden internen Reverse-Proxy Caddy (CT 131, `192.168.10.18`) mittels
Cloudflare-DNS-01 und Split-DNS auf `dnsmasq` (CT 101, `192.168.10.6`).

Keine öffentliche DNS-Route, kein Cloudflare-Tunnel, keine Änderung an
CT 121 (`zb2mqtt`), Router, Firewall oder DHCP.

**Sicherheitshinweis:** Das Zigbee2MQTT-Frontend läuft unverändert mit
`frontend: true` ohne eigene Anmeldung oder Authentik-SSO. Der Zugang über
`https://zb2mqtt.jaylab.org` ist damit auf das interne Netz beschränkt, aber
nicht zusätzlich durch eine Benutzeranmeldung geschützt.

## Ausgangslage

Am 27. November 2026 vor der Änderung geprüft:

- CT 121 (`zb2mqtt` auf `proxmox`): Adresse `192.168.40.250` (DHCP-Lease 10
  Minuten), Node.js-Dienst lauscht auf `0.0.0.0:8080` (`frontend: true`).
- CT 131 (`caddy-pilot` auf `proxmox`, `192.168.10.18`): aktiv, bindet
  `/etc/caddy/sites/*.caddy` ein, `/etc/resolv.conf` nutzt `192.168.10.6` und
  löst `zb2mqtt.jaylab.local` auf `192.168.40.250` auf. HTTP-GET gegen
  `http://192.168.40.250:8080/` von CT 131 liefert HTTP 200.
- CT 101 (`dnsmasq` auf `proxmox2`, `192.168.10.6`): `/etc/dnsmasq.d/` enthielt
  `90` bis `96`. `zb2mqtt.jaylab.org` lieferte öffentlich (`1.1.1.1`) `NXDOMAIN`.

## Aktivierte Änderung

- [Split-DNS-Include](../router/dnsmasq/97-jaylab-zb2mqtt.conf) auf CT 101
  (`/etc/dnsmasq.d/97-jaylab-zb2mqtt.conf`, `root:root`, `0644`): nur
  `address=/zb2mqtt.jaylab.org/192.168.10.18` und `local=/zb2mqtt.jaylab.org/`;
  keine AAAA-/HTTPS-Antwort und keine öffentliche DNS- oder Tunnelroute.
- [Caddy-Route](../pilot/https/zb2mqtt.caddy) auf CT 131
  (`/etc/caddy/sites/zb2mqtt.caddy`, `root:root`, `0644`): DNS-01-Zertifikat
  für `zb2mqtt.jaylab.org` über Cloudflare, Reverse-Proxy auf
  `http://zb2mqtt.jaylab.local:8080` mit `header_up Host {host}` (über den
  internen Namen, damit die Weiterleitung auch bei einem DHCP-Adreßwechsel
  stabil bleibt; kein Backend-TLS, da CT 121 unverschlüsseltes HTTP spricht).

## Sicherung und Rücknahme

Vor den Änderungen wurden Sicherungen und SHA256-Prüfsummen in geschützten
Host-Verzeichnissen angelegt:

- Host `proxmox2`:
  `/root/.local/jaylab/zb2mqtt-https-20261127T190155Z/dnsmasq.d-before.tar.gz`
  und `dnsmasq.d-sha256.txt` (Verzeichnis `0700`, Dateien `0600`).
- Host `proxmox`:
  `/root/.local/jaylab/zb2mqtt-https-20261127T190155Z/caddy-sites-before.tar.gz`
  und `caddy-sites-sha256.txt` (Verzeichnis `0700`, Dateien `0600`).

Gezielter Rückweg bei Bedarf:

1. Auf CT 131 `/etc/caddy/sites/zb2mqtt.caddy` entfernen, Konfiguration mit
   `caddy-pilot validate --config /etc/caddy/Caddyfile --adapter caddyfile`
   prüfen und `systemctl reload caddy-pilot` ausführen.
2. Auf CT 101 `/etc/dnsmasq.d/97-jaylab-zb2mqtt.conf` entfernen,
   `dnsmasq --test` prüfen und `systemctl restart dnsmasq` ausführen.

## Abnahme

| Prüfung | Ergebnis | Status |
|---|---|---|
| Internes DNS (UDP & TCP gegen `192.168.10.6`) | `zb2mqtt.jaylab.org` A `192.168.10.18`; AAAA/HTTPS NODATA; `zb2mqtt.jaylab.local` A `192.168.40.250` | Bestanden |
| Öffentliches DNS (`1.1.1.1`) | `zb2mqtt.jaylab.org` A, AAAA und HTTPS liefern `NXDOMAIN` | Bestanden |
| TLS-Zertifikat (`zb2mqtt.jaylab.org`) | Aussteller `Let's Encrypt` (`CN = YE2`), SAN `DNS:zb2mqtt.jaylab.org`, gültig 27.11.2026 bis 25.02.2027, Prüfung ohne Ausnahmen erfolgreich | Bestanden |
| HTTPS (`GET https://zb2mqtt.jaylab.org/`) | HTTP 200, Seitentitel `Zigbee2MQTT` | Bestanden |
| WebSocket (`wss://zb2mqtt.jaylab.org/api`) | Handshake `Open`, 43 Byte Text empfangen | Bestanden |
| Bestehende Dienste | `dnsmasq` und `caddy-pilot` aktiv; `https://https-pilot.jaylab.org/` HTTP 200 | Bestanden |
