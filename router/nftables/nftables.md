# Links

## Flows

[nftables-wiki](https://wiki.nftables.org/wiki-nftables/index.php/Main_Page)

[schema netfilter](./resources/schema_netfilter.txt) orig from: [Plouf](http://www.plouf.fr.eu.org/bazar/netfilter/schema_netfilter.txt)

[packet-flow](https://en.wikipedia.org/wiki/Netfilter#/media/File:Netfilter-packet-flow.svg)


nft list table inet filter
nft list table nat
nft list table ip
nft list table ip nat
nft list table
nft list table ip
nft list table ip nat


watch nft table ip nat
watch nftable table ip nat
watch nft table ip nat
watch nft table ip
watch nft table ip nat
watch nft table ip nat
watch nft table inet filter
nft list table inet filter
nft list table inet filter inbound_private
nft list table inet filter chain inbound_private
nft list table inet filter
nft list table inet filter | grep counter
nft list table nat
nft list table inet filter > grep counter
nft list table inet filter | grep counter
nft list table nat
nft list table inet filter

Musiccast:
https://telekomhilft.telekom.de/t5/Geraete-Zubehoer/Yamaha-MusicCast-Ports-Router/td-p/4439206
UDP 1900
UDP 5353
UDP 51100
UDP 51200
UDP 61100

TCP 80
TCP 49154
TCP 51000

https://de.yamaha.com/de/support/faq/audio_visual/WIFI_and_Network_trouble_shooting.html: UDP 1900, UDP 5353, UDP 51100, UDP 51200, UDP 61100, TCP 80, TCP 49154, TCP 51000.


# IPv6
activated:
sudo nano /etc/sysctl.conf
net.ipv6.conf.all.forwarding=1
sysctl -p

then on dnsmasq host
sysctl -w net.ipv6.conf.all.accept_ra=2


printf 'net.ipv4.ip_forward=1\n' >/etc/sysctl.d/99-router.conf
printf 'net.ipv6.conf.all.forwarding=1\n' >>/etc/sysctl.d/99-router.conf
sysctl --system


ip route get 192.168.20.4
ping -c 3 -I 192.168.20.3 192.168.20.4
sysctl net.ipv4.ip_forward
sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.enp2s0.rp_filter
nft list ruleset
tcpdump -ni enp2s0 host 192.168.20.4