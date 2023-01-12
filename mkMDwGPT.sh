#!/bin/bash 
apt install mdadm parted -y
modprobe md_mod

dList=''
for disk in $(lsblk | grep disk | awk -e '{print $1}'); 
do
 res=$(mount| grep -o "/dev/$disk");
 if [ "x$res" = "x" ];
 then
  mdadm --zero-superblock --force "/dev/$disk"
  dList="$dList /dev/$disk"
 fi;
done

mdadm --create /dev/md0 -l 10 -n 4 $dList
mdadm --detail --scan >> /etc/mdadm/mdadm.conf

parted -s /dev/md0  mktable gpt
for start in $(seq 0 4);
do
 parted -s /dev/md0 mkpart "part$(($start+1))" "$((20*$start))%" "$((20*$start+20))%";
done

for part in $(ls -1 /dev/md0p*);
do
# pNum=$(echo $part | cut -d 'p' -f 2);
 pNum=${part: -1};
 echo $pNum;
 mkfs.ext4 -F $part;
 mkdir -p /raid/part"$pNum";
 mount $part /raid/part"$pNum";
 puuid=$(blkid $part | cut -d ' ' -f 2| tr -d '"');
 echo -e "$puuid\t/raid/part$pNum\text4\tdefaults,nofail\t0\t0" >> /etc/fstab
done
