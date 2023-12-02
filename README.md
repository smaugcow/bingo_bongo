## Деплоить, деплоить, деплоить:

### Шаги установки:

Обязательно установите `git-lfs`:
```bash
sudo apt install git-lfs
git clone https://github.com/smaugcow/bingo_bongo.git
```

Установите Docker и Docker Compose:
```bash
sudo apt-get install docker docker-compose
```

Установите Terraform:
```bash
wget https://releases.hashicorp.com/terraform/1.6.4/terraform_1.6.4_linux_amd64.zip && sudo unzip ~/Downloads/terraform_1.6.4_linux_amd64.zip -d /usr/local/bin/
```

Инициализируйте Yandex.Cloud и создайте токен IAM для использования в `main.tf`:
```bash
yc init
yc iam create-token
```
(его нужно поместить в main.tf на место YOUR_IAM_TOKEN)

Сгенерируйте SSH-ключ:
```bash
ssh-keygen -t ed25519
```

#### Настройка Terraform:

Отредактируйте `~/.terraformrc` для использования Terraform с mirror:
```bash
nano ~/.terraformrc
```
```plaintext
provider_installation {
  	network_mirror {
    	url = "https://terraform-mirror.yandexcloud.net/"
    	include = ["registry.terraform.io/*/*"]
  	}
  	direct {
    	exclude = ["registry.terraform.io/*/*"]
  	}
}
```

Авторизуйтесь в Yandex Container Registry:
```bash
docker login --username oauth --password YOUR_OAUTH_YENDEX_TOKEN cr.yandex
```

#### Конфигурация и запуск:

Укажите токен и folder_id в `main.tf`:
```plaintext
YOUR_IAM_TOKEN
YOUR_FOLDER_ID
```

Настройте конфигурацию для `bingo` с указанием `student_email`.

Инициализируйте Terraform, выполните планирование и примените изменения:
```bash
terraform init
terraform plan
terraform apply
```

### Bingo bingo bingo:

Попробуем запустить бинарь, `Hello, World`. Что-то в этом есть.
Запустим `help``, ага, уже что-то интересное.
Попробуем все и поймем, что нам не хватает конфига.
На `print_current_config`` ошибка. Можно немного еще поиграться туда-сюда, но это же ctf, значить gdb.
Запускаем, усканавливаем `args`, и `run`. Видим что ошибка в `/build/internal/config/soft.go:21`. Значит нам туда. 
Сделаем break на 21 строке. Посмотрим на `info func`. Очень много кода. Там и наш разраб спрятался.
Нас интересует что-то связанное с config.
Найдем вот такие:
`/build/internal/config/config.go`
`/build/internal/config/hard.go`
`/build/internal/config/soft.go`
Значит есть что-то, что мы изменить не сможем, а что-то сможем.
Сделаем break `/build/internal/config/config.go:10`. `run`.
`info locals`.
Уууу, а тут сколько всего.
ConfigPath, MainLogPath, StartupRequestUrl...
Еще немного покрутив это место, можно сделать вывод:
`ListIpString = 21999`
`ConfigPath = "/opt/bingo/config.yaml"`
`MainLogPath = "/opt/bongo/logs/{хеш от почты, вроде fnv и sha1}/main.log"`
`StartupRequestUrl = "http://8.8.8.8/"`
`RPSLimit = 100`
`...`
Создадим конфиг в нужном месте и файл для логгов.
Не забываем что бинарь запускать от рута нельзя и нужно дать права на запись в файл main.log.

Поднимаем postgres.
```bash
sudo apt install postgresql postgresql-contrib
```
создадим пользователя и базу, что указали в конфиге
попробуем дернуть бинарь с командой `prepare_db`
Вот они, наши пользователи.
Запустим бинарь. Он довольно долго запускается.
netstat проверим, на каком порту работает наш сервер. Или посмотрим на `hardConfig` из gdb. Поймем что это 21999.
Запустим пару раз сервер. Он долго запускается
Посмотрим логи. Почитаем логи.
Страшно: 
```bash
cat main.log | awk -F '[:,]' '!/Notified all waiters\.|Quota updated\.|I am alive\.|Started updating nodes\.|Node is alive\./ {print $4,$5,$6, $11}'\n
```
Поймем что между "Run initialization request." и "Failed initialization request." проходит почти 30 секунд. Можно додумать что дело с DNS. Либо вспомнить StartupRequestUrl. Либо сделать грязь и 
```bash
strings ./bingo | grep "code:"
```
Вот наши код: "google_dns_is_not_http". И все остальные тоже.
Значит гугль DNS не http. Изменим это с помощью `iptables`: 
```bash
sudo iptables -t nat -A OUTPUT -d 8.8.8.8 -p tcp --dport 80 -j DNAT --to-destination 77.88.8.8
```
В дальнейшем, чтобы не делать так каждый раз на виртуалке, можно исполльзовать user-data в terraform, чтобы выполнить это правило при старке виртуалки.

Теперь бинарь шустро запускается. Успех.
Сходим на `localhost:21999`
Еще один код. Хотя бы из все вынули с помощью `strings`.
Уже можно и тесты програть. Но нет.
Посмотрим на ТЗ.
Сделано так, дампнута базу и помещена в отдельный контейнер. Так же контейнер для nginx и для самого бина.

Если покрутить тесты с operation, то можно понять что сервер падает из-за каких-то значений. Падает через panic, через 500 на все запросы и крашится из-за съеденной полностью RAM.
Надо это учесть при запуске.
Будем проверять память и что отвечает на /ping.

Можно сделать еще хитрее и даже по правилам задания. Создать middleware, допустим на python, который был проверял только operation, остальные запросы просто пробрасывал дальше. Он должен смотреть что за число пришло в operation. Если "хорошее", то пропускаем, если нет, то можно 404, либо редактировать запрос на operation: 0.
Правила можно изнать просто перебирая числа в operation. Только не брутом, бинарным поиском и начинать с изменения сташих цифр.
Правила operation:<br>
25769803776 <= 200 <= ...<br>
21474836481 <= 500 <= 25769803775<br>
17179869184 <= panic <= 21474836480<br>
12884901888 <= mem leak <= 17179869183<br>
1 < 200 <= 12884901887<br>
Но, есть прикол, перед тем как число пришло, а оно может придти от 0 до int_max_go: 9223372036854775807, оно подвергается операции побитового `&` F00000000. И только после этого оно проходит проверку выше. Это число можно найти в gdb, если крутить его на запросы, когда, допустим operation=17179869184.

Так же для производительности следует сделать индексацию в базе для запросов, которые довольно оъемные. Файл `commands.sql`.
```bash
openssl genpkey -algorithm RSA -out example.key -aes256
openssl req -new -key example.key -out example.csr
openssl x509 -req -days 365 -in example.csr -signkey example.key -out example.crt
openssl rsa -in example.key -out example.key
```

Для nginx напишем конфиг. Сделает https с помощью `openssl`. Так же сделаем кэш для `/long_dummy`.

### Используемые инструменты:

- `gdb`
- `netstat`
- `tmpdump`
- `iptables`
- `bash`
- `python`
- `docker` & `docker compose`
- `Terraform`
- `PostgreSQL`
- `OpenSSL`
