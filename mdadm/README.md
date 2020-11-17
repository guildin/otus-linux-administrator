# HW2 Работа с mdadm
  * добавить в Vagrantfile еще дисков
  * сломать/починить raid
  * собрать R0/R5/R10 на выбор
  * прописать собранный рейд в конф, чтобы рейд собирался при загрузке
  * создать GPT раздел и 5 партиций

## Добавление дсиков в Vagrantfile
Модифицируем Vagrantfile следующим образом:

```
        v.customize ['storagectl', :id, '--name', 'SATA Controller', '--add', 'sata', '--portcount', 8]
        # Добавили сата контроллер (иде контроллер не даст добавить больше 4х дисков, неспортивно)
        (0..3).each do |i|
        # 4 раза:
          if not File.exists?("./additionalDisk#{i}.vdi")
          # Если нет файла диска additionalDisk(0.1.2.3).vdi
            v.customize ['createhd', '--filename', "./additionalDisk#{i}.vdi", '--variant', 'Fixed', '--size', 10 * 1024]
            # создать диск в 10ГБ
          end
          v.customize ['storageattach', :id,  '--storagectl', 'SATA Controller', '--port', "#{i}", '--device', 0, '--type', 'hdd', '--medium', "./additionalDisk#{i}.vdi"]
          # приаттачить диск на сата контроллер, за портом (0,1,2,3) из файла ./additionalDisk(0,1,2,3).vdi  
        end
```
Создадим машину и убедимся что диски создались:
```
$ lsblk
NAME            MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sdd               8:48   0  10G  0 disk 
sdb               8:16   0  10G  0 disk 
sde               8:64   0  10G  0 disk 
sdc               8:32   0  10G  0 disk 
...
```

На самом деле нам не нужно 4 диска по 10 GB, если мы собрались ломать и чинить рейд. Возьмем 5 дисков по 1 GB, (один как бы запасной).

## Сборка массива
Создадим массив ручками.
```
$ sudo yum install -y mdadm
$ sudo mdadm --create --verbose /dev/md0 --level=10  --raid-devices=4 /dev/sda /dev/sdc /dev/sdd /dev/sde
mdadm: layout defaults to n2
mdadm: layout defaults to n2
mdadm: chunk size defaults to 512K
mdadm: size set to 1046528K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
```

Создадим фс и прикрутим массив:
```
sudo mkfs.ext4 /dev/md0
...
$ sudo mkdir /mnt/storage
$ sudo mount -t ext4 /dev/md0 /mnt/storage
$ df -h
Файловая система        Размер Использовано  Дост Использовано% Cмонтировано в
...
/dev/md0                  2,0G         6,0M  1,9G            1% /mnt/storage
```

Проверим массив:
```sudo mdadm --detail /dev/md0```

## Деградация массива (и наоборот)
Сломаем массив:
```sudo mdadm /dev/md0 --fail /dev/sdd```
...и посмотрим, что с ним с помощью --detail :
```
    Number   Major   Minor   RaidDevice State
       0       8        0        0      active sync set-A   /dev/sda
       1       8       32        1      active sync set-B   /dev/sdc
       -       0        0        2      removed
       3       8       64        3      active sync set-B   /dev/sde

       2       8       48        -      faulty   /dev/sdd
```
Какая красота, когда это ничем не грозит )

Удалим "сбойный" диск и добавим новый:
```
$ sudo mdadm /dev/md0 --remove /dev/sdd
$ sudo mdadm /dev/md0 --add /dev/sdf
$ sudo mdadm --detail /dev/md0
/dev/md0:
...
    Rebuild Status : 81% complete
...
    Number   Major   Minor   RaidDevice State
       0       8        0        0      active sync set-A   /dev/sda
       1       8       32        1      active sync set-B   /dev/sdc
       4       8       80        2      spare rebuilding   /dev/sdf
       3       8       64        3      active sync set-B   /dev/sde
```
Диски мелкие и не пройдет много времени, как массив снова будет в состоянии стояния ) 

## Автосборка массива

После уже проделанной работы остается только внести соответствующие инструкции в Vagrantfile
```
$provision_script = <<-SCRIPT
yum install -y mdadm
mdadm --create --verbose /dev/md0 --level=10 --raid-devices=4 /dev/sdb /dev/sdc /dev/sdd /dev/sde
mkfs.ext4 /dev/md0
mkdir /mnt/storage
mount -t ext4 /dev/md0 /mnt/storage
SCRIPT
box.vm.provision "shell", inline: $provision_script
```

## GPT раздел и партиции
```
sudo parted -s /dev/md0 mktable gpt
sudo parted /dev/md0 mkpart primary ext4 0% 20%
sudo parted /dev/md0 mkpart primary ext4 20% 40%
sudo parted /dev/md0 mkpart primary ext4 40% 50%
sudo parted /dev/md0 mkpart primary ext4 50% 70%
sudo parted /dev/md0 mkpart primary ext4 70% 100%

for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i && sudo mkdir -p /mnt/vol$i && sudo mount -t ext4 /dev/md0p$i /mnt/vol$i; done
df -h
...
/dev/md0p1                388M         2,3M  361M            1% /mnt/vol1
/dev/md0p2                389M         2,3M  362M            1% /mnt/vol2
/dev/md0p3                194M         1,8M  178M            1% /mnt/vol3
/dev/md0p4                389M         2,3M  362M            1% /mnt/vol4
/dev/md0p5                587M         936K  543M            1% /mnt/vol5
```
