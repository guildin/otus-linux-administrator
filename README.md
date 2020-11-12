# Contents

  * HW1 (Manual kernel update)

# HW1

## Установка (или обновление) Vagrant:
C https://www.vagrantup.com/downloads.html берем ссылку на последнюю версию, устанавливаем:

```
wget https://releases.hashicorp.com/vagrant/2.2.13/vagrant_2.2.13_linux_amd64.zip -O /tmp/vagrant.zip && \
unzip /tmp/vagrant.zip -d /tmp && sudo mv -f /tmp/vagrant /usr/local/bin
```

## Установка (или обновление) packer:

C https://www.packer.io/downloads.html берем ссылку на последнюю версию, устанавливаем:

```
wget https://releases.hashicorp.com/packer/1.6.5/packer_1.6.5_linux_amd64.zip -O /tmp/packer.zip && \
unzip /tmp/packer.zip -d /tmp && sudo mv -f /tmp/packer /usr/local/bin
```

## Установка VirtualBox (Ubuntu-based):

Подробности: https://www.virtualbox.org/wiki/Linux_Downloads
```
[ `which gpg` ] || sudo apt install -y gpg # ^_^

wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
echo "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib" | sudo tee /etc/apt/sources.list.d/vbox.list
sudo apt update 
sudo apt install virtualbox
```

Создание ключевой пары для машин vagrant (почему бы и нет)
```
ssh-keygen -t ed25519 -C "vagrant EC key" -N "" -f ~/.ssh/vagrant.ec.privateKey
cat ~/.ssh/vagrant.ec.privateKey.pub
```

Содержимое публичного ключа вставим в файл scripts/stage-2-clean.sh (вместо этой вашей копипасты!)

Правда, нужно будет заставить вагрант использовать правильный ключ. Например, так:
```config.ssh.private_key_path = ['~/.ssh/vagrant.ec.privateKey', '~/.vagrant.d/insecure_private_key']```


## Запуск vagrant
Собственно: 
```vagrant up```

## Ubuntu focal и пятиминтка граблей
```
The executable 'bsdtar' Vagrant is trying to run was not
found in the PATH variable. This is an error. Please verify
this software is installed and on the path.
```
OK:
```
sudo apt install apt-file
sudo apt-file update
apt-file search bsdtar

 ... # тут мы узнаем в каком пакете бинарь - libarchive-tools: /usr/bin/bsdtar

sudo apt install -y libarchive-tools 

...

vagrant up
```

Зайдем в ВМ:
```vagrant ssh```

проверим версию ядра:
```
uname -r
3.10.0-1127.el7.x86_64
```

##  Kernel update
Следим за руками:
```
sudo yum install -y https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
sudo yum install -y --enablerepo=elrepo-kernel kernel-ml
... # Есть ядро, в загрузчик его:
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
... # Ок, теперь установим порядок загрузки, чтобы ОС загружалась с новым ядром автоматически
sudo grub2-set-default 0
```
Перезагружаемся и машем.

## Packer 


Займемся вивисекцией packer/config.json
```
cat /etc/centos-release # Посмотрели версию 

  "variables": {
    "artifact_description": "CentOS 7.8.2003 with kernel 5.x",
    "artifact_version": "7.8.2003",
    "image_name": "centos-7.8"
  },
```

Далее в config.json:
Лезем на mirror.yandex.ru, а там уже новая версия. В секции builders указываем ее, а еще качаем и дергаем сумму (весной уже были грабли, хватит):
```

wget https://mirror.yandex.ru/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-Minimal-2009.iso
sha256sum CentOS-7-x86_64-Minimal-2009.iso
```
В итоге имеем:
```
  builders [

...

      "iso_url": "CentOS-7-x86_64-Minimal-2009.iso", # можно и не урл, каждый раз качать что ли?
      "iso_checksum": "07b94e6b1a0b0260b94c83d6bb76b26bf7a310dc78d7a9c7432809fb9bc6194a",
      "iso_checksum_type": "sha256", # а вот это пришлось выкинуть. Ибо устарело.
```

А теперь поднимаемся выше и правим variables

Но хватит правок, давайте собирать.
```
cd packer
packer build centos.json
```

## Первый блин комом или привет от второй стадии
Забегая вперед, собранный образ радостно загрузился с ядром 3.10, после чего еще раз глянул на содержимое stage-2-clean.sh и поправил команду: ```grub2-set-default 0```. 


Долго ли, коротко ли, что-то собралось. Добавим это что-то куда-то (ну, наверное, в локальное хранилище вагранта):
```vagrant box add --name centos-7-9 centos-7.9.2009-kernel-5-x86_64-Minimal.box```

Поменяем в вагрантфайле box_name на соответствующий: ```:box_name => "centos-7-9",``` 

(не забудем удалить старую машину с помощью ```vagrant destroy```)

Запустимся и проверим ядро: ```5.9.8-1.el7.elrepo.x86_64```


## Vagrant cloud

Вкратце:
```
vagrant cloud auth login
...
vagrant cloud publish --release atikhonov/centos-7-9 1.0 virtualbox centos-7.9.2009-kernel-5-x86_64-Minimal.box
```
