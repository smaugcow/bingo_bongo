# bingo_bongo

С утра будет красиво)

Зависимости:
git-lfs
Docker
yc
terraform





деплоить деплоить деплоить:

обязательно нужно установить git-lfs!!!
sudo apt install git-lfs
git clone https://github.com/smaugcow/bingo_bongo.git


sudo apt-get install docker docker-compose
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
wget https://releases.hashicorp.com/terraform/1.6.4/terraform_1.6.4_linux_amd64.zip && sudo unzip ~/Downloads/terraform_1.6.4_linux_amd64.zip -d /usr/local/bin/

yc init
yc iam create-token
ssh-keygen -t ed25519

nano ~/.terraformrc
-----------> 
provider_installation {
  	network_mirror {
    	url = "https://terraform-mirror.yandexcloud.net/"
    	include = ["registry.terraform.io/*/*"]
  	}
  	direct {
    	exclude = ["registry.terraform.io/*/*"]
  	}
}
----------->

docker login --username oauth --password y0_AgAAAAAYDjrOAATuwQAAAADyZGblMZr7XRU1SQeFISr8S82BZb-GvVE cr.yandex

terraform init
terraform plan
terraform apply





в чем же бинго???:

Попробуем запустить бинарь, Hello, World. Что-то в этом есть.
Запустим help, ага, уже что-то интересное.
Попробуем все и поймем, что нам не хватает конфига.
На print_current_config ошибка. Можно немного еще поиграться туда-сюда, но это же ctf, значить gdb.
Запускаем, усканавливаем args, и run. Видим что ошибка в /build/internal/config/soft.go:21. Значит нам туда. 
Сделаем break на 21 строке. Посмотрим на info func. Очень много кода. Там и наш разраб спрятался.
Нас интересует что-то связанное с config.
Найдем вот такие:
/build/internal/config/config.go
/build/internal/config/hard.go
/build/internal/config/soft.go
Значит есть что-то, что мы изменить не сможем, а что-то сможем.
Сделаем break /build/internal/config/config.go:10. run.
info locals.
Уууу, а тут сколько всего.
ConfigPath, MainLogPath, StartupRequestUrl...
Еще немного покрутив это место, можно сделать вывод:
ListIpString = 21999
ConfigPath = "/opt/bingo/config.yaml"
MainLogPath = "/opt/bongo/logs/{хеш от почты, вроде fnv и sha1}/main.log"
StartupRequestUrl = "http://8.8.8.8/"
RPSLimit = 100
...    c08832d0e4
Создадим конфиг в нужном месте и файл для логгов.
Не забываем что бинарь запускать от рута нельзя и нужно дать права на запись в файл main.log.



Используемый софт:
gdb
tmpdump
bash
python
docker
docker compose
terraform
postgresql
