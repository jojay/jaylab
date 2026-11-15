#!/bin/bash
set -euo pipefail
umask 077
root=/opt/jaylab-authentik
backup="$root/backups"
install -d -m 0700 "$backup"
exec 9>"$backup/.lock"
flock -n 9
stamp=$(date -u +%Y%m%dT%H%M%SZ)
tmp="$backup/native-$stamp.tmp"
trap 'rm -f -- "$tmp"' EXIT
docker exec jaylab-authentik-postgresql-1 pg_dump -U authentik -d authentik -Fc > "$tmp"
test -s "$tmp"
mv "$tmp" "$backup/native-$stamp.dump"
# Nur eigene native Dumps, sieben Tage lokale Aufbewahrung.
find "$backup" -maxdepth 1 -type f -name 'native-????????T??????Z.dump' -mtime +7 -delete
echo "Native Authentik backup completed: $stamp"
