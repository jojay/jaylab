# Arbeitsweise und Wiederherstellung

## Bestandsaufnahme

Zuerst [Inventar](../inventory/infrastruktur.json),
[Architektur](ARCHITEKTUR.md) und den datierten
[Zugangsbericht](../INFRASTRUKTUR-ZUGAENGE.md) lesen. Nur für den Auftrag
benötigte Geräte untersuchen. Netzscan und Anmeldung sind verschiedene Nachweise.
Version, Uhrzeit, Gerät und verwendete Berechtigung zu jedem Ergebnis festhalten.

Rohdaten und Sicherungen nach `.local/` schreiben; vor einer Übernahme in Git
Kennwörter, Tokens, private Schlüssel, WLAN-Schlüssel und personenbezogene Daten
entfernen. `.gitignore` ersetzt weder Bereinigung noch sichere Speicherung.

## Änderungen vorbereiten

Für eine Änderung mit Betriebswirkung eine konkrete Fassung der
[Änderungsvorlage](vorlagen/AENDERUNG.md) erstellen. Der Umfang des aktuellen
Auftrags bestimmt die Erlaubnis. Ein bereits ausdrücklich beauftragtes Deployment
benötigt keine erneute Freigabe allein wegen dieses Dokuments. Fehlt ein für die
Änderung notwendiger Zugang oder ein nachgewiesener Rückweg, diesen konkreten
Punkt klären und mit unabhängiger Arbeit fortfahren.

Nicht mehrere Abhängigkeiten zugleich umstellen: beispielsweise zuerst DNS
eindeutig machen, anschließend Firewallregeln ändern. Die sinnvolle Reihenfolge
ergibt sich aus dem aufgenommenen Paket- und Verwaltungsweg.

## Prüfung, Aktivierung und Rückweg

1. Laufende Konfiguration und persistenten Startzustand sichern; Sicherung auf
   anderem System erreichbar halten. Bei Proxmox/LXC auch Mounts, Netzwerk,
   Ressourcen und vom Container nicht mitgesicherte Daten erfassen.
2. Unabhängigen Konsolenzugang oder anderen funktionierenden Rückweg prüfen.
   Für Netzänderungen reicht eine zweite SSH-Sitzung über denselben Pfad nicht.
3. Kandidaten getrennt bereitstellen und mit der installierten Version prüfen:
   nftables etwa mit `nft -c -f KANDIDAT`, dnsmasq mit `dnsmasq --test` gegen
   die tatsächlich vorgesehenen Konfigurationsdateien. Absolute Includes müssen
   den bereitgestellten Kandidatenbestand lesen; nicht versehentlich den Altbestand testen.
4. Wiederherstellung vor Aktivierung vorbereiten. Bei Firewall-/Routingänderungen
   einen getesteten zeitgesteuerten Rückweg oder eine gleichwertig verläßliche
   unabhängige Wiederherstellung verwenden. Exakte Befehle, Frist und Auslöser
   je Plattform festlegen, nicht aus einem Dateinamen ableiten.
5. Nur im beauftragten Umfang aktivieren. nftables möglichst als geprüfte
   Transaktion laden; Zuständigkeit gegenüber Proxmox-/Containerregeln klären.
   Keine fremden Tabellen mit `flush ruleset` oder Verbindungen mit `conntrack -F`
   unbesehen entfernen. Bei Cisco running/startup-Konfiguration unterscheiden
   und Speichern oder Rücknahme am konkreten Modell ausrichten.
6. Verwaltung, DNS/DHCP, Internet und die betroffenen positiven/negativen
   Segmenttests einschließlich IPv6 prüfen. Erst nach diesen Nachweisen einen
   aktivierten Rücklauf aufheben und die Persistenz gezielt herstellen/prüfen.
7. Bei fehlgeschlagener Aktivierung oder Abnahme den vorbereiteten Rückweg
   ausführen, Zustand prüfen und Ursache aufnehmen. Nicht wiederholt blind
   neu starten, Kennwörter versuchen oder Regelsätze austauschen.

## Ausfall und Wiederanlauf

RPO (tragbarer Datenverlust) und RTO (tragbare Wiederherstellungsdauer) mit dem
Betreiber festlegen, keine Zahlen erfinden. Abhängigkeiten für Hoststart,
Bridges, Router-/DNS-LXC, Zeit, Storage und Internet aufnehmen. Ein Backupjob
allein bestätigt keine Wiederherstellbarkeit; isolierte Wiederherstellung und
Netzdienste prüfen, ohne doppelte DHCP-/RA-Server ins produktive Netz zu starten.

Nachweislich funktionierende Konfigurationen mit Version und Wiederherstellungsweg
kennzeichnen. Die vorhandene Distupgrade-Notiz ist kein geprüfter Upgradeplan.
