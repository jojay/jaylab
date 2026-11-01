#!/usr/bin/env python3
"""Add one source-restricted Ed25519 key without replacing existing access."""
import argparse
import base64
import datetime
import ipaddress
import json
import os
import pathlib
import struct
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--key', required=True, help='Public Ed25519 key, never a private key')
    parser.add_argument('--authorized-keys', required=True)
    parser.add_argument('--source-address', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    source = str(ipaddress.ip_address(args.source_address))
    fields = args.key.split()
    if len(fields) < 2 or fields[0] != 'ssh-ed25519':
        parser.error('An Ed25519 public key is required')
    data = base64.b64decode(fields[1], validate=True)
    expected = struct.pack('>I', 11) + b'ssh-ed25519' + struct.pack('>I', 32)
    if len(data) != len(expected) + 32 or not data.startswith(expected):
        parser.error('Invalid Ed25519 public key data')
    requested = pathlib.Path(args.authorized_keys).expanduser()
    target = requested.resolve()
    exists = target.exists()
    original = target.read_bytes() if exists else b''
    present = any(fields[1] in line.split() for line in original.decode('utf-8').splitlines()
                  if not line.lstrip().startswith('#'))
    result = {'path': str(target), 'keyAlreadyPresent': present, 'sourceAddress': source,
              'applied': False, 'backup': None}
    if present or not args.apply:
        print(json.dumps(result))
        return
    line = ('from="' + source + '",no-agent-forwarding,no-X11-forwarding '
            + fields[0] + ' ' + fields[1] + ' jaylab-agent-windows\n').encode('utf-8')
    if not target.parent.exists():
        target.parent.mkdir(mode=0o700, parents=True)
    if exists:
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        backup_dir = requested.parent / 'jaylab-key-backups'
        backup_dir.mkdir(mode=0o700, exist_ok=True)
        backup = backup_dir / (target.name + '.before-jaylab-' + stamp)
        backup_fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(backup_fd, 'wb') as stream:
            stream.write(original)
        result['backup'] = str(backup)
    # Append to the real file; preserve a Proxmox shared-file symlink and permissions.
    fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(fd, 'ab') as stream:
        if original and not original.endswith(b'\n'):
            stream.write(b'\n')
        stream.write(line)
        stream.flush()
        os.fsync(stream.fileno())
    result['applied'] = True
    print(json.dumps(result))


if __name__ == '__main__':
    main()
