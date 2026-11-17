#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd -- "$here/../.." && pwd)
config=${DNSMASQ_SSH_CONFIG:-$repo/.local/access/ssh_config_wsl}
target=${DNSMASQ_SSH_TARGET:-jaylab-dnsmasq}
if [[ ${1:-} == --help ]]; then
    echo 'Aufruf: bash router/dnsmasq/synch.sh'
    echo 'Optional: DNSMASQ_SSH_CONFIG und DNSMASQ_SSH_TARGET.'
    echo 'Synchronisiert zehn Dateien mit Sicherung, Syntaxprüfung und Rücknahme.'
    exit 0
fi
[[ $# == 0 && $target =~ ^[a-zA-Z0-9_.@-]+$ && $target != -* ]]
[[ -f $config ]] || { echo "SSH-Konfiguration fehlt: $config" >&2; exit 1; }
files=(hosts dhcphosts.conf dnsmasq.cnames.conf dnsmasq.conf
       90-jaylab-https-pilot.conf 91-jaylab-grafana.conf 92-jaylab-authentik.conf
       93-jaylab-proxmox.conf 94-jaylab-nodered.conf 95-jaylab-synology.conf)
payload=$(mktemp -d)
trap 'rm -rf -- "$payload"' EXIT
sources=()
for file in "${files[@]}"; do
    [[ -f $here/$file && ! -L $here/$file ]]
    sed 's/\r$//' "$here/$file" > "$payload/$file"
    sources+=("$payload/$file")
done
opts=(-F "$config" -o BatchMode=yes -o StrictHostKeyChecking=yes)
stage=$(ssh "${opts[@]}" "$target" 'umask 077; mktemp -d /root/jaylab-dnsmasq-sync.XXXXXXXX')
[[ $stage =~ ^/root/jaylab-dnsmasq-sync\.[a-zA-Z0-9]+$ ]]
echo "Arbeitsverzeichnis und Sicherung auf dem Ziel: $stage"
scp "${opts[@]}" "${sources[@]}" "$target:$stage/"
ssh "${opts[@]}" "$target" "bash -s -- $stage" <<'REMOTE'
set -euo pipefail
stage=$1
[[ $stage =~ ^/root/jaylab-dnsmasq-sync\.[a-zA-Z0-9]+$ && -d $stage && ! -L $stage ]]
[[ $(id -u) == 0 ]]
exec 9>/run/lock/jaylab-dnsmasq-sync.lock
flock -n 9
systemctl is-active --quiet dnsmasq
/usr/share/dnsmasq/systemd-helper checkconfig
files=(hosts dhcphosts.conf dnsmasq.cnames.conf dnsmasq.conf
       90-jaylab-https-pilot.conf 91-jaylab-grafana.conf 92-jaylab-authentik.conf
       93-jaylab-proxmox.conf 94-jaylab-nodered.conf 95-jaylab-synology.conf)
targets=(/home/hosts /home/dhcphosts.conf /home/dnsmasq.cnames.conf
         /etc/dnsmasq.d/dnsmasq.conf /etc/dnsmasq.d/90-jaylab-https-pilot.conf
         /etc/dnsmasq.d/91-jaylab-grafana.conf /etc/dnsmasq.d/92-jaylab-authentik.conf
         /etc/dnsmasq.d/93-jaylab-proxmox.conf /etc/dnsmasq.d/94-jaylab-nodered.conf /etc/dnsmasq.d/95-jaylab-synology.conf)
umask 077
mkdir "$stage/before"
different=0
for i in "${!files[@]}"; do
    dst=${targets[i]}
    [[ -f $stage/${files[i]} && ! -L $dst ]]
    if [[ -e $dst ]]; then
        [[ -f $dst ]]
        cp -a -- "$dst" "$stage/before/${files[i]}"
    else
        touch "$stage/before/${files[i]}.absent"
    fi
    if ! cmp -s -- "$stage/${files[i]}" "$dst"; then different=1; fi
done
if [[ $different == 0 ]]; then
    echo 'Alle zehn Dateien identisch; kein Neustart.'
    exit 0
fi
committed=0
rollback() {
    status=$?
    trap - EXIT HUP INT TERM
    if [[ $committed == 0 ]]; then
        set +e
        failed=0
        for i in "${!files[@]}"; do
            if [[ -f $stage/before/${files[i]}.absent ]]; then
                rm -f -- "${targets[i]}" || failed=1
            else
                cp -a -- "$stage/before/${files[i]}" "${targets[i]}" || failed=1
            fi
        done
        /usr/share/dnsmasq/systemd-helper checkconfig && systemctl restart dnsmasq || failed=1
        systemctl is-active --quiet dnsmasq || failed=1
        echo "Synchronisierung fehlgeschlagen; Rücknahmefehler=$failed; Sicherung: $stage/before" >&2
        exit 1
    fi
    exit "$status"
}
trap rollback EXIT
trap 'exit 1' HUP INT TERM
for i in "${!files[@]}"; do
    install -m 0644 -o root -g root -- "$stage/${files[i]}" "${targets[i]}"
done
# Vollständige tatsächliche Includes prüfen, bevor der Dienst sie einliest.
/usr/share/dnsmasq/systemd-helper checkconfig
systemctl restart dnsmasq
systemctl is-active --quiet dnsmasq
for entry in synstation.jaylab.org:192.168.10.18 https-pilot.jaylab.org:192.168.10.18 grafana.jaylab.org:192.168.10.18 login.jaylab.org:192.168.10.18 nodered.jaylab.org:192.168.10.18 pve.jaylab.org:192.168.10.4 pve2.jaylab.org:192.168.10.7 pve3.jaylab.org:192.168.10.13; do
    domain=${entry%%:*}
    expected=${entry#*:}
    [[ $(dig @192.168.10.6 "$domain" A +short +time=2 +tries=1) == "$expected" ]]
    [[ $(dig @192.168.10.6 "$domain" A +tcp +short +time=2 +tries=1) == "$expected" ]]
    for kind in AAAA TYPE65; do
        answer=$(dig @192.168.10.6 "$domain" "$kind" +short +time=2 +tries=1)
        [[ -z $answer ]]
    done
done
committed=1
echo "Synchronisiert; Syntax, Dienst und Split-DNS geprüft. Sicherung: $stage/before"
REMOTE

