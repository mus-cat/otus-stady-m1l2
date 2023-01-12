# otus-stady-m1l2

##
Приложенные файлы относятся к процессу автоматического создания ВМ с помощью **vagrant**.
В результате их работы получается ВМ с 4 дополнительными дисками собраными в RAID 10. На этом устройстве создано 5 разделов смонтированных в папку **/raid/partX** (X = 1..5). Систему можно перезагружать.

## Перенос системы размещенной на одном диске -> RAID 1
### Замечание. D качестве ОС Используется debian 11.

- Исходное состояние блочных устройств (вывод команды `lsblk`):
```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   80G  0 disk 
├─sda1   8:1    0 15.1G  0 part /
├─sda2   8:2    0    1K  0 part 
├─sda5   8:5    0  5.4G  0 part /var
├─sda6   8:6    0  976M  0 part [SWAP]
├─sda7   8:7    0  998M  0 part /tmp
└─sda8   8:8    0 57.6G  0 part /home
sdb      8:16   0   80G  0 disk 
sr0     11:0    1 1024M  0 rom 
```
где ***sdb*** - второй диск добавленный в сиситему ипредназначенный для включения в RAID1

- Готовим диск ***sdb***, разбив его минимум на 2 раздела. Используемая схема разметки - MBR.
```
parted /dev/sdb mktable msdos
parted /dev/sdb mkpart primary 0% 1G
parted /dev/sdb mkpart primary 1G 100%
```

- На первом разделе **sdb** создаем файловую систему (далее - ФС) ext4. Так же указываем, что раздел будет загрузачным.
```
mkfs.ext4 /dev/sdb1
parted /dev/sdb set 1 boot on
```

- Создаем RAID1 с одним отсутствующим диском (опция `missing`) 
```mdadm --create /dev/md0 -l 1 -n 2 /dev/sdb2 missing```

- Переносим содержимое папки **/boot** на первый раздел **sdb** и монтируем его в **/boot**
```
mount /dev/sdb1 /mnt
cp -ra /boot /mnt
umount /mnt
mount /dev/sdb1 /boot
```

- Переносим содержмое "корня" на новыи диск. Файл архива "корня" временно положим в папку **/var** расположенную на отдельном разделе
```
mount -o remount,ro /dev/sda1
fsarchiver savefs /var/sda1 /dev/sda
fsarchiver restfs /var/sda1.fsa id=0,dest=/dev/md0
fsck -fC /dev/md0
rm /var/sda1.fsa
```
Последней командой на всякий случа проверили целостность перенесенной ФС

- Переносим папки пользователей (папку /home ) и папку **/var**
```
cp -ra /home/* /mnt/home/
cp -ra /var/* /mnt/var/
```

- Вносим изменения в файл **/etc/fstab**
```
echo -e "$(blkid | grep md0 | cut -d ' ' -f 2 | tr -d '"')\t/\text4\terrors=remount-ro\t0\t1" >> /etc/fstab
echo -e "$(blkid | grep sdb1 | cut -d ' ' -f 2 | tr -d '"')\t/boot\text4\tdefaults\t0\t2 >> /etc/fstab
```
С помощью редактора в файле **/etc/fstab** удаляем или коментируем все старые записи монтирования (ссылающиеся на **/dev/sda** или его разделы)

- Устанавливаем grub на диск /dev/sdb и создаём для него новый конфиг
```
grub-install /dev/sdb
grub-mkconfig -o /mnt/grub/grub.cfg
```

- На всякий случай сохраняем настройку MD RAID
```
mdadm --detail --scan >> /etc/mdadm/mdadm.conf
```

- Перезагружаем систему и осуществляем загрузку со второго диска (**sdb**). Должна загрузится система с корнем на RAID.

- Переразбиваем старый диск
```
sfdisk -d /dev/sdb | sfdisk /dev/sda
```

- Добавляем второй раздел диска **sda** в RAID
```
mdadm --manage --add /dev/md127 /dev/sda2
```
**/dev/md127** - надо зменить на нужное устройство.
Запускается процесс синхронизации.

- Настраиваем раздел **/dev/sda1** 
```
dd if=/dev/zero of=/dev/sda1 bs=1M
mkfs.ext4 /dev/sda1
mount /dev/sda1 /mnt
cp -ar /boot/* /mnt
grub-install /dev/sda
```
Теперь система должна нормально грузится со старого диска
В результате `lsblk` покажет такой результат
```
NAME      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
sda         8:0    0   80G  0 disk  
├─sda1      8:1    0  953M  0 part  
└─sda2      8:2    0 79.1G  0 part  
  └─md127   9:127  0   79G  0 raid1 /
sdb         8:16   0   80G  0 disk  
├─sdb1      8:17   0  953M  0 part  /boot
└─sdb2      8:18   0 79.1G  0 part  
  └─md127   9:127  0   79G  0 raid1 /
sr0        11:0    1 1024M  0 rom 
```

**P.S. Чтобы чуть-чуть сократить текст создание раздела под SWAP было исключено**




