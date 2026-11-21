# Änderung: Cloudflare-Access-Rückruf für Paperless

## Befund und Änderung

Am 19. November 2026 führte die Cloudflare-Anmeldung für
`paperless.jaylab.org` auf dem Desktop zu Grafana. Paperless CT 116 läuft auf
`proxmox`; der Connector CT 124 erreichte über `paperless.jaylab.local` die
Paperless-Anmeldeseite. Die gemeinsame Access-Anwendung `dfderp` enthält fünf
öffentliche Hostnamen. Bei nicht ausdrücklich gesetzter Einstellung verteilt
Cloudflare bei fünf Hostnamen Cookies über eine Umleitungskette. Der Grafana-Name
wird auf dem Desktop lokal auf Caddy aufgelöst; der Access-Rückruf trifft dort
Grafana statt Cloudflare. Nach der Änderung bestätigte der Betreiber, daß die
Paperless-Anmeldeseite nach Cloudflare Access wieder erscheint.

Über die Cloudflare-API wurde `eager_redirect_cookie_setting` für die bestehende
Anwendung auf `false` gesetzt. Die Zugriffspolitiken, Identitätsanbieter und
alle fünf Ziele blieben beim API-Rücklesevergleich unverändert. Damit werden
Anwendungscookies bei Besuch des jeweiligen Hostnamens ausgestellt. Der anonyme
Aufruf von Paperless, ERPNext, ERPNext-Altstand und Proxmox wird weiterhin zu
Cloudflare Access umgeleitet. Auch ein über eine öffentliche Cloudflare-Adresse
erzwungener Grafana-Aufruf leitet anonym zu Access. Angemeldete Tests stehen
für die übrigen Dienste noch aus.

## Sicherung und Rückweg

Vorherstand, Kandidat, API-Antwort, Rücklesung und Rücknahme-Body liegen unter
`.local/changes/2026-11-19-paperless-access/`. Der Rücknahme-Body setzt die
vorher wirksame Cookie-Verteilung ausdrücklich wieder auf `true`. Vor einer
Rücknahme aktuellen Anwendungsbestand mit dem Nachherstand vergleichen und
konkurrierende Änderungen erhalten. Anschließend denselben API-Endpunkt mit
dem Rücknahme-Body aufrufen und Ziele sowie Richtlinien erneut prüfen.

## HTTPS und Absicherung des bisherigen Headers

Paperless 1.14.5 akzeptierte bereits `X-authentik-username` als Remote-User,
obwohl nginx den vom Client gelieferten Header durchließ. nginx entfernt ihn
nun; Tests mit einem manipulierten Header über IPv4, IPv6 und Caddy führten
zur Anmeldeseite. Es wurde kein SSO-Vertrauenspfad aktiviert. Die gesicherte
nginx-Vorfassung liegt auf `proxmox` unter
`/root/.local/jaylab/paperless-header-20261119/nginx-paperless.before`. Sie
enthält die unsichere Headerbehandlung und ist kein geeigneter Dauerzustand.

Das abgelaufene nginx-Zertifikat wurde durch ein Zertifikat der vorhandenen
Jaylab Automation CA für `paperless.jaylab.local` und `192.168.40.221` ersetzt;
der private Schlüssel blieb erhalten. Das Backend-Zertifikat läuft am
19. November 2027 ab und muß gesondert erneuert werden. Caddy CT 131 bedient
`paperless.jaylab.org` mit einem automatisch verwalteten Let's-Encrypt-
Zertifikat und überprüft Namen und CA des Backends. Der Cloudflare-Tunnel
`dfderp` wurde von Version 48 auf 49 geändert: nur die Paperless-Regel zeigt
jetzt mit Namensprüfung auf Caddy; andere Regeln stimmen beim Rücklesen überein.
Der Connector erreichte Caddy mit gültigem Zertifikat. Vorherstand und Rückweg
liegen unter `.local/changes/2026-11-19-paperless-access/tunnel/`.

dnsmasq CT 101 erhielt ausschließlich `96-jaylab-paperless.conf`, das intern
A auf `192.168.10.18` und keine öffentlichen AAAA-/HTTPS-Antworten liefert.
Vollständige Kandidatenprüfung, Dienstneustart und Abfrage bestanden. Vor einer
Rücknahme die Datei auf den SHA256-Wert
`2c31785014b44b00bbf7b30125aa97844e0063e8766a4a294efbd420c745b1e4` prüfen,
nur diese Datei entfernen, `systemd-helper checkconfig` prüfen und dnsmasq
neu starten. Der DNS-Hostzugang über `proxmox2` und `pct exec 101` ist bestätigt.

Die bisherige Paperless-URL bleibt für Altnutzer erhalten; die neue Adresse
ist zusätzlich als vertrauenswürdiger CSRF-Origin gesetzt. Die frühere
Konfiguration liegt auf `proxmox` im genannten Verzeichnis als
`paperless.conf.before`. HTTPS mit normaler Zertifikatsprüfung, Anmeldungseite
und ein CSRF-geschützter Test mit ungültigen Zugangsdaten bestanden. Der
Betreiber bestätigte anschließend die echte Anmeldung und Dokumentübersicht
im Heimnetz ohne Zertifikatswarnung.

## Nachfolgende Änderung

Paperless wurde am 21. November 2026 auf Version 3.5.1 aktualisiert und an
Authentik OIDC angebunden. Der lokale Notzugang bleibt aktiv; bestehende Konten
müssen ihre Authentik-Verbindung einmal im Paperless-Profil herstellen. Der
Authentik-Host ist weiterhin nur im Heimnetz erreichbar. Der Cloudflare-Tunnel
`dfderp` führt Paperless weiter über Caddy mit geprüfter TLS-Verbindung.

Einzelheiten zu Upgrade, SSO, Zertifikaten, Abnahme und offenen Schritten stehen
in [Änderung: Paperless-Upgrade, SSO und Zertifikatsverwaltung](AENDERUNG-PAPERLESS-UPGRADE-SSO-2026-11-21.md).
