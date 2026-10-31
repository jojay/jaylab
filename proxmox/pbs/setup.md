# Install
Installation on debian 11 as VM on proxmox


# Resizing disk on guest
[docu](https://pve.proxmox.com/wiki/Resize_disks)
1. Increase size of disk in proxmox
2. To make it available assign newly added capacity by booting guest VM making use of gparted iso image. Attach unallocated space to partition
3. Boot guest normal
4. Execute: 
```
root@pbs:~# guest --extents +100%FREE /dev/mapper/pbs-root
  Size of logical volume pbs/root changed from 27.62 GiB (7071 extents) to 91.62 GiB (23455 extents).
  Logical volume pbs/root successfully resized.

  root@pbs:~# df
Filesystem           1K-blocks     Used Available Use% Mounted on
udev                    978592        0    978592   0% /dev
tmpfs                   202324      660    201664   1% /run
/dev/mapper/pbs-root  28332092 27062220         0 100% /
tmpfs                  1011604        0   1011604   0% /dev/shm
tmpfs                     5120        0      5120   0% /run/lock
tmpfs                   202320        0    202320   0% /run/user/0

root@pbs:~# resize2fs /dev/mapper/pbs-root
resize2fs 1.46.5 (30-Dec-2021)
Filesystem at /dev/mapper/pbs-root is mounted on /; on-line resizing required
old_desc_blocks = 4, new_desc_blocks = 12
The filesystem on /dev/mapper/pbs-root is now 24017920 (4k) blocks long.

root@pbs:~# df
Filesystem           1K-blocks     Used Available Use% Mounted on
udev                    978592        0    978592   0% /dev
tmpfs                   202324      660    201664   1% /run
/dev/mapper/pbs-root  94371820 27070708  63152668  31% /
tmpfs                  1011604        0   1011604   0% /dev/shm
tmpfs                     5120        0      5120   0% /run/lock
tmpfs                   202320        0    202320   0% /run/user/0
``` 