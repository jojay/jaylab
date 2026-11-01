# IPv6-Korrektur für Amazon Music und Netflix

Stand: 1. November 2026. Aktueller Auftrag unter Z05; U01 wurde vom Betreiber
zurückgestellt. Amazon-Music-Suche in der Android-App und Netflix sind im WLAN
`papalapap` unzuverlässig. Die Musiksuche funktioniert laut Betreiber im
Gast-WLAN. Dessen SSID und Gerätepfad sind noch nicht gesondert aufgenommen.

## Beobachtung und Eingrenzung

Das betroffene Telefon meldet `192.168.60.206`, globale Adressen aus
`2a02:908:c250:9d00::/64` und ULA aus `fd4d:b7b5:44d3::/64`. Die IPv4 liegt
im bisher als Gäste bezeichneten Repository-Segment. Das normale WLAN daher
nicht allein anhand des Segmentnamens dem Fritz-Gastzugang gleichsetzen.
Die Einstellung für Androids privates DNS ist noch unbekannt.

Lesende Messungen am 1. November 2026 ergaben:

- DNS-LXC CT 101 auf proxmox2: dnsmasq 2.91, IPv6-Weiterleitung ausgeschaltet.
  Geladen wird `/etc/dnsmasq.d/dnsmasq.conf`, zusätzlich zur Debian-Hauptdatei.
- In dieser Datei stehen sechs `ra-param=enpXs0,high,10,65535`. Eine passive
  RA-Aufnahme zeigt tatsächlich hohe Routerpriorität und 9000 Sekunden
  Router-Lifetime. Der DNS-LXC bietet sich damit als Standardrouter an,
  obwohl er keine Pakete weiterleitet.
- Die globale IPv6-DNS-Option nennt drei ULA-Adressen; zwei davon sind im
  laufenden DNS-LXC nicht eingerichtet. Auch die zonenbezogenen Optionen
  enthalten solche momentan nicht belegten Adressen.
- A-/AAAA-Abfragen für `music.amazon.de`, `www.netflix.com` und ein Kontrollziel
  über dnsmasq sowie Google antworten erfolgreich; die Kabel-Fritzbox antwortet
  ebenfalls für die geprüften Amazon-Namen. Das belegt diese Namen, nicht alle
  Endpunkte der Android-Anwendungen.
- Nicht angemeldete HTTPS-Aufrufe aus dem DNS-Netzraum funktionieren zu allen
  drei Zielen über IPv4. Über IPv6 scheitern alle drei Verbindungsaufbauten am
  Zeitlimit. Die IPv6-Routenwahl zeigt dabei auf eine andere Schnittstelle des
  DNS-LXC selbst als Next-Hop.
- Der vorhandene fremde IPv6-Router `fe80::ec5:74ff:fe9a:eb5b` ist über
  `enp2s0` erreichbar und beantwortet DNS-Abfragen über IPv6.

Damit sind fehlerhafte Router-/DNS-Ankündigungen belegt. Ob sie sämtliche
Amazon-/Netflix-Störungen erklären, entscheidet die nachfolgende Prüfung
auf dem betroffenen Telefon. Der Windows-Arbeitsplatz hat derzeit nur IPv4
und kann diese IPv6-Clientprüfung nicht ersetzen.

## Konkrete erste Änderung

Nur `/etc/dnsmasq.d/dnsmasq.conf` in CT 101 und die entsprechende
Repository-Datei `router/dnsmasq/dnsmasq.conf` ändern:

1. Sechs RA-Zeilen auf `ra-param=enpXs0,10,0` setzen: Der Dienst kündigt
   Präfixe und DNS weiterhin an, bietet sich mit Router-Lifetime null aber
   nicht mehr als Standardrouter an. Die kurze bestehende Sendeperiode bleibt
   zunächst für das rasche Zurückziehen der falschen Routerrolle erhalten.
2. Die globale und sechs zonenbezogenen IPv6-DNS-Optionen auf `[fe80::]`
   setzen. dnsmasq ersetzt dies durch seine Link-Local-Adresse an der jeweiligen
   Schnittstelle. Damit werden tatsächlich gebundene DNS-Listener genannt.

DNSSEC, IPv4-DHCP, IPv4-Gateways, Upstreams und eingebundene Hosts-/Aliasdateien
bleiben Bestandteil des bisherigen Bestands. Wegen des dokumentierten
SIGHUP-Verhaltens muß dnsmasq für diese Konfigurationsänderung kurz neu starten;
ein Reload allein liest die Hauptkonfiguration nicht neu.

Die vorhandenen Mehrfachpfade und statischen IPv6-Default-Routen im DNS-LXC
bleiben gesondert zu prüfen. Diese Änderung führt weder die spätere
Segmentarchitektur noch neue öffentliche Präfixzuweisungen ein.

## Prüfung und Rückweg

- Der bestätigte SSH-Zugang zum Host wurde ausdrücklich über IPv4 und die
  numerische Adresse `192.168.10.7` geprüft. `pct exec 101 -- id -u` funktioniert
  darüber unabhängig von dnsmasq und dessen IPv6-Ankündigungen. Die Änderung
  betrifft weder diesen Hostzugang noch die IPv4-Routerkonfiguration.
- Original und Kandidat werden mit dnsmasq 2.91 gegen getrennte vollständige
  Kopien der Hauptdatei, Konfigurationsverzeichnisse und eingebundenen Dateien
  geprüft. Die aktiven DNSSEC-Vertrauensanker werden beim Test übernommen.
- Originaldateien mit Prüfsummen, Besitzer und Rechten liegen im lokalen,
  ignorierten Analysebestand sowie gesondert unter einem datierten
  `/root/jaylab-ipv6-ra-*` auf Host und DNS-LXC. Vor Aktivierung werden die
  Originalprüfsummen erneut verglichen; fremde Änderungen nicht überschreiben.
- Ein außerhalb des DNS-LXC laufender Host-Zeitgeber ruft nötigenfalls dessen
  Wiederherstellung per `pct exec` auf. Der Zeitgeber-/Konsolenpfad und die
  Sicherungsprüfsumme werden vorher mit einem Probelauf ohne Konfigurations-
  oder Dienständerung geprüft. Das ist kein vollständiger Restore-Test.
- Zurücknehmen bei fehlgeschlagenem Start, DNS-Ausfall oder fehlerhaften
  neuen RA-/DNS-Antworten. Original atomar zurückschreiben, Besitzer/Rechte
  erhalten und dnsmasq neu starten. Nur die eigene Änderung zurücknehmen.

Abnahme: Dienst aktiv; RA-Lifetime null an allen sechs DNS-Schnittstellen;
passende Link-Local-RDNSS; interne und externe DNS-Abfragen über UDP/TCP und
IPv4/IPv6 erfolgreich; IPv4-Betrieb erhalten. Anschließend am Telefon WLAN
einmal aus-/einschalten, um alte Router-/DNS-Einträge zu verwerfen, und
Amazon-Music-Suche sowie Netflix erneut prüfen. Die Anwendungsmessung bleibt
ein eigener Nachweis neben den Infrastrukturtests.

## Aktivierungsstand

Kandidat und Original sind mit vollständigen Include-Kopien erfolgreich auf
Syntax geprüft. Die Aktivierung und Nachher-Ergebnisse werden nachgetragen.

Technische Referenzen: [dnsmasq-Handbuch](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html)
zu `ra-param`, IPv6-DNS-Platzhaltern und SIGHUP sowie
[Linux-Kernel-Dokumentation](https://docs.kernel.org/networking/ip-sysctl.html)
zu Weiterleitung und Annahme von Router Advertisements.
