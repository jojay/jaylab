scp -i /home/jay/.ssh/id_rsa stubby.yml root@dnsmasq:/etc/stubby
ssh -i /home/jay/.ssh/id_rsa root@dnsmasq 'systemctl restart stubby'