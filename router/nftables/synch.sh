scp -i ~/.ssh/id_ed25519 nftables.nft root@192.168.10.3:/etc/nftables.conf
ssh -i ~/.ssh/id_ed25519 root@192.168.10.3 'systemctl restart nftables; conntrack -F; systemctl status nftables'
