# Änderung: Paperless-Upgrade, SSO und Zertifikatsverwaltung

## Ergebnis

Am 21. November 2026 wurde Paperless-ngx auf CT 116 von 1.14.5 über den
erforderlichen Zwischenstand 2.20.15 auf 3.5.1 aktualisiert. 3.5.1 ist laut
offizieller Release-Seite derzeit die aktuelle Fassung. Die geprobten
Datenbankmigrationen, Django-Systemprüfungen, der Neuaufbau des Suchindexes und
die SQLite-Integritätsprüfung (`ok`) wurden im Produktivsystem wiederholt.
Der Bestand blieb bei 194 Dokumenten und fünf Benutzern.

Vor der Änderung wurde PBS-Sicherung
`ct/116/2026-11-21T13:23:59Z` erstellt. Der ursprüngliche Stand blieb zusätzlich
root-geschützt auf CT 116 erhalten. Die alte Version, Python-Umgebung,
Konfiguration und Einheiten sind weiterhin als Rückweg vorhanden. Der
Cloudflare-Tunnel und die CIFS-Eingangsfreigabe wurden beim Upgrade nicht
umgestellt.

## Betrieb und Erreichbarkeit

Die Einheiten `paperless-webserver`, `paperless-consumer`,
`paperless-scheduler` und `paperless-task-queue` sind aktiv. Der Webserver
lauscht weiterhin nur auf Loopback hinter nginx. Die Worker-Einheit startet
Celery worker; die vorherige Fehlkonfiguration als zweites Celery Beat ist
berichtigt.

CT 116 liefert für `/` die erwartete Umleitung zur Paperless-Anmeldung.
Der lokale HTTPS-Weg über Caddy lieferte die Anmeldeseite mit gültiger
Zertifikatsprüfung. Ein an Cloudflare Edge erzwungener Aufruf lieferte bei
gültiger TLS-Prüfung eine Umleitung zu Cloudflare Access. Der Betreiber hatte
vor dem Upgrade bereits bestätigt, daß nach Access die Paperless-Anmeldung und
Dokumentübersicht erscheinen.

Der Cloudflare-Tunnel `dfderp` enthält weiterhin eine eigene Regel für
`paperless.jaylab.org`: Ziel `https://192.168.10.18:443`, TLS-Prüfung aktiv,
`originServerName` und `httpHostHeader` auf `paperless.jaylab.org`. Die Regel
führt zu Caddy CT 131 und von dort per geprüftem HTTPS zu CT 116. Der zuletzt
gesicherte Cloudflare-API-Rücklesestand weist Tunnelversion 49 aus. Diese
Konfiguration wurde beim Upgrade nicht verändert.

## Authentik-SSO

Paperless nutzt nun django-allauth OIDC mit Authentik. Die Anwendung heißt
`Paperless`, der Provider ist `jaylab-paperless`; die Rückrufadresse ist
streng auf
`https://paperless.jaylab.org/accounts/oidc/jaylab-paperless/login/callback/`
begrenzt. Authentik-Metadaten sind unter der Anwendung `paperless` erreichbar.
Der OIDC-Start aus dem Paperless-Anmeldeformular leitet zu
`login.jaylab.org/application/o/authorize/` weiter.

Neue Paperless-Konten und automatische Anmeldungsanlage sind ausgeschaltet.
Die bisherige lokale Anmeldung bleibt als Notzugang aktiv. Die Paperless-
Anmeldemaske zeigt Authentik als Anbieter. Ein erster OIDC-Aufruf erreichte den
Paperless-Rückruf; Paperless wies die Neuanlage wie vorgesehen zurück, weil das
vorhandene Konto noch nicht mit Authentik verbunden ist. Für die erste
Verknüpfung muß der Betreiber zuerst regulär in Paperless anmelden und dann
über das Benutzer-Menü **My Profile / Mein Profil** die Verbindung zu Authentik
einrichten, wie in der
[Paperless-Anleitung zu SSO](https://docs.paperless-ngx.com/advanced_usage/)
beschrieben. Danach ist eine vollständige SSO-Anmeldung zu prüfen.

Der Authentik-Host `login.jaylab.org` ist weiterhin nur im Heimnetz erreichbar;
für ihn wurde keine Cloudflare-Tunnelroute angelegt. Daher kann SSO von
außerhalb des Heimnetzes über den Paperless-Tunnel den IdP eventuell nicht
erreichen. Die lokale Paperless-Anmeldung bleibt verfügbar. Eine öffentliche
Authentik-Route ist nicht Teil dieser Änderung.

## Zertifikate

Caddy verwaltet das öffentliche Zertifikat für `paperless.jaylab.org` über
ACME DNS-01 mit Cloudflare und erneuert es automatisch. Caddy prüft zusätzlich
die CA und den Namen des Paperless-Backendzertifikats.

Das Backendzertifikat für `paperless.jaylab.local` stammt von der Jaylab
Automation CA 2026 und läuft am **19. November 2027, 20:14:04 UTC** ab. Sein
Fingerabdruck und Ablaufdatum sind in der lokalen PKI-Metadatenliste unter
`.local/pki/automation-2026/public-metadata.json` erfaßt. Die Erneuerung dieses
Backendzertifikats ist manuell; ein automatischer Erneuerungsauftrag ist nicht
eingerichtet. Der private Schlüssel bleibt auf CT 116.

## Konfiguration und Rücknahme

Die aktive OIDC-Konfiguration ist `/opt/paperless/paperless.conf` auf CT 116;
die Vorfassung liegt root-geschützt unter
`/root/.local/jaylab/paperless-upgrade-20261121/paperless.conf.pre-oidc`.

### OIDC-Clientgeheimnis und DPAPI

Das Clientgeheimnis liegt in den beiden Dienstablagen als JSON-Datei mit
`0600 root:root`: `/opt/jaylab-authentik/paperless-client.json` auf VM 132 und
`/root/.local/jaylab/paperless-upgrade-20261121/paperless-oidc-client.json` auf
CT 116. Die aktive Paperless-Konfiguration enthält ebenfalls das Geheimnis;
ihre Rechte sind `0640 root:paperless`, damit der Paperless-Dienst sie lesen
kann. Der Client ist außerdem lokal als
`.local/access/authentik/paperless-client.clixml` abgelegt. Diese Datei
verschlüsselt die JSON-Zeichenfolge mit Windows-DPAPI. Das Wiedereinlesen als
`SecureString` wurde unter dem Windows-Profil `PAPADESK\ajjay` geprüft; die
Datei-DACL erlaubt diesem Benutzer und SYSTEM den Zugriff.

Die DPAPI-Kopie ist an dieses Windows-System und Benutzerprofil gebunden und
kein portabler Wiederherstellungsweg. Sie ist zusätzlicher lokaler Schutz; für
den Dienstbetrieb sind die geschützten Ablagen auf VM 132 und CT 116 maßgeblich.
Die Clixml-Datei liegt unter `.local/` und wurde nicht in dieses Repository
aufgenommen.

Für eine Rücknahme der OIDC-Anbindung nur die Vorfassung der Paperless-
Konfiguration wiederherstellen und die vier Paperless-Einheiten neu starten.
Authentik-Anwendung, Provider und Gruppe bleiben davon unberührt und können
nach Prüfung getrennt entfernt werden. Für einen Rückweg des Versionswechsels
gilt der PBS-Punkt oben sowie die Sicherung und Versionsverzeichnisse auf CT 116.

## Abnahme

| Prüfung | Ergebnis |
| --- | --- |
| Version, Migration und Django-Prüfung | 3.5.1, erfolgreich |
| SQLite-Integrität und Datenbestand | `ok`, 194 Dokumente, 5 Benutzer |
| Paperless-Einheiten | 4 von 4 aktiv |
| OIDC-Anbieter in Anmeldemaske | Authentik sichtbar |
| OIDC-Start | HTTP 302 zu Authentik |
| Lokales HTTPS über Caddy | Anmeldeseite, TLS-Prüfung 0 |
| Cloudflare Edge anonym | Access-Umleitung, TLS-Prüfung 0 |
| OIDC-Aufruf bis Paperless-Rückruf | erreicht; Paperless verweigerte die neue Kontenerstellung wie vorgesehen |
| Vorhandenes Konto verbinden und SSO wiederholen | durch Betreiber im Profil auszuführen |
| OIDC außerhalb des Heimnetzes | IdP ist nicht öffentlich geroutet |
