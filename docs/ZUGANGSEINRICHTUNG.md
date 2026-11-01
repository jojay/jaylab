# Einrichtung der Verwaltungszugänge

Stand 1. November 2026: Die Verwaltungszugänge aller 13 inventarisierten
Komponenten sind eingerichtet und geprüft: drei Proxmox-Hosts, DNS und Firewall
als LXC, PBS, drei Cisco-Switches, zwei Fritzboxen und zwei Repeater.
Die physische Port-/Bridgezuordnung bleibt ein eigener offener Teil von Z01.

Auftrag vom 1. November 2026: Zugriff auf die Netzwerkkomponenten einrichten.
Die Einrichtung umfaßt die benötigten Verwaltungszugänge; Routing, Bridges,
Segmentregeln und bestehende Benutzerzugänge werden dafür nicht umgebaut.

## Nachgewiesener Ausgangspunkt

Der vorhandene WSL-Schlüssel erlaubt root-Anmeldung auf `proxmox`, `proxmox3`
und `dnsmasq`. Über die bereits vertrauenswürdige Clusterverbindung von
`proxmox` ist `proxmox2` erreichbar. DNS ist CT 101, Firewall CT 103, beide
auf `proxmox2`. Die drei Proxmox-Hosts verwenden gemeinsam
`/etc/pve/priv/authorized_keys` über ihren jeweiligen root-SSH-Pfad.

## Konkrete Änderung

Der vorhandene besondere Windows-Schlüssel
`%USERPROFILE%\.ssh\id_ed25519_proxmox_codex` wurde zusätzlich in die gemeinsame
SSH-Schlüsselliste der drei Hosts aufgenommen. Die neue Zeile ist auf Quelle
`192.168.10.241` begrenzt und deaktiviert Agent- und X11-Weiterleitung.
Vorhandene Einträge blieben erhalten. Der tatsächlich verwendete Zugang erfolgt
über den bestehenden WSL-Schlüssel; DNS und Firewall benötigten keine weitere
Schlüsselinstallation. PBS erhielt dessen öffentlichen Schlüssel über den Gastagenten.

Das Werkzeug [Install-JaylabPublicKey.py](../scripts/Install-JaylabPublicKey.py)
arbeitet zunächst lesend; nur `--apply` hängt einen fehlenden Schlüssel an.
Es prüft das öffentliche Ed25519-Format, legt eine datierte Sicherung an und
erhält den Proxmox-Symlink. Es ändert keine sshd-Einstellungen und startet
keinen Dienst neu. Die Zugangserweiterung gilt bei Proxmox durch die gemeinsame
Datei für alle drei Clusterhosts.

Hostschlüssel werden über den funktionierenden, geprüften SSH-/Clusterzugang
direkt aus Hosts und Containern bezogen. Eine lokale SSH-Konfiguration mit
eigener `known_hosts`-Datei liegt unter `.local/access/`; private Schlüssel
bleiben an ihrem bestehenden Ort. Dadurch wird die globale SSH-Konfiguration
des Benutzers nicht ersetzt.

## Rückweg und Abnahme

Der funktionierende WSL-Schlüssel und die Clusterverbindung bleiben erhalten.
Eine fehlerhafte neue Schlüsselzeile kann darüber anhand des Kommentars
`jaylab-agent-windows` und ihres öffentlichen Schlüssels gezielt entfernt werden;
die gesamte Schlüsselliste nicht durch eine ältere Kopie ersetzen, falls inzwischen
andere Einträge hinzugekommen sind. Die datierte Sicherung dient zum Vergleich.
Bei DNS/Firewall bleibt zusätzlich `pct exec` vom Proxmox-Host verfügbar.

Nach Einrichtung je Ziel über den neuen nativen SSH-Zugang `id` und `hostname`
prüfen. SSH-Hostschlüsselprüfung bleibt eingeschaltet. Ein erfolgreicher
Wiederholungslauf soll keine zweite Schlüsselzeile erzeugen.

## Noch getrennt einzurichten

Cisco-Zugänge sind inzwischen wie unten dokumentiert geprüft.
Fritzbox und Repeater erhalten den tatsächlich unterstützten lokalen
Verwaltungsweg; eine SSH-Schnittstelle wird nicht vorausgesetzt. Keine Kennwörter in Git
oder Chat ablegen; einen vorhandenen Gerätezugang oder eine angemeldete Oberfläche
für die Ersteinrichtung nutzen.

## Zusätzlicher Befund

CT 101 (DNS) und CT 103 (Firewall) besitzen denselben Ed25519-Hostschlüssel
aus einem früheren Template. Er wurde über `pct exec` auf beiden Geräten
nachgewiesen. Die Erneuerung muß bestehende Hostschlüsselbindungen der Clients
berücksichtigen und wird als eigener Schritt behandelt.

## Tatsächlich erreichter Stand am 1. November 2026

| Gerät | Zugang | Nachweis |
| --- | --- | --- |
| proxmox | WSL-Profil `jaylab-proxmox` | root, hostname, Proxmox VE 9.2.21 |
| proxmox2 | WSL-Profil `jaylab-proxmox2` | root, hostname, Proxmox VE 9.2.21 |
| proxmox3 | WSL-Profil `jaylab-proxmox3` | root, hostname, Proxmox VE 9.2.21 |
| DNS, CT 101 auf proxmox2 | WSL-Profil `jaylab-dnsmasq` | root, hostname, Debian 13 |
| Firewall, CT 103 auf proxmox2 | WSL-Profil `jaylab-firewall` | root, hostname, Debian 13 |
| PBS, VM 115 auf proxmox3 | WSL-Profil `jaylab-pbs` | root, hostname, PBS 4.2.8-1 |
| Cisco16, CBS350-16T-2G | SSH.NET, `jay`, bestätigter Hostschlüssel | CLI, Version 3.2.0.89, Berechtigungsstufe 15 |
| Cisco8, SG250-08 | SSH.NET, `jay`, bestätigter Hostschlüssel | CLI, Version 2.5.9.15, Berechtigungsstufe 15 |
| Cisco162, CBS350-16T-2G | SSH.NET, `jay`, bestätigter Hostschlüssel | CLI, Version 3.2.0.89, Berechtigungsstufe 15 |
| Kabel-Fritzbox, 192.168.20.5 | FRITZ!Box 6670 Cable | HTTPS/TR-064, Benutzer `fritz7964`, BoxAdmin readwrite, FRITZ!OS 8.25 |
| Mesh-Fritzbox, 192.168.20.4 | FRITZ!Box 7530 AX | HTTPS/TR-064, Benutzer `jay`, BoxAdmin readwrite, FRITZ!OS 8.25 |
| Repeater OG, 192.168.20.194 | FRITZ!Repeater 1200 | HTTPS/PBKDF2-v2, Sitzung und BoxAdmin 2 geprüft; Testsitzung abgemeldet |
| Repeater Keller, 192.168.20.227 | FRITZ!Repeater 1200 | HTTPS/PBKDF2-v2, Sitzung und BoxAdmin 2 geprüft; Testsitzung abgemeldet |

`192.168.20.226` steht noch als repeater-garten in der Lease-Datei, antwortete
bei der HTTP-Prüfung aber nicht. Daraus wird kein dritter aktiver Repeater abgeleitet.
Die beiden Fritzbox-Benutzernamen und ihre Berechtigungen wurden anschließend
durch die authentifizierte Benutzerabfrage bestätigt.

Die besondere Windows-Schlüsselzeile wurde der gemeinsamen Proxmox-Datei
hinzugefügt; der Server nimmt den Schlüssel nun an. Der private Windows-Schlüssel
benötigt jedoch eine Passphrase, und der Windows-SSH-Agent ist deaktiviert.
Eine native unbeaufsichtigte Anmeldung ist deshalb noch nicht möglich. Die
funktionierende Arbeitsverbindung verwendet den bereits vorhandenen WSL-Schlüssel.
Auf DNS und Firewall mußte kein zusätzlicher Schlüssel installiert werden.
Auf PBS wurde der vorhandene öffentliche WSL-Schlüssel über den Gastagenten
hinzugefügt, ebenfalls quellgebunden auf `192.168.10.241`.

Beispiel vom Workspace aus:

```powershell
wsl.exe --exec ssh -F /mnt/c/Users/ajjay/Documents/GitHub/jaylab/.local/access/ssh_config_wsl jaylab-proxmox2 hostname
```

Die lokale Konfiguration und die abgeglichenen Hostschlüssel sind von Git
ausgeschlossen. Die alten globalen SSH-Einstellungen wurden nicht ersetzt.
Die Proxmox-Sicherung liegt auf `proxmox` unter
`/root/.ssh/jaylab-key-backups/authorized_keys.before-jaylab-20261101T104959684537Z`.
Für PBS wurde eine neue root-Schlüsselliste angelegt; die hinzugefügte Zeile ist
an Schlüssel und Kommentar eindeutig identifizierbar.

## Kennwörter für die noch offenen Geräte lokal bereitstellen

Das geprüfte Werkzeug [Set-JaylabCredential.ps1](../scripts/Set-JaylabCredential.ps1)
fordert vorhandene Zugangsdaten im lokalen PowerShell-7-Terminal an. Es speichert
sie unter `.local/access/credentials/GERAET.clixml` mit Windows-DPAPI, gebunden
an diesen Rechner und dieses Windows-Konto. Das Verzeichnis ist auf den Benutzer
und SYSTEM begrenzt. Kennwörter werden weder ausgegeben noch in Git abgelegt.
Ein gespeicherter Eintrag bestätigt noch keine Geräteanmeldung.

Bei weiteren Aufrufen trat ursprünglich ein `Set-Acl`-Fehler zu
`SeSecurityPrivilege` auf. Das Werkzeug setzt jetzt ausschließlich die DACL
über [FileSystemAclExtensions.SetAccessControl](https://learn.microsoft.com/en-us/dotnet/api/system.io.filesystemaclextensions.setaccesscontrol).
Eigentümer und Überwachungsregeln bleiben unberührt; die Kennwortabfrage folgt
erst nach der Rechtevorbereitung. Der Regressionstest
[Test-CredentialStore.ps1](../scripts/tests/Test-CredentialStore.ps1) prüft drei
aufeinanderfolgende Ablagen, DPAPI und den Erhalt vorhandener Einträge mit
künstlichen Daten. Inzwischen sind `cisco8`, `cisco16` und `cisco162` lokal
für Benutzer `jay` hinterlegt und unter dem Windows-Konto lesbar. Der Betreiber
hat die Übereinstimmung der Fingerabdrücke aller drei Geräte nach dem unabhängigen
Abgleich bestätigt. Anschließend wurden die drei Kennwortanmeldungen und die
lesende CLI-Abfrage erfolgreich geprüft.

```powershell
& ./scripts/Set-JaylabCredential.ps1 -DeviceId cisco16 -UserName jay
& ./scripts/Set-JaylabCredential.ps1 -DeviceId cisco8 -UserName jay
& ./scripts/Set-JaylabCredential.ps1 -DeviceId cisco162 -UserName jay
```

Vor der Cisco-Anmeldung die Fingerabdrücke im datierten Zugangsbericht über
einen bereits vertrauenswürdigen Gerätezugang abgleichen. Ein `ssh-keyscan`
allein bestätigt sie nicht. Die lokale Ablage ändert kein Gerätekennwort.

Fritz-Geräte können je nach unterstütztem Dienst über ihre Weboberfläche oder
TR-064 verwaltet werden; Umfang und Benutzerrechte sind am Gerät nachzuweisen.
Nicht jede Aktion ist für unbeaufsichtigte Ausführung geeignet: Die
[Herstellerbeschreibung](https://fritz.support/resources/TR-064_First_Steps.pdf)
beschreibt Rechte sowie zusätzliche Bestätigungen für bestimmte Aktionen.
Diese Schutzmechanismen bleiben Bestandteil des Verwaltungswegs.

## Vorbereitete Cisco-Anmeldung

Die erneute SSH-Aushandlung ohne Anmeldung ergab unverändert:

| Ziel | Beobachteter RSA-Fingerabdruck |
| --- | --- |
| cisco16, 192.168.10.1 | `SHA256:b9TvBDJWG4osQgUD4Bu8lEhU8ZYu88U1HleH8wX6rxA` |
| cisco8, 192.168.10.2 | `SHA256:1pIlLyLFcttJeK78++lWb+PRg/wS65DczqV8kvERwyA` |
| cisco162, 192.168.10.16 | `SHA256:cuUaBFciMFvmgMpsRY5aqA6VSzkPiubnxU+BDKhUa3k` |

Übereinstimmung mit früheren Messungen ist kein unabhängiger Identitätsnachweis.
Für die Ersteinrichtung gibt es zwei unterschiedliche Grundlagen: Abgleich über
einen bereits vertrauenswürdigen Gerätezugang oder ausdrückliche Entscheidung
des Betreibers, diese IP-/Fingerabdruckpaare als ersten Vertrauensstand zu verwenden.
Bei letzterem ist eine bereits bei der ersten Verbindung bestehende Täuschung
nicht ausgeschlossen. Der Betreiber hat den unabhängigen Abgleich am Gerät
gewählt und anschließend die Übereinstimmung aller drei Fingerabdrücke bestätigt.
Die bestätigten IP-/SHA256-Paare sind lokal in
`.local/access/cisco-hostkeys-approved.json` fest hinterlegt. Ein anderer
Fingerabdruck wird weiterhin vor der Anmeldung abgewiesen.

### Abgleich am Gerät

Modelle laut Betreiber: `cisco8` ist ein SG250-08; `cisco16` und `cisco162`
sind CBS350-16T-2G. Terminalzugang ist laut Betreiber möglich. Ob damit eine
lokale Konsole oder ein bereits vertrauenswürdiger SSH-Zugang gemeint ist,
ist noch nicht festgestellt; eine neu aufgebaute, ungeprüfte SSH-Verbindung
liefert keinen unabhängigen Nachweis.

Für die beiden CBS350 an der lokalen Konsole oder über einen bereits
vertrauenswürdigen Verwaltungszugang im privilegierten EXEC-Modus (`#`) lesen:

```text
show crypto key mypubkey rsa
```

Der [CBS350-CLI-Leitfaden](https://www.cisco.com/c/en/us/td/docs/switches/lan/csbms/CBS_250_350/CLI/cbs-350-cli-/rsa-and-certificate-commands.html)
bestätigt, daß `mypubkey` die Ausgabe auf den öffentlichen Schlüssel begrenzt.
Nur die Zeile `Public Key Fingerprint` oder den öffentlichen Schlüsselblock
zurückmelden. `show crypto key` ohne `mypubkey` kann auch private Schlüssel zeigen.

Beim SG250 nicht ungeprüft CBS250-/CBS350-Befehlsunterstützung voraussetzen.
Über die Kontext-Hilfe `show crypto key ?` zunächst prüfen, ob `mypubkey`
angeboten wird; erst dann die obige öffentliche RSA-Abfrage verwenden. Ist
der Befehl nicht verfügbar, den RSA-Fingerprint über die bereits vertrauenswürdige
Webverwaltung ablesen. Das
[SG250-Handbuch](https://www.cisco.com/c/en/us/td/docs/switches/lan/csbms/250_/2_5_7/Admin_guide/tesla-250-ag/cb_250_chapter_15.html)
beschreibt dessen SSH-Serververwaltung.

Zuerst Modell und Firmware über Geräteetikett oder bereits vertrauenswürdige
Verwaltung feststellen. Für die Cisco-350-/550-Serie beschreibt das
[Herstellerhandbuch](https://www.cisco.com/c/en/us/td/docs/switches/lan/csbms/350xseries/2_5_7/Administration/tesla-350-550/security.html)
die Anzeige unter `Security > SSH Server > SSH Server Authentication`.
Dort den RSA-Fingerprint nur ablesen. Der gleichnamige Bereich unter
`SSH Client` betrifft andere Server und ist für diesen Vergleich nicht passend.
Bei anderen Modellen den passenden Handbuchpfad verwenden.

Falls die Geräteanzeige 16 durch Doppelpunkte getrennte Hexadezimalbytes
verwendet, dient die folgende MD5-Darstellung derselben beobachteten RSA-Schlüssel
zum Vergleich. Die spätere feste Bindung verwendet weiterhin SHA256:

| Gerät | IP | MD5-Darstellung für ältere Geräteanzeigen |
| --- | --- | --- |
| cisco16 | 192.168.10.1 | `44:db:1a:ce:f8:68:2b:be:50:63:ca:c2:c1:02:bf:8a` |
| cisco8 | 192.168.10.2 | `12:08:05:17:2e:53:28:a5:15:76:f3:64:3e:4f:ee:e8` |
| cisco162 | 192.168.10.16 | `3a:5c:0a:99:ca:3f:2f:e2:6e:cc:af:82:a5:cb:a0:4d` |

Bevorzugt den vollständigen öffentlichen RSA-Hostschlüssel über den unabhängigen
Zugang beziehen und daraus SHA256 berechnen. Keine privaten Schlüssel oder
vollständigen Gerätekonfigurationen weitergeben. Schlüssel beim Ablesen weder
neu erzeugen noch ersetzen. Ein neuer SSH-Aufruf mit ignorierter Prüfung ist
kein unabhängiger Vergleichsweg.

Bei künftigen Abweichungen bleibt die Anmeldung gesperrt; nicht automatisch
einen neuen Schlüssel übernehmen.

[Test-JaylabCisco.ps1](../scripts/Test-JaylabCisco.ps1) verwendet die
lokalen DPAPI-Zugänge erst nach einer passenden Bestätigung in
`.local/access/cisco-hostkeys-approved.json`. Die Prüfung lehnt einen anderen
Fingerabdruck vor der Authentifizierung ab. Ohne weitere Option prüft sie nur
die Anmeldung. `-ReadIdentity` liest zusätzlich Version und Berechtigungsstufe
über eine Shell. Keine dieser Prüfungen ändert die Switch-Konfiguration.

```powershell
# Ohne Kennwortverwendung: Schlüssel beobachten und die Verbindung ablehnen.
& ./scripts/Test-JaylabCisco.ps1 -ProbeOnly

# Erst nach bestätigten Hostschlüsseln: genau ein Anmeldeversuch je Ziel.
& ./scripts/Test-JaylabCisco.ps1

# Zusätzlich nur show version und show privilege ausführen.
& ./scripts/Test-JaylabCisco.ps1 -ReadIdentity
```

Die Bibliothek [SSH.NET 2026.0.0](https://www.nuget.org/packages/SSH.NET/2026.0.0)
und ihre benötigten Abhängigkeiten liegen ausschließlich lokal unter
`.local/tools/sshnet/`. [Initialize-JaylabSsh.ps1](../scripts/Initialize-JaylabSsh.ps1)
bezieht festgelegte Versionen von NuGet und prüft die SHA512-Paketwerte aus
dem offiziellen Katalog. Die [Herstellerbeispiele](https://sshnet.github.io/SSH.NET/examples.html)
beschreiben die verwendete Fingerabdruckprüfung vor der Anmeldung.
Die Werkzeuge benötigen PowerShell ab Version 7.4.

Geprüft wurden die echte Aushandlung mit allen drei Switches bei absichtlicher
Ablehnung der Hostschlüssel sowie die lokale Sperre bei fehlender Bestätigung.
Nach Bestätigung wurden alle drei Anmeldungen und die CLI mit `show version`
und `show privilege` geprüft. Alle melden Berechtigungsstufe 15.

Cisco8 bot zunächst ausschließlich `publickey` an. Der erste Anmeldeversuch
mit dem Kennwortverfahren konnte deshalb nicht erfolgreich sein. Eine anschließende
Abfrage mit `-AuthenticationMethodsOnly` verwendete keine gespeicherten Kennwörter.
Der Betreiber aktivierte danach selbst die Kennwortanmeldung. Die erneute
Prüfung war erfolgreich. Der anschließende lesende Vergleich zeigte
`ip ssh password-auth` sowohl in der laufenden als auch in der Startkonfiguration.
Es wurde dabei nichts gespeichert oder verändert.

## Fritzbox-Zugänge: geprüft

Die beiden DPAPI-Einträge sind vorhanden und lesbar: `fritz-mesh` für Benutzer
`jay`, `fritz-cable` für `fritz7964`. Die Geräte veröffentlichen TR-064 auf
Port 49000 und bieten TLS auf 443 und 49443 an. Die reguläre Windows-Prüfung
scheitert an selbstsignierten Zertifikaten und dem vom IP-Ziel abweichenden Namen.
Der Betreiber hat beide Zertifikatsfingerabdrücke bestätigt. Erst danach wurden
die gespeicherten Zugänge über fest gebundenes HTTPS verwendet.

| Gerät | Adresse | SHA256 des beobachteten Zertifikats auf 443 und 49443 |
| --- | --- | --- |
| Mesh, 7530 AX | 192.168.20.4 | `BA543778ABE089D07D9C478B057CE72C5B0C5ABC965431B6DB682192AB14DCE9` |
| Cable, 6670 | 192.168.20.5 | `7AAF07858A79C9BCFDDF11472C897EE9056F16D0AB71B4B4613840A52B894889` |

Beide Zertifikate sind laut gemessenen Feldern vom 25. Oktober 2026 bis
15. Januar 2038 gültig. Der Betreiber bestätigte den unabhängigen Abgleich
beider Fingerabdrücke. Diese Bestätigung ist lokal in
`.local/access/fritz-certificates-approved.json` festgehalten. Die allein aus
einer Netzbeobachtung gespeicherten `.cer`-Dateien wären kein unabhängiger Beleg.

[Get-JaylabFritzCertificate.ps1](../scripts/Get-JaylabFritzCertificate.ps1)
erfaßt nur öffentliche Zertifikate und lehnt im TLS-Callback jedes Zertifikat
ab. Es liest keine Zugangsdaten und führt keine Geräteanmeldung durch.

[Test-JaylabFritz.ps1](../scripts/Test-JaylabFritz.ps1) ist für die anschließende
lesende Prüfung vorbereitet. Es verlangt zuvor bestätigte Zertifikate in
`.local/access/fritz-certificates-approved.json`. Die Prüfung bindet TLS an
genau SHA256, Geräteadresse, Port 49443, HTTPS und die Gültigkeitszeit.
Es werden weder globale Zertifikatspeicher geändert noch allgemeine
Zertifikatsprüfungen abgeschaltet; Umleitungen und Proxys sind für diesen
Client deaktiviert. Zugangsdaten werden ausschließlich für Digest-Anmeldung
am vorgesehenen HTTPS-Ziel im Speicher verwendet.

Ausgeführte Abfragen sind `LANConfigSecurity:X_AVM-DE_GetCurrentUser` zum Nachweis
des tatsächlichen Benutzers und seiner Rechte sowie `DeviceInfo:GetInfo` für
Modell und Version. Beide Dienste und die Benutzerabfrage sind in den vom
Gerät veröffentlichten Beschreibungen vorhanden. Grundlage ist die
[TR-064-Herstellerbeschreibung](https://fritz.support/resources/TR-064_First_Steps.pdf).
Es werden keine Einstellungen verändert und keine zusätzlichen Bestätigungen abgeschaltet.

Der [Offline-Test](../scripts/tests/Test-TlsPinning.ps1) besteht: falsche
Fingerabdrücke, Adressen, Ports, HTTP sowie abgelaufene und noch nicht gültige
Zertifikate werden abgewiesen. Die Sperre bei fehlender Zertifikatsbestätigung
ist ebenfalls geprüft. Beide Anmeldungen waren erfolgreich: 7530 AX als `jay`
mit gemeldeter Version `256.08.25`, 6670 Cable als `fritz7964` mit `284.08.25`.
Beide Benutzer melden für `BoxAdmin` die Berechtigung `readwrite`. Es wurden
keine Geräteeinstellungen geändert.

## Repeater-Zugänge

Beide Repeater bieten HTTPS auf 443 und 49443 sowie eine eingeschränkte
TR-064-Beschreibung auf 49000 an. `DeviceInfo` ist vorhanden, der bei den
Fritzboxen verwendete Dienst `LANConfigSecurity` dagegen nicht. Die
Web-Anmeldebeschreibung bietet PBKDF2-v2 ohne veröffentlichte benannte Benutzer.
Der Betreiber bestätigte eigene bzw. unterschiedliche Gerätekennwörter;
Fritzbox-Kennwörter wurden dafür nicht wiederverwendet.

| Gerät | Adresse | Bestätigter SHA256-Fingerabdruck für 443 und 49443 |
| --- | --- | --- |
| OG, repeater-1 | 192.168.20.194 | `D5A586F49BE0E76B7FC3406BFDA0B5926ECE3AA93220A696257DF24C95ECCEF0` |
| Keller, repeater-2 | 192.168.20.227 | `C1C80382B7F2A3F41B053E5724DC47A8F5BB2F251633A91C9D64B9F2D0A7D0A0` |

Der Betreiber bestätigte beide Fingerabdrücke. Die feste Bindung für den
Webzugang steht lokal in `.local/access/repeater-certificates-approved.json`.
Gerätekennwörter werden mit `Set-JaylabCredential.ps1 -PasswordOnly` erfaßt;
`password-only` ist dabei nur eine lokale Ablagebezeichnung, kein Gerätebenutzer.

[Test-JaylabRepeater.ps1](../scripts/Test-JaylabRepeater.ps1) verwendet
zertifikatsgebundenes HTTPS, die PBKDF2-v2-Anmeldung und eine anschließende
Prüfung der erhaltenen Sitzung. Sitzungskennungen und Challenge-Antworten
werden nicht ausgegeben oder in URLs übertragen. Die Testsitzung wird am Ende
abgemeldet. Bestehende Sperrzeiten führen zum Abbruch; nach Ablehnung wird nicht
automatisch erneut versucht. Es werden keine Geräteeinstellungen geändert.
Grundlage ist die [Herstellerbeschreibung zur Session-ID](https://fritz.support/resources/HTTP_Session-ID_DE.pdf).
Der [PBKDF2-Test](../scripts/tests/Test-FritzChallenge.ps1) besteht mit dem
öffentlichen Testvektor dieser Beschreibung.

Ergebnis: Beide Repeater erfolgreich angemeldet, Sitzungen gegengeprüft,
Rechte `App=2` und `BoxAdmin=2` gelesen, beide Testsitzungen erfolgreich
abgemeldet. OG hatte zunächst abgewiesen; erst nach erneuter lokaler Ablage
des Gerätekennworts durch den Betreiber wurde genau ein weiterer Versuch
ausgeführt, der erfolgreich war.
