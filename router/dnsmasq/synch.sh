scp -i /home/vscode/.ssh/id_ed25519 hosts root@192.168.10.6:/home/
scp -i /home/vscode/.ssh/id_ed25519 dhcphosts.conf root@192.168.10.6:/home/
scp -i /home/vscode/.ssh/id_ed25519 dnsmasq.cnames.conf root@192.168.10.6:/home/
scp -i /home/vscode/.ssh/id_ed25519 dnsmasq.conf root@192.168.10.6:/etc/dnsmasq.d/
ssh -i /home/vscode/.ssh/id_ed25519 root@192.168.10.6 'systemctl restart dnsmasq; systemctl status dnsmasq'

