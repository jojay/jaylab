# Änderung: HTTPS und SSO für drei Proxmox-Knoten

## Auftrag und Kandidat

Beauftragte Anbindung von `proxmox`, `proxmox2` und `proxmox3`.
Lokale Browsernamen direkt auf Port 8006: `pve.jaylab.org` → `.10.4`,
`pve2.jaylab.org` → `.10.7`, `pve3.jaylab.org` → `.10.13`.
Keine Knotenumbenennung, Bridge-/Routing-/Firewalländerung oder neue
öffentliche Tunnelroute. Der alte öffentliche Name `proxmox.jaylab.org`
bleibt als bestehender, gesondert zu behandelnder Zugang erhalten.

Alle drei Knoten sind erreichbar und verwenden noch dasselbe am
15. Februar 2024 abgelaufene benutzerdefinierte Webzertifikat. Die internen
Clusterzertifikate werden nicht ersetzt. Bestehendes ACME-Konto `jaylaborg`
für Let's Encrypt Produktion weiterverwenden; DNS-01 mit dem vorhandenen,
auf `jaylab.org` begrenzten DNS-Token und eigenem Proxmox-Plugin `cf-jaylab`.
Je Knoten ein eigenes Zertifikat und native Erneuerung über Proxmox.

Der bestehende gemeinsame OIDC-Realm `authentik` zeigt auf die aufgegebene
Installation. Neues Authentik-Provider-/Anwendungspaar für den Cluster,
exakte Callbacks für alle drei Browsernamen. Vorhandenes `jay@authentik`
mit seinen Gruppen `admingruppe` und `administratorgruppe` erhalten;
keine neuen ACLs und keine automatische Gruppenübernahme. `root@pam` und
SSH bleiben erhalten. Kein automatisches Anlegen weiterer Benutzer.

## Prüfung und Rückweg

Vorher Knotenkonfiguration, Webzertifikat und privaten Schlüssel sowie
Realm-/Benutzerkonfiguration geschützt auf den Hosts sichern. SSH über
gebundene Hostschlüssel bleibt vom Webzertifikat und OIDC unabhängig.
Erst einen Knoten umstellen und TLS mit normalem Systemvertrauen prüfen,
dann die anderen. ACME-Zertifikatsinstallation lädt nur den Webdienst neu;
kein Host- oder Gastneustart.

DNS-Ergänzung gegen vollständige Includes prüfen und nur diese Datei
aktivieren. A/AAAA/HTTPS sowie Namen von Arbeitsplatz und Knoten prüfen.
OIDC-Discovery/JWKS auf allen Knoten, Benutzer-/ACL-Erhalt, positive und
negative Anwendungsbindung prüfen. Browser-SSO auf allen drei Namen,
Konsole und lokaler PAM-Notzugang sind eigene Abnahmeschritte.

Bei Fehlern eigenes DNS-Include zurücknehmen; auf dem betroffenen Knoten
gesicherte `pveproxy-ssl.pem`/`.key` und vorherige ACME-Konfiguration
wiederherstellen, `pveproxy` neu laden und SSH/Webzustand prüfen. Für OIDC
gezielt die gesicherten Realmwerte zurücksetzen, andere Realms und ACLs
erhalten. Alte Zertifikate bleiben als Rückweg abgelaufen; für Verwaltung
steht weiterhin der geprüfte SSH-Zugang bereit.

Stand: eingerichtet und Zertifikate/SSO auf allen drei Knoten vom Betreiber
 am 15. November 2026 bestätigt. Belege und Geheimnisse ausschließlich unter `.local/`
beziehungsweise `/root/jaylab-proxmox-sso-20261115/` auf den Knoten.

## Ergebnis und Abnahme

- Drei eigene Let's-Encrypt-Zertifikate über `cf-jaylab` und das vorhandene
  Konto `jaylaborg` installiert. Pilot zuerst, danach die anderen Knoten.
  HTTPS liefert auf allen drei Namen HTTP 200 mit normalem Systemvertrauen.
  `pve-daily-update.timer` ist auf allen Knoten aktiv; eine tatsächliche
  spätere automatische Erneuerung ist damit noch nicht nachgewiesen.
- `router/dnsmasq/93-jaylab-proxmox.conf` nach vollständiger Syntaxprüfung
  aktiviert. A über UDP/TCP geprüft; AAAA/HTTPS ohne Antwortdaten.
  Alle zuvor vorhandenen DNS-Dateien blieben bytegleich.
- Gemeinsamer Realm `authentik`: Issuer
  `https://login.jaylab.org/application/o/proxmox/`, Client `jaylab-proxmox`,
  Benutzerzuordnung über `username`/`preferred_username`, automatische
  Benutzeranlage aus. Drei exakte Callbacks ohne abschließenden Schrägstrich:
  `https://pve.jaylab.org:8006`, `https://pve2.jaylab.org:8006` und
  `https://pve3.jaylab.org:8006`.
- Eigene Authentik-Gruppe `jaylab-proxmox-users` mit dem bestehenden `jay`.
  Eine OIDC-Anwendung und zwei zusätzliche Portalkacheln. Anwendungsprüfung
  erlaubt `jay` und verweigert dem vorhandenen deaktivierten Testkonto
  ohne Gruppenzugehörigkeit den Zugriff. Das ersetzt keinen vollständigen
  negativen Browser-Anmeldeversuch mit einem aktiven fremden Konto.
- Discovery, JWKS und vom jeweiligen Knoten erzeugte OIDC-Weiterleitung
  geprüft. `/etc/pve/user.cfg` einschließlich ACLs blieb auf allen Knoten
  bytegleich. Bestehende Administratorgruppen von `jay@authentik` erhalten.
- Betreiber bestätigt ausdrücklich Zertifikate und SSO auf allen drei Knoten.
  Gastkonsole, tatsächliche Rollenwirkung, frischer PAM-Login, Authentik-Ausfall,
  Abmeldung und Rechteentzug bleiben gesonderte Abnahmepunkte.
- `synch.sh` enthält jetzt alle acht verwalteten Dateien und prüft sechs
  DNS-Namen. Bash-Syntax und simulierte Übertragung, unveränderte Wiederholung
  sowie Rücknahme bei Syntax-/Neustartfehlern erfolgreich geprüft.
- Vorherige und aktuelle Zertifikats-/Realm-/ACME-Konfiguration der drei
  Hosts außerhalb der Hosts mit Windows-DPAPI gesichert und Entschlüsselung
  geprüft. Native Authentik-Datenbanksicherung nach Einrichtung erneuert und
  verschlüsselt exportiert. Wiederherstellung dieser neuen Sicherungen auf
  einem Ersatzsystem bleibt ungetestet; DPAPI benötigt das Windows-Profil.

Der bestehende öffentliche Tunnel `proxmox.jaylab.org` bleibt unverändert.
Die neuen Namen sind lokale Direktzugänge. Die frühere Forderung „nur intern“
ist wegen dieses bestehenden Nebenpfades noch nicht vollständig umgesetzt;
SSO ist nur für die drei genannten neuen Browseradressen eingerichtet.