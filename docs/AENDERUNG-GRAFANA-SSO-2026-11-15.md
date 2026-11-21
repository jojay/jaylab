# Änderung: Grafana als lokaler SSO-Pilot

## Kandidat und Bestandsbindung

Authentik VM 132, Fassung 2026.8.5, lokaler Issuer
`https://login.jaylab.org/application/o/grafana/`. Eigener vertraulicher
OIDC-Client, Authorization Code mit PKCE; Callback ausschließlich
`https://grafana.jaylab.org/grafana/login/generic_oauth`.
Scopes openid, email und profile. Keine automatische Anmeldung, weil der
Issuer zunächst nur aus dem LAN erreichbar ist.

Bestehendes Grafana CT 102, Version 12.4.2: lokaler Administrator ID 5,
gewöhnliches altes OAuth-Konto ID 2 mit der bestätigten Betreiberadresse und
Rolle Viewer in Organisation 1. Dessen bisherige externe Identitätskennung
ist leer. Keine pauschale E-Mail-Zuordnung einschalten. Für genau dieses
Konto die neue stabile Authentik-Benutzer-UUID zuordnen, nachdem die Anmeldung
von `jay` bestätigt ist. Andere Konten, Kennwörter, Dashboards, Datenquellen
und Berechtigungen erhalten. Keine automatische Neuanlage weiterer Benutzer.

Eigene Authentik-Gruppe `jaylab-grafana-viewers`, ausschließlich `jay`.
Anwendungszugriff an diese Gruppe binden und Viewer-Rechte festlegen;
keine Zuweisung von Grafana-Administratorrechten. Bestehende lokale
Grafana-Anmeldemaske und `admin` erhalten. Native Authentik-Sicherung,
isolierter PostgreSQL-Restore und PBS-Vollsicherung sind nachgewiesen.

## Aktivierung, Prüfung und Rückweg

Vor Aktivierung Grafana-INI und SQLite-Datenbank mit geschützter Sicherung
aufnehmen, aktuelle Dateien und Zielzeile erneut abgleichen. Anhalten des
Grafana-Dienstes nur für die begrenzte Identitätsmigration. In einer
Transaktion genau die bisher leere OAuth-Kennung von Benutzer 2 aktualisieren;
keine anderen Auth-Zeilen verändern. Neue Clientgeheimnisse nur in geschützte
Gastdateien übertragen. Unnötige alte TLS-Clientzertifikatangaben ausschließlich
im betroffenen OAuth-Abschnitt entfernen; öffentliche TLS-Prüfung aktiv lassen.

Aus CT 102 Discovery, Token-Endpunkt und JWKS über den lokalen Issuer mit
normaler TLS-Prüfung testen. Dann frische Anmeldung, Viewer-Rolle,
Dashboardzugriff, Verweigerung für ein unberechtigtes Konto und lokalen
Adminzugang prüfen. SSO-Ausfall darf keine anonyme Freigabe ergeben.

Bei Fehlschlag Grafana stoppen, ausschließlich die gesicherte INI und
ursprüngliche Auth-Zuordnung wiederherstellen; Datenbankvollrestore nur nach
Abgleich zwischenzeitlicher Änderungen. Grafana starten und lokalen Login
erneut prüfen. Authentik-Provider deaktivieren bzw. dessen Anwendungsbindung
sperren, Datenbestand zur Untersuchung behalten. Der alte, nicht vorhandene
Authentik-Dienst ist kein Rückweg.

## Aktivierter Stand

Die neue Authentik-Anwendung und der vertrauliche Provider sind angelegt;
Clientkennung `jaylab-grafana`, Provider-ID 1. Anwendung zunächst im
Authentik-Portal während der Einrichtung verborgen. Nach der Meldung des
Betreibers „Keine Anwendungen vorhanden“ wurde `meta_hide: true` als Ursache
bestätigt und auf `false` gesetzt. Zugriff für `jay` bleibt erlaubt;
Provider und Gruppenbindung wurden nicht verändert. Keine Selbstregistrierung oder automatische
Grafana-Benutzeranlage. Der Gruppen-Zugriffstest erlaubt `jay` und verweigert
ein unberechtigtes Testkonto; dieses ist danach deaktiviert worden.

Nach bestätigter Anmeldung und TOTP-Einrichtung wurde genau die vorhandene
Auth-Zeile 1 von Grafana-Benutzer 2 auf seine neue Authentik-UUID gebunden.
Andere Auth-Zeilen unverändert. Datenbank vor Änderung nativ gesichert;
Integritätsprüfung erfolgreich. Nur Abschnitte `auth` und
`auth.generic_oauth` der INI gezielt ergänzt, andere Einstellungen erhalten.
INI vorher SHA256 `6535099d99ea8f3e3c4e6e7f3ca670e7e9827c2be7a8784bfc9eb03e4fc54812`,
nachher `143899384d370f5b778adf79a09ce195bce188173c31714fe6f912406c2abdea`.
Geschützter Rückweg im Gast `/root/jaylab-sso-20261115/` und auf `proxmox`
unter `/root/jaylab-authentik-20261115/grafana-sso/`.

Grafana aktiv, Datenbank gesund, anonymer Dashboard-API-Zugriff HTTP 401.
Anmeldeknopf `Jaylab SSO (LAN)` leitet mit PKCE und korrektem Callback zu
`login.jaylab.org`. Discovery und JWKS direkt aus CT 102 mit normaler
TLS-Prüfung erreichbar; Name wird auf `.10.18` aufgelöst. Nicht authentisierte
Tokenanforderung HTTP 400. ID-Token-Prüfung gegen JWKS ist aktiviert;
E-Mail-Ausweichzuordnung und automatische Anmeldung bleiben deaktiviert.

Beim ersten Browserversuch scheiterte die Rollenauswertung. Der einzelne
Viewer-Ausdruck wurde durch
`contains(groups[*], 'jaylab-grafana-viewers') && 'Viewer'` ersetzt.
Strikte Rollenprüfung und Gruppenbegrenzung bleiben aktiv. Die vorherige
INI liegt zusätzlich unter `grafana.ini.before-role-fix` im geschützten
Gastverzeichnis. Aktuelle INI-SHA256:
`fc5866d913314da2aabd392e741bcb5d6049dbc4a5cf98ab89ed7af8f9dd2228`.
Grafana wurde erfolgreich neu gestartet. Am 15. November 2026 bestätigt der
Betreiber anschließend: „grafana sso funktioniert“. Die SSO-Anmeldung ist
damit als Betreiberabnahme bestanden.

Die Anmeldung mit dem vorhandenen lokalen `admin`-Konto ohne SSO wurde
anschließend ebenfalls vom Betreiber am 15. November 2026 bestätigt.
Der lokale Notzugangstest ist damit bestanden. Ein Test bei tatsächlich
abgeschaltetem Authentik ist dadurch noch nicht belegt.

Die ausdrückliche Prüfung der Viewer-Rolle nach tatsächlichem SSO, Abmeldung,
Rechteentzug und Verhalten bei Authentik-Ausfall stehen noch aus.
Verwaltungskonto-MFA, externes SSO
und Mobilfunkabnahme sind nicht als bestanden bestätigt.
