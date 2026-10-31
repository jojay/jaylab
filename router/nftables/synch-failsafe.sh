scp -i ~/.ssh/id_ed25519 nftables-failsafe2.nft root@192.168.10.3:/etc/nftables.conf
ssh -i ~/.ssh/id_ed25519 root@192.168.10.3 'conntrack -F; systemctl restart nftables; systemctl status nftables'
