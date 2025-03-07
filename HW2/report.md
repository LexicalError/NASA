# NASA Homework 2

B12902116 林靖昀

## 1. 那傢伙竟然敢無視窗  

1. `pacman -S ntfs-3g` to install ntfs util for creating ntfs.  
2. `mkfs.ntfs /dev/vdi2` to creat ntfs on `vdi2`.  \
3. `lsblk -f` to find the UUID of the new file system.  
3. Edit fstab and add an entry for `/dev/vdi2`.  

**Reference:**  
[https://wiki.archlinux.org/title/File_systems](https://wiki.archlinux.org/title/File_systems)  
[https://wiki.archlinux.org/title/NTFS](https://wiki.archlinux.org/title/NTFS)  

## 2. 因為要換到新的 SWAP

1. `mkswap --size 4G --file /newswap` to make a swap file.  
2. `swapon /newswap` to activate.  

**Reference:**  
[https://wiki.archlinux.org/title/Swap](https://wiki.archlinux.org/title/Swap)  

## 3. 為資料創造新的棲身之處

1. `lvresize -L 1G nasahw2-main/course` to resize lv.
2. `resize2fs /dev/nasahw2-main/course` to expand the file system.

**Reference:**  
[https://wiki.archlinux.org/title/LVM](https://wiki.archlinux.org/title/LVM)  

## 4. 我有拜託妳別把我的作業告訴其他人了吧  

1. `lvcreate -L 800M nasahw2-main -n homework` to create lv.  
2. `cryptsetup luksFormat /dev/nasahw2-main/homework --key-file /home/balu/lvm_key` to initialize LUKs with a key file.  
3. `cryptsetup open /dev/nasahw2-main/homework homework  --key-file=/home/balu/lvm_key` to open the LUKS device.  
3. `mkfs.ext4 /dev/mapper/homework` to make file system.  
4. `lsblk -f` to get UUID.  
5. Edit `/etc/crypttab` and add an entry:  
    `homework 	UUID=bf8e6be1-b71f-4587-9d96-4e1188285a3d 	/home/balu/lvm_key	luks`  
6. Edit `/etc/fstab` and add an entry:  
    `UUID=7e016873-6d79-415f-8715-b555933f21bb  /home/balu/homework ext4    defaults 0 2`  
7. `reboot` to test.  


**Reference:**  
[https://wiki.archlinux.org/title/LVM](https://wiki.archlinux.org/title/LVM)  
[https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system)
[https://wiki.archlinux.org/title/Dm-crypt/Device_encryption](https://wiki.archlinux.org/title/Dm-crypt/Device_encryption)
[https://man7.org/linux/man-pages/man5/crypttab.5.html](https://man7.org/linux/man-pages/man5/crypttab.5.html)  

## 5. 快照真的好難喔

1. `vgextend nasahw2-main /dev/vdc1` to add `/dev/vdc1` to volume group `nasahw2-main`.  
2. `lvcreate --size 1G --snapshot --name backup /dev/nasahw2-main/course` and `mount -m /dev/nasahw2-main/backup /mnt/backup` to create a snapshot lv for `course`, and mount it on `/mnt/backup`.  
    
3. `tar --zstd -cf backup.tar.zst /mnt/backup` to create tar archive.  
4. `umount /mnt/backup` and `lvremove nasahw2-main/backup` to unmount lv and remove it.  

**Reference:**  
[https://wiki.archlinux.org/title/LVM](https://wiki.archlinux.org/title/LVM)  
[https://www.cyberciti.biz/faq/how-to-tar-a-file-in-linux-using-command-line/](https://www.cyberciti.biz/faq/how-to-tar-a-file-in-linux-using-command-line/)  
[https://man7.org/linux/man-pages/man1/tar.1.html](https://man7.org/linux/man-pages/man1/tar.1.html)  

## 6. 好老舊喔  

1. `vgextend nasahw2-secondary /dev/vdd1` to add `/dev/vdd1` to `nasahw2-secondary`.  
2. `pvmove /dev/vde1` to move the data from `/dev/vde1`
3. `vgreduce nasahw2-secondary /dev/vde1` to remove `/dev/vde1` from `nasahw2-secondary`.  
4. 

**Reference:**  
[https://wiki.archlinux.org/title/LVM](https://wiki.archlinux.org/title/LVM)  

## 7. 我看還是再來合一次吧  

1. `umount /home/balu/videos` to unmount the lv on `nasahw2-secondary`.  
1. `vgchange -a n nasahw2-secondary` to deactivate vg.  
2. `vgmerge nasahw2-main nasahw2-secondary` to merge `nasahw2-secondary` into `nasahw2-main`.  
3. Modify fstab, change the line:  
    `/dev/nasahw2-secondary/videos	/home/balu/videos	ext4	defaults	0 2` to  
    `/dev/nasahw2-main/videos	/home/balu/videos	ext4	defaults	0 2`

**Reference:**  
[https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/6/html/logical_volume_manager_administration/vg_combine#VG_combine](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/6/html/logical_volume_manager_administration/vg_combine#VG_combine)  
[https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/4/html/cluster_logical_volume_manager/vg_activate#VG_activate](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/4/html/cluster_logical_volume_manager/vg_activate#VG_activate)

## 8.等一下，妳還沒回答我  

1. zfs does not support growing and shrinking while unmounted, whereas btrfs supports both while unmounted.  

**Reference:**  
[https://en.wikipedia.org/wiki/Comparison_of_file_systems#Features](https://en.wikipedia.org/wiki/Comparison_of_file_systems#Features)  

2. FUSE as the name implies, is a filesystem  implemented in userspace, with a kernel module that only acts as a bridge between the userspace code and other kernel interfaces.  
    Advantages:  
    Faster development and distribution, as it not integrated to the kernel.  
    Disadvantages:
    Less robust, for example, since the filesystem is implemented as processes, there is a chance that it is accidentally killed.  

**References:**  
[https://en.wikipedia.org/wiki/Filesystem_in_Userspace](https://en.wikipedia.org/wiki/Filesystem_in_Userspace)  
[https://www.linuxtoday.com/blog/user-space-file-systems/](https://www.linuxtoday.com/blog/user-space-file-systems/)  

3. MBR: Master Boot Record, GPT: GUID Partition Table  
    1. MBR has a maximum partition size of 2TB whereas GPT supports up to 64ZiB (depending on sector size).  
    2. MBR only supports 4 partitions whereas GPT supports at least 128 partitions.  

    **References:**  
    [https://en.wikipedia.org/wiki/Master_boot_record](https://en.wikipedia.org/wiki/Master_boot_record)  
    [https://en.wikipedia.org/wiki/GUID_Partition_Table](https://en.wikipedia.org/wiki/GUID_Partition_Table)

4. SI & IEC definition:  
    MB: $1000^2$ bytes, MiB: $1024^2$ bytes.  
    For a 4096 byte file, with `ls -l`, we see that it is `4096` bytes, but with `ls -lh`, it is 4.0K, thus the K means KiB, and `ls -lh` uses binary prefixes by default.  


    **Reference:**  
    [https://en.wikipedia.org/wiki/Megabyte](https://en.wikipedia.org/wiki/Megabyte)  

5. 
    1.  RAID 0:  
        RAID 0 does stripping, which increases read/write throughput, but it does not provide mirroring or parity, thus losing 1 drive would typically mean all data are lost.  
    2.  RAID 1:
        RAID 1 does mirroring, which decreases write throughput, but since all data are mirrored, as long as one drive is functional, no data is lost. RAID 1 does not provide parities or striping.  
    3.  RAID 5:  
        RAID 5 does striping with distributed parities, parities are distributed among the drives, such that if one drive fails, data can still be rebuild, if more than one fails, data would be lost.  

    4.  RAID 10:  
        Also known as RAID 1+0, is a RAID 0 of RAID 1s, meaning it does stripping on mirrors.  

    **Reference:**  
    [https://en.wikipedia.org/wiki/RAID](https://en.wikipedia.org/wiki/RAID)
    [https://en.wikipedia.org/wiki/Standard_RAID_levels](https://en.wikipedia.org/wiki/Standard_RAID_levels)
    [https://en.wikipedia.org/wiki/Nested_RAID_levels#RAID_10](https://en.wikipedia.org/wiki/Nested_RAID_levels#RAID_10)

