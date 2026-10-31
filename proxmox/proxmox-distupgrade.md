# Upgrade docu

## bookworm --> trixie
```bash
#!/bin/bash

# Script to upgrade APT sources from Debian bookworm to trixie
# WARNING: This modifies system configuration files. Run with caution.

set -e  # Exit on error

echo "Upgrading APT sources from 'bookworm' to 'trixie'..."

# Replace bookworm with trixie in the main sources.list file
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list

# Replace bookworm with trixie in all .list files in sources.list.d directory
find /etc/apt/sources.list.d -name "*.list" -exec sed -i 's/bookworm/trixie/g' {} \;

# Update package lists
apt update

echo "Upgrade complete!"
```

`apt upgrade --without-new-pkgs`
`apt full-upgrade`
`apt autoremove;apt autoclean`
`reboot`