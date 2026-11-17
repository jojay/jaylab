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
