# Cloudflare-DNS-Zugang für Caddy

Änderung vom 15. November 2026 zu Z07/Z09. Auftrag: die in PowerShell
installierte `cf`-CLI verwenden und den fehlenden DNS-API-Zugang einrichten.
Bestehende Token, Tunnelrouten und Web-DNS-Einträge bleiben erhalten.

## Ausgangspunkt und konkrete Änderung

`cf` 1.0.0-beta.32 stammt laut installiertem Paket aus `cloudflare/cf`.
Das vorhandene Standardprofil kann die aktive Zone `jaylab.org` im
erwarteten Konto lesen und Tokenrechte abfragen. Die heutige API-Aufnahme
bestätigt den zuvor im Dashboard gesehenen Benutzer-API-Token mit DNS-
Schreibrechten und zusätzlichen Kontorechten. `codex-caddy` ist dagegen
ein Access-Service-Token; er wird nicht für DNS-01 verwendet.

Neuer eigener Benutzer-API-Token: **`caddy-dns-jaylab`**. Genau eine
Allow-Richtlinie, ausschließlich Zone `jaylab.org`, genau `Zone Read`
und `DNS Write` (Dashboard: `DNS: Edit`). Keine Konto-/Tunnelrechte,
keine anderen Zonen. Keine feste Quell-IP-Beschränkung, solange der spätere
IPv4-/IPv6-Ausgangspfad des Caddy-Gasts nicht feststeht. Keine automatische
Ablauffrist, damit die spätere Erneuerung nicht unerwartet endet; Widerruf
und kontrollierter Austausch bleiben möglich.

Der Tokenwert wird bei der Anlage nur im Speicher verarbeitet und unmittelbar
mit Windows-DPAPI unter `.local/access/cloudflare/caddy-dns-jaylab.clixml`
gesichert. Das Verzeichnis ist auf das Windows-Konto und SYSTEM begrenzt.
Kein Tokenwert in Git, Chat, Prozeßargumenten oder Klartextprotokollen.
Bei Fehlschlag der lokalen Sicherung wird nur der gerade angelegte Token
widerrufen. Das vorhandene CLI-Profil bleibt unverändert.

## Prüfung und Rückweg

Vor Anlage Zone/Konto und Namenskollision erneut prüfen. Erstellungsauftrag
per CLI-Dry-run prüfen. Anschließend Tokenstatus, genaue Richtlinie und
Zonenlesezugriff mit dem neuen Token prüfen. Einen eigenen kurzlebigen
TXT-Prüfeintrag unter dem Pilotnamen anlegen, lesen und nur anhand seiner
neu erhaltenen Record-ID wieder löschen. Vorherige Einträge nicht ersetzen.
Tokenverwaltung mit dem eingeschränkten Token muß abgewiesen werden.

Bereinigte Metadaten und Prüfergebnisse liegen lokal unter
`.local/changes/2026-11-15-caddy-dns/`. Der Rückweg ist
`cf user tokens delete 909d2f5e88cc8da9fe338db2a4da2364 --force` mit dem bisherigen Verwaltungsprofil,
nach Abgleich von Name und gespeicherter Token-ID. Keine vorhandenen
Zugänge rotieren oder entfernen. Nach einer unklaren CLI-Antwort zuerst
den Bestand lesen, niemals blind einen zweiten Token anlegen.

## Ergebnis

**Angelegt und geprüft.** Token-ID `909d2f5e88cc8da9fe338db2a4da2364`, Status
`active`. Der Erstellungsauftrag bestand zuvor den CLI-Dry-run. Die genaue
Richtlinie wurde nach Anlage erneut gelesen und auf genau die zwei Rechte
und die eine Zone geprüft. Kein Ablaufdatum und keine Vorlaufzeit gesetzt.

| Prüfung | Ergebnis |
| --- | --- |
| Lokale Ablage | DPAPI-Rücklesevergleich erfolgreich; Dateizugriff nur Benutzer und SYSTEM |
| Tokenidentität und Status | Über `cf user tokens verify` mit dem neuen Token bestätigt |
| Zone lesen | `jaylab.org` mit dem neuen Token erfolgreich gelesen |
| DNS schreiben/lesen | Eigener TXT-Wert unter `_acme-challenge.https-pilot.jaylab.org` angelegt und identisch zurückgelesen |
| DNS-Rücknahme | Ausschließlich eigene Record-ID gelöscht; Prüfname anschließend wieder leer |
| Negativtest | `cf user tokens list` mit dem neuen Token als Berechtigungsfehler abgewiesen |
| Erhalt des Bestands | Vorhandener Token weiterhin mit identischem Namen, Status, Änderungszeitpunkt und Richtlinien vorhanden |
| Keine Doppelanlage | Genau ein Token mit Namen `caddy-dns-jaylab` vorhanden |

Der API-Zugang ist im Caddy-LXC CT 131 in Betrieb. Der Token wurde nur im
Speicher entschlüsselt und über SSH-Standardeingabe direkt nach
`/etc/caddy/cloudflare.env` übertragen; `root:root`, 0600 bestätigt. Kein
Klartextexport, keine Ausgabe und kein Token in Prozeßargumenten. DNS-01
gegen Staging und Produktion bestanden; das Challenge-TXT des Testnamens
war danach über die CLI nicht mehr vorhanden. Windows-DPAPI ist an diesen
Rechner und dieses Benutzerkonto gebunden; zusätzlich ist die geschützte
Dienstdatei Bestandteil der geprüften vollständigen PBS-Sicherung.
