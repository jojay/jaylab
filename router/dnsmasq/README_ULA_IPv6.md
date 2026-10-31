# DNSmasq ULA IPv6 Konfiguration

## Überblick

Diese Konfiguration implementiert Unique Local Addresses (ULA) IPv6 für alle Netzwerksegmente in der DNSmasq-Router-Konfiguration.

## ULA IPv6 Adressierung

Das ULA-Präfix `fd00::/8` wird verwendet mit folgender Struktur:
- **fd00:10::/64** - Admin-Netzwerk (192.168.10.0/24)
- **fd00:20::/64** - General-Netzwerk (192.168.20.0/24) 
- **fd00:30::/64** - Familie-Netzwerk (192.168.30.0/24)
- **fd00:40::/64** - IoT-Netzwerk (192.168.40.0/24)
- **fd00:50::/64** - Media-Netzwerk (192.168.50.0/24)
- **fd00:60::/64** - Gast-Netzwerk (192.168.60.0/24)

## Interface-spezifische Konfiguration

### Router Advertisement (RA) und DHCPv6
Jedes Interface erhält:
- **RA (Router Advertisement)**: Für IPv6-Autoconfiguration
- **DHCPv6**: Für verwalte IPv6-Adresszuweisung
- **ra-stateless**: Ermöglicht SLAAC (Stateless Address Autoconfiguration)

### DHCP-Bereiche
- **IPv4**: 192.168.x.100-240 (jedes Subnetz)
- **IPv6**: fd00:x::1000-11ff (jedes Subnetz)

## DNS-Konfiguration

### IPv6 Reverse DNS
Jedes ULA-Subnetz hat entsprechende reverse DNS-Zonen:
```
fd00:10::6 -> 0.1.0.0.0.0.0.0.0.0.0.0.0.0.d.f.ip6.arpa
fd00:20::6 -> 0.2.0.0.0.0.0.0.0.0.0.0.0.0.d.f.ip6.arpa
...
```

### DNS-Server pro Interface
- **Admin**: fd00:10::6 + öffentliche DNS
- **General**: fd00:20::6 + öffentliche DNS  
- **Familie**: fd00:30::6 + öffentliche DNS
- **IoT**: fd00:40::6 + öffentliche DNS
- **Media**: fd00:50::6 + öffentliche DNS
- **Gast**: fd00:60::6 + öffentliche DNS

## Sicherheitsaspekte

### ULA Vorteile
- **Lokal routbar**: Funktioniert nur im lokalen Netzwerk
- **Eindeutig**: Statistisch eindeutig generierte Adressen
- **Nicht Internet-routbar**: Automatischer Schutz vor externer Erreichbarkeit

### Netzwerksegmentierung
- Familie-Netz: Kein NTP-Zugang zum Media-Netz
- Gast-Netz: Nur öffentliche DNS-Server
- Admin-Netz: Vollzugriff auf alle Dienste

## Implementierungsdetails

### Interface-Konfiguration (interfaces)
```bash
iface ethX inet6 static
    address fd00:X0::3
    netmask 64
```

### DNSmasq-Features
- `enable-ra`: Router Advertisement aktiviert
- `ra-stateless`: SLAAC ermöglicht  
- `ra-names`: Namen aus DHCPv6-Leases für RA verwenden
- Interface-spezifische DHCP-Optionen

## Migration von bestehender Konfiguration

Die Konfiguration wurde von öffentlichen IPv6-Adressen (2003:cd:2700:31X0::/64) auf ULA-Adressen (fd00:X0::/64) migriert für:
- Bessere Sicherheit
- Einfachere Verwaltung
- Lokale Kontrolle über IPv6-Adressierung

## Testen der Konfiguration

```bash
# IPv6-Konnektivität testen
ping6 fd00:10::6

# DHCPv6-Leases anzeigen
cat /var/lib/dhcp/dhcpd6.leases

# Router Advertisement prüfen
rdisc6 eth1
```

netsh interface ipv6 reset;netsh interface ipv4 reset; ipconfig /flushdns
netsh interface ipv6 reset; ipconfig /flushdns
netsh interface ipv6 delete address "Ethernet" fd38:21a1:1b97:60::/64

netsh interface ipv6 set interface "Ethernet" state=disabled
netsh interface ipv6 set interface "Ethernet" state=enabled