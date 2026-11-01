# Entwurf der Netzfreigaben

Stand: 1. November 2026. Diese Matrix ist eine Zielrichtung zur Überarbeitung,
keine Beschreibung der aktuell wirksamen Regeln und keine Deployment-Freigabe.
Vor Implementierung echte Quellgeräte, Ziele, Ports und Abhängigkeiten aufnehmen.

| Quelle | Ziel | Vorgesehener Umfang | Abnahme |
| --- | --- | --- | --- |
| Bestimmte Verwaltungsgeräte im Adminnetz | Proxmox, PBS, Firewall, DNS, Cisco, Fritz-Verwaltung | Nur benötigte Verwaltungsdienste, nachgewiesene Benutzer/Rechte | Anmeldung möglich; dieselben Dienste aus IoT/Gast nicht erreichbar |
| Jede berechtigte Zone | Ihr DNS-/DHCP-Dienst, Router und ggf. Zeitdienst | Notwendige Namensauflösung, Adreßbezug und IPv6-Netzfunktionen; keine pauschale Dienstfreigabe | Frischer Client erhält richtige Adresse, DNS und Default-Route; fremde Zone nicht angeboten |
| Familie / General | Internet | Nach erhobenem Bedarf; lokales Routing nicht pauschal freigeben | Normale Nutzung funktioniert, Verwaltungszugriffe bleiben gesperrt |
| IoT | Internet / definierte interne Dienste | Einzelne begründete Abhängigkeiten | Erlaubter Dienst funktioniert; neue Verbindung zur Verwaltung und zu anderen Zonen scheitert |
| Familie | Drucker / benötigte Medien- und IoT-Dienste | Konkrete Geräte und Dienste; Discovery gesondert begründen | Nutzfunktion funktioniert, benachbarte Dienste bleiben gesperrt |
| Bestimmter Anwendungsdienst | Synstation / Datendienst | Nur benötigtes Ziel und Protokoll; z. B. tatsächlichen Paperless-SMB-Pfad prüfen | Anwendung funktioniert; anderes IoT-Gerät erreicht Datenfreigabe nicht |
| Gäste | Internet und erforderliche Netzdienste | Kein Zugriff auf interne Geräte oder Verwaltungsoberflächen | Internet funktioniert; interne Ziele über IPv4 und IPv6 gesperrt |
| Internet | Interne Netze | Keine neuen eingehenden Verbindungen ohne einzeln beauftragten Dienst | Externe Gegenprüfung; Fritzbox-Freigaben, IPv6 und Tunnel berücksichtigen |
| Zonen untereinander, sonstiger Verkehr | Andere Zone | Standardmäßig verweigern | Gezielte Negativtests für jede relevante Grenze |

Für jede konkrete Ausnahme Quelle, Eingangs-/Ausgangsschnittstelle, Ziel,
Transportprotokoll, Port, IPv4/IPv6, Zweck und Beleg festhalten. Bestehende
Verbindungen und Rückverkehr berücksichtigen; ICMPv6 nicht pauschal sperren.
Antwortverkehr ersetzt keine ausdrückliche Erlaubnis für neue Gegenverbindungen.

## Nachweis physischer Isolation

- Je Zone NIC, Bridge, LXC-Schnittstelle, Switchport und WLAN-Anschluß kennen.
- Zwei Zonen dürfen nicht durch eine gemeinsame ungetrennte Layer-2-Verbindung
  zusammenfallen. Verschiedene IP-Netze oder DHCP-Tags beweisen diese Trennung nicht.
- Verkehr innerhalb derselben Broadcast-Domäne kann am Router vorbeigehen.
  Solche Pfade können dessen Forward-Regeln nicht als Nachweis der Isolation nutzen.
- Mesh, Kabel-Fritzbox, statische Routen, Mehrfachanschlüsse von Clients und IPv6
  als mögliche Nebenpfade erfassen. Gast-SSID nicht ungeprüft dem Gastsegment gleichsetzen.

## Prüfnachweis

Je Test tatsächliche Quelle mit Zone/Adresse, Ziel, Protokoll/Port, erwartetes und
gemessenes Ergebnis sowie Datum erfassen. Vom Verwaltungsrechner allein läßt
sich die Sperre für Gäste nicht beweisen. Positive und negative Tests für IPv4
und IPv6 durchführen; fehlendes IPv6 nicht als bestandenen IPv6-Filtertest werten.
Bei Zustandsregeln neue Verbindungen verwenden, ohne pauschal Conntrack zu löschen.
