# Änderung: Synology HTTPS und SSO

## Auftrag und erhobener Bestand

Beauftragt: Synology an Authentik anbinden und ein gültiges Zertifikat
einrichten. Bestehende lokale Konten, Freigaben und Speicherdienste erhalten.

Am 15. November 2026 ist DSM unter `192.168.50.1:5000` beziehungsweise
`synstation.jaylab.local:5001` erreichbar. Modell und DSM-Version sind noch
nicht authentifiziert erhoben. Ein gespeicherter Verwaltungszugang wurde
in der vorhandenen Zugangsablage nicht gefunden; Browseranmeldung angefragt.

Das auf Port 5001 vorgelegte Zertifikat hat CN `synstation.jaylab.local`,
Aussteller `jaylab Intermediate CA`, Ablauf 18. Juli 2023. SAN enthält den
lokalen Namen und die alte IP `192.168.40.173`. SHA-256-Fingerabdruck:
`18:1E:D3:81:60:49:90:3C:52:83:11:23:C5:12:7C:8E:03:1F:4D:5D:D3:20:D1:F3:C9:46:27:D9:6F:6D:C5:21`.
Dies ist eine Beobachtung des vorgelegten Zertifikats, kein unabhängiger
Vertrauensnachweis. Keine Anmeldedaten darüber übertragen.

## Kandidat und Voraussetzungen

Vorgesehener Browsername: `synstation.jaylab.org`; noch nicht aktiviert.
Vor Auswahl zwischen direktem DSM-Zertifikat und bestehendem Caddy die
DSM-Zertifikatszuordnung, Erneuerungsmöglichkeit und bisherigen Dienstnamen
aufnehmen. Keine neue öffentliche Freigabe oder Speicheränderung.

Eigener OIDC-Provider und eigene Anwendung in Authentik; RSA-Signierung,
Scopes `openid profile email`, exakte Callback-Adresse aus DSM. Zugriff
zunächst auf das vorhandene Authentik-Konto `jay` begrenzen. DSM-Benutzername
vor Aktivierung bestätigen und gegebenenfalls eine nur für diesen Provider
geltende `preferred_username`-Zuordnung verwenden. Bestehende lokale
Anmeldung erhalten; keine automatische Weiterleitung erzwingen.

## Sicherung, Rückweg und Abnahme

Vor Aktivierung DSM-SSO-Einstellungen, Zertifikatszuordnungen und vorhandene
Zertifikate geschützt sichern; Rückweg über bestehende lokale Anmeldung
prüfen. Bei Fehlern vorherige SSO-Einstellungen und Zertifikatszuordnung
wiederherstellen. Kein NAS-Neustart und keine Änderung an iSCSI/SMB/NFS.

Prüfen: TLS-Kette und Name, lokale DNS-Auflösung, DSM-Erreichbarkeit des
Authentik-Issuers/JWKS, Anmeldung mit dem richtigen vorhandenen Benutzer,
unveränderte Rechte und lokaler Notzugang. Erneuerung und betroffene
Synology-Anwendungen gesondert abnehmen.

Stand: Bestandsaufnahme; noch keine Synology-, DNS-, Zertifikats- oder
Authentik-Änderung aktiviert. Nächste Voraussetzung ist die administrative
DSM-Anmeldung und die bestätigte Kontozuordnung.

Quelle: [Authentik – Synology DSM](https://integrations.goauthentik.io/infrastructure/synology-dsm/).

## Ergänzte Bestandsaufnahme und konkreter HTTPS-Kandidat

DSM-Anmeldung im Browser bestätigt. DS116, DSM 7.1.1-42962 Update 9;
`jay` ist ein aktives lokales Konto. OIDC bereits eingeschaltet, aber mit
Issuer der aufgegebenen Authentik-Installation und Claim `name`; Synology-SSO
ebenfalls eingeschaltet. Keine automatische SSO-Auswahl. OIDC-Dialog bietet
keine Kontotyp-Auswahl. LDAP-Verbindung meldet einen Fehler, LDAP-Benutzer-
register sind ausgegraut. Diese bestehende Verzeichnisanbindung bleibt erhalten.

HTTPS-Kandidat: zusätzlicher Import `Jaylab DSM Backend 2026`, ausgestellt
von der vorhandenen Automation CA, SAN `synstation.jaylab.local`,
`synstation.jaylab.org`, `192.168.50.1`, Laufzeit ein Jahr. Nur Systemstandard
für den DSM-Webzugang umstellen; ausdrückliche Zuordnungen für FTPS, LDAP,
Log Receiving, Drive, Storage Console und bisherigen Reverse-Proxy erhalten.
Altes Zertifikat bleibt als Rückweg vorhanden. Bei Fehlern Systemstandard
wieder auf das alte Zertifikat stellen. Kein Zertifikat löschen.

Caddy soll `synstation.jaylab.org` mit DNS-01-Zertifikat bedienen und das
Backend `.50.1:5001` gegen die Automation CA und `synstation.jaylab.local`
prüfen. DNS erst nach erfolgreicher Backend- und Frontendprüfung aktivieren.
Nur eigenes Include und eigene Caddy-Datei bei Fehler zurücknehmen.
Die jährliche Backend-Erneuerung bleibt ein gesonderter Betriebspunkt.

## Zertifikatsimport am 17. November 2026

Das zusätzliche Zertifikat `Jaylab DSM Backend 2026` wurde im angemeldeten
DSM importiert. Schlüssel und Zertifikat vorab auf Übereinstimmung geprüft.
SHA-256: `5D1BE2E80FB1C7D89BB37C214F03E6146236D5AB97679A5F49A665F478DDBD3D`.
Ablauf: 15. November 2027. Der ursprüngliche Importdialog blieb auf
„Processing“ stehen; eine unabhängig geöffnete zweite DSM-Sitzungsansicht
bestätigt den gespeicherten Eintrag samt Beschreibung und Ablaufdatum.
Kein zweiter Import ausgelöst. Der alte Eintrag bleibt als Standard erhalten;
keine Dienstzuordnung geändert. Die Fenster-Dateiauswahl gelang mit
Alt+N, Eingabe des vollständigen Dateinamens und Eingabetaste.

Der private Schlüssel liegt in der zugriffsbeschränkten lokalen Ablage;
eine zusätzliche Windows-DPAPI-Sicherung wurde erstellt. Der Import allein
aktiviert weder den geplanten Caddy-Zugang noch Split-DNS oder SSO.
Nächster Schritt bleibt die gezielte DSM-Webzertifikatszuordnung und danach
die geprüfte Caddy-/DNS-Aktivierung.

## HTTPS-Aktivierung am 17. November 2026

Der Betreiber hat das Backend-Zertifikat als DSM-Standard aktiviert.
Live geprüft: Port 5001 liefert den oben genannten Fingerabdruck; die
Zertifikatsliste zeigt nun zwei Einträge, das alte abgelaufene Zertifikat
ist nicht mehr sichtbar. Diesen geänderten Betreiberstand erhalten.

Caddy-Route `pilot/https/synology.caddy` aktiviert. Backend-TLS mit der
Automation CA und dem Namen `synstation.jaylab.local` erfolgreich geprüft.
Frontend-Zertifikat von Let's Encrypt YE1 für `synstation.jaylab.org`,
gültig bis 15. Februar 2027; automatische Verwaltung durch Caddy.
Windows-curl und Linux-curl bestätigen gültige TLS-Prüfung und HTTP 200.
Ein späterer Abruf überschritt zehn Sekunden; DSM-Ladezeiten weiter beobachten.

Split-DNS `95-jaylab-synology.conf` aktiviert: A zeigt auf `192.168.10.18`,
AAAA und HTTPS liefern keine Ausweichadresse. DNS über UDP, TCP und den
IPv6-Resolver geprüft. Vollständiger Kandidat vor Aktivierung syntaktisch
geprüft; vorherige Dateien anhand ihrer Hashes unverändert bestätigt.
`synch.sh` um die zehnte Datei und deren Abnahme ergänzt. Beim Gesamtabgleich
wurden nur Kommentare der Hauptdatei angeglichen; ein zweiter Lauf bestätigte
alle zehn Dateien identisch und führte keinen Neustart aus. Sicherung:
`/root/jaylab-dnsmasq-sync.sglT6GYA/before` auf dem DNS-LXC.

Bestehende Caddy-Dienste HTTPS-Pilot, Grafana, Authentik und Node-RED antworten
weiterhin mit gültigem TLS. Keine öffentliche DNS-/Tunnelroute eingerichtet.
Gezielter Rückweg: eigenes DNS-Include entfernen, DNS-Syntax prüfen und Dienst
neu starten; eigene Caddy-Site entfernen, Gesamt-Konfiguration mit den
bestehenden Dienstumgebungen validieren und Caddy neu laden. Direkter DSM-Zugang
bleibt bestehen. Keine privaten Schlüssel in den Repositorybestand übernommen.

Browserdiagnose: Das neue Frontend-Zertifikat ist gültig. Die DSM-Anmeldeseite
lädt jedoch zusätzlich Inhalte von `https://synstation.jaylab.local:5001`;
Edge kennzeichnet diesen Ursprung wegen Zertifikatsfehlern als unsicher.
Der bestehende Synology-SSO-Verweis wird deshalb gesondert geprüft.

Der Synology-SSO-Serververweis wurde von
`https://synstation.jaylab.local:5001` auf `https://synstation.jaylab.org`
umgestellt. DSM bestätigt „Changes applied.“. Client-ID, Aktivierung und
OIDC-Einstellungen blieben unverändert. Rückweg: denselben URL-Eintrag auf den
oben genannten vorherigen Wert zurückstellen. Dies ist noch keine fertige
Authentik-Anbindung; der alte OIDC-Issuer bleibt gesondert zu ersetzen.

Abschließende Browserprüfung: Nach dem Schließen ausschließlich des eigenen
Testfensters und Start einer neuen InPrivate-Sitzung zeigt Edge bei
`https://synstation.jaylab.org/#/signin` „Websiteinformationen anzeigen“
statt „Nicht sicher“. Die Loginseite wird geladen. Der HTML-Abgleich belegt,
daß `synoSSO-1.0.0.js` jetzt ebenfalls über `synstation.jaylab.org` kommt.
Der direkte `.local:5001`-Zugang bleibt wegen der internen CA gesondert zu
bewerten. Lokale Anmeldung über den neuen Namen beim Betreiber angefragt.
Workspace-Prüfung, Shell-Syntaxprüfung und `git diff --check` bestanden.
Vorhandene Änderung an `.gitignore` wurde erhalten.

## Authentik-SSO: Fortsetzung am 17. November 2026

Betreiber meldet beim Synology-SSO-Reiter „Invalid SSO client application“.
Authentik-Bestand lesend geprüft: Noch kein Synology-Provider und keine
Synology-Anwendung vorhanden. Gemeinsamer vorhandener Signierschlüssel ist RSA.

Konkreter Kandidat: eigene Anwendung/Provider `synology` / `jaylab-synology`,
vertraulicher OIDC-Client, strikte Redirect-URI `https://synstation.jaylab.org`,
Scopes openid/email/profile, Claim preferred_username, Subject aus E-Mail,
RSA-Signierung und Zugriff ausschließlich für jay über eigene Gruppe.
Keine DSM-Konten oder Rechte automatisch anlegen. Vor DSM-Aktivierung die
veraltete Konfiguration aufnehmen; lokale Anmeldung bleibt erhalten. Alten
Synology-SSO-Client erst bei geprüftem OIDC-Kandidaten deaktivieren, damit der
Reiter auf den vorgesehenen Anmeldedienst verweist. SSO-Serverpaket erhalten.
Rückweg: neue OIDC-Verknüpfung deaktivieren und lokal anmelden; Authentik-
Anwendung zunächst ausblenden bzw. Gruppenbindung sperren. Alte aufgegebene
Authentik-Installation ist kein funktionierender Rückweg.

Authentik-Kandidat angelegt: Provider 4, Client-ID `jaylab-synology`, Anwendung
`synology`, eigene Gruppe nur mit jay. Bis zur Abnahme im Portal ausgeblendet.
Discovery `https://login.jaylab.org/application/o/synology/.well-known/openid-configuration`
mit gültigem TLS und RS256 geprüft. Clientgeheimnis ausschließlich im geschützten
Authentik-Verzeichnis und als Windows-DPAPI-Datei in der vorhandenen lokalen
Zugangsablage gesichert. DSM ist noch nicht auf diesen Client umgestellt.
Die am 17. November geöffnete Browsersitzung steht bei der Kennworteingabe;
lokale Anmeldung beim Betreiber angefragt. Kein Kennwort ausgelesen.

Lokale DSM-Anmeldung nach Betreiberbestätigung im Browser nachgewiesen.
OIDC-Dialog lesend abgeglichen; bisheriger Issuer und Client-ID stammen noch
aus dem Altbestand. Neue öffentliche OIDC-Werte im Dialog vorbereitet, aber
noch nicht gespeichert. Der Betreiber muß den neuen Application key einsetzen
und speichern; Browsersteuerung verlangt für geänderte Authentifizierungsdaten
eine Benutzerübergabe. Lokaler DPAPI-Kopierhelfer vorbereitet, nicht ausgeführt.
Keine Kontotyp-Auswahl im DSM-7.1.1-Dialog vorhanden; die tatsächliche Anmeldung
mit lokalem jay ist deshalb weiterhin ein offener Abnahmepunkt.

Nach Betreiberbestätigung „fertig“ gespeicherte DSM-Konfiguration geprüft:
Client-ID jaylab-synology, Authentik-Token- und Authorize-Endpunkte sowie
Redirect-URI korrekt vorhanden. Der alte Synology-SSO-Dienst war weiterhin
angekreuzt; diesen gezielt abgeschaltet und Apply ausgeführt. Ein frischer
HTTP-Abruf enthält danach das alte Synology-SSO-Skript nicht mehr. OIDC bleibt
eingeschaltet; lokale Anmeldung und bestehende LDAP-Konfiguration erhalten.
Frische InPrivate-Abnahme begonnen, ohne vorhandene Verwaltungssitzung abzumelden.

Berichtigt am 17. November 2026: Die Synology-Anwendung soll nach der
Authentik-Anbindung eingeblendet werden. Als bevorzugter Benutzername für die
DSM-Zuordnung gilt `jay` (Claim `preferred_username`). Das Einblenden und die
manuelle Providerprüfung stehen noch aus; OIDC-Anmeldung und Gruppenbindung sind
daher weiterhin nicht als abgenommen bestätigt.

## Einblendung und Provider-Abgleich am 18. November 2026

Betreiber vermutet ein Problem in Authentik, da `synstation` nicht als SSO-Anwendung
im Portal gelistet wird. Zugriff auf die Authentik-API über das lokale Bootstrap-
Zertifikat `.local/access/authentik/bootstrap.clixml` hergestellt und Bestand geprüft:

1. Anwendung `synology` (`Synology DSM`, PK `98505ada-5b36-4bf5-be13-c51e867d96e9`)
   war vorhanden und über die Gruppe `jaylab-synology-users` korrekt an `jay`
   gebunden, besaß jedoch den Status `meta_hide: true`.
2. Provider 4 (`jaylab-synology`) war auf `sub_mode: user_email` gesetzt und besaß
   nur eine einzige strikte Redirect-URI `https://synstation.jaylab.org`.

Durchgeführte Korrekturen:
- Anwendungssichtbarkeit `meta_hide` über API-PATCH auf `false` gesetzt. Die Kachel
  `Synology DSM` wird für `jay` nun im Authentik-Portal unter `https://login.jaylab.org/`
  aufgeführt.
- Provider 4 vorübergehend auf `sub_mode: user_username` umgestellt. Das setzt
  `sub` auf den Authentik-Benutzernamen, belegt aber keine DSM-Zuordnung über
  `sub` und ersetzt nicht den von der Anleitung geforderten Claim
  `preferred_username`. Die spätere Korrektur steht unten.
- `redirect_uris` um `https://synstation.jaylab.org/` und
  `https://synstation.jaylab.org/webman/sso/sso_login.cgi` erweitert, um Abbrüche
  durch abweichende Schrägstriche oder Callback-Pfade von DSM zu verhindern.
- Der serverseitige Authentik-Richtlinien- und Dashboard-Cache (`app_access_<pk>`)
  wurde über `POST /api/v3/policies/all/cache_clear/` explizit geleert, da Authentik
  den Benutzer-Anwendungsbestand für 300 Sekunden zwischenspeichert.

Rückweg: `meta_hide` kann über denselben API-Aufruf wieder auf `true` gesetzt,
`sub_mode` auf `user_email` und die Redirect-URIs auf den ursprünglichen Einzelwert
zurückgestellt werden.

## Redirect-URI-Korrektur am 18. November 2026

Auf Betreiberauftrag Provider 4 (`jaylab-synology`) nach der
[Authentik-Synology-Anleitung](https://integrations.goauthentik.io/infrastructure/synology-dsm/)
berichtigt. Vorher waren drei strikte Authorization-Redirect-URIs eingetragen:
`https://synstation.jaylab.org`,
`https://synstation.jaylab.org/` und
`https://synstation.jaylab.org/webman/sso/sso_login.cgi`.
Die beiden zusätzlichen Einträge entfernt; übrig blieb ausschließlich
`https://synstation.jaylab.org`.

Die Live-Prüfung bestätigt genau diesen einen Eintrag. Client-ID, Client-Typ,
Grant-Typen, Subject-Modus, Issuer-Modus, Signierschlüssel und Scope-Mappings
blieben unverändert. Der öffentliche Discovery-Endpunkt wurde danach mit
gültiger TLS-Prüfung abgerufen; Issuer und RS256-Angabe stimmen. Ein DSM-Login
wurde in diesem Schritt nicht ausgeführt.

Fachliche Klarstellung zur vorherigen Begründung des Subject-Modus:
`sub_mode: user_username` setzt den OIDC-Claim `sub`, ersetzt aber nicht
`preferred_username`. Die Authentik-Anleitung verlangt, daß
`preferred_username` dem vorhandenen DSM-Benutzernamen entspricht. Das aktive
Profil-Mapping setzt den Claim auf den Authentik-Benutzernamen; der tatsächlich
ausgestellte ID-Token wurde hier nicht eingesehen.

Rückweg: Provider 4 per API-PATCH wieder auf die drei zuvor vorhandenen
strikten Authorization-URIs setzen. Die übrigen Provider-Felder dabei
unverändert lassen.

## Subject-Modus-Korrektur am 18. November 2026

Auf Betreiberauftrag Provider 4 (`jaylab-synology`) an die
Authentik-Synology-Anleitung angeglichen: `sub_mode` von `user_username` auf
`user_email` gesetzt. Die Live-Prüfung bestätigt den neuen Wert. Redirect-URI,
Client-ID, Client-Typ, Grant-Typen, Issuer-Modus, Signierschlüssel und
Scope-Mappings blieben unverändert. Der öffentliche Discovery-Endpunkt besteht
weiterhin die TLS-Prüfung und weist den erwarteten Issuer sowie RS256 aus.
Ein DSM-Login wurde nicht ausgeführt.

Rückweg: Provider 4 per API-PATCH auf `sub_mode: user_username` setzen; die
übrigen Provider-Felder unverändert lassen.
