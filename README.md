## Deploy, deploy, deploy:

### Installation steps:

Make sure to install `git-lfs`:
```bash
sudo apt install git-lfs
git clone https://github.com/smaugcow/bingo_bongo.git
```

Install `Docker` and `Docker Compose`:
```bash
sudo apt-get install docker docker-compose
```

Install `YC`:
```bash
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
```

Install `Terraform`:
```bash
wget https://releases.hashicorp.com/terraform/1.6.4/terraform_1.6.4_linux_amd64.zip && sudo unzip ~/Downloads/terraform_1.6.4_linux_amd64.zip -d /usr/local/bin/
```

Initialize Yandex.Cloud and create an IAM token to use in `main.tf`:
```bash
yc init
yc iam create-token
```
(it needs to be placed into `main.tf` instead of `YOUR_IAM_TOKEN`)

Generate an `SSH-key`:
```bash
ssh-keygen -t ed25519
```

`Terraform` setup:

Edit `~/.terraformrc` to use `Terraform` with a mirror:
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

Log in to `Yandex Container Registry`:
```bash
docker login --username oauth --password YOUR_OAUTH_YENDEX_TOKEN cr.yandex
```

#### Configuration and launch:

Set the token and `folder_id` in `main.tf`:
```plaintext
YOUR_IAM_TOKEN
YOUR_FOLDER_ID
```

Set up the config for `bingo`, including `student_email`.

Initialize `Terraform`, run the plan, and apply the changes:
```bash
terraform init
terraform plan
terraform apply
```

### Bingo bingo bingo:

Let’s try running the binary. `Hello, World`. There’s something about that.
Let’s run `help` — okay, now that’s already a bit more interesting.
Let’s try everything and figure out that we’re missing a config.
`print_current_config` throws an error. We can poke around a bit more here and there, but this is a `ctf`, so `gdb`.
We launch it, set `args`, and `run`. We see the error is in `/build/internal/config/soft.go:21`. So that’s where we go.
Let’s set a `break` on line 21. Check `info func`. That’s a lot of code. Our dev is hiding in there too.
We care about anything related to config.
We find these:
`/build/internal/config/config.go`
`/build/internal/config/hard.go`
`/build/internal/config/soft.go`

So that means there’s something we won’t be able to change, and something we will.
Let’s put a break on `/build/internal/config/config.go:10`. `run` → `info locals`
Ooooh, there’s a lot in here.
`ConfigPath`, `MainLogPath`, `StartupRequestUrl` ...
After poking around this place a bit more, we can conclude:

`ListIpString = 21999`<br>
`ConfigPath = "/opt/bingo/config.yaml"`<br>
`MainLogPath = "/opt/bongo/logs/{hash of the email, looks like fnv and sha1}/main.log"`<br>
`StartupRequestUrl = "http://8.8.8.8/"`<br>
`RPSLimit = 100`<br>
`...`<br>

Let’s create the config in the required location and also create the log file.
Don’t forget that the binary cannot be run as root, and you need to give write permissions to the `main.log` file.

Let’s bring up `postgres`.
```bash
sudo apt install postgresql postgresql-contrib
```

Let’s create the user and the database we specified in the config.
Let’s try hitting the binary with the `prepare_db` command.
There they are — our users.
Now let’s run the binary. It takes quite a while to start.
Let’s use `netstat` to check which port the server is running on. Or we can look at `hardConfig` in `gdb`.
We figure out it’s `21999`.
Let’s start the server a couple of times. It starts slowly.
Let’s check the logs. Let’s read the logs.
Scary:
```bash
cat main.log | awk -F '[:,]' '!/Notified all waiters\.|Quota updated\.|I am alive\.|Started updating nodes\.|Node is alive\./ {print $4,$5,$6, $11}'\n
```

We realize that between `"Run initialization request."` and `"Failed initialization request."`, almost 30 seconds pass. You can reason out that this is probably DNS-related. Or remember `StartupRequestUrl`. Or do something dirty and:
```bash
strings ./bingo | grep "code:"
```

And there are our codes: `google_dns_is_not_http`. And all the others too.
So Google DNS is not HTTP. Let’s fix that with `iptables`:
```bash
sudo iptables -t nat -A OUTPUT -d 8.8.8.8 -p tcp --dport 80 -j DNAT --to-destination 77.88.8.8
```

Later, so you don’t have to do this every single time on the VM, you can use `user-data` in `terraform` to apply this rule at VM startup.

Now the binary starts up quickly. Success.
Let’s go to `localhost:21999`.
One more code. At least we pulled all of them out with `strings`.
Now we can finally run the tests. But no.
Let’s look at the spec.
It’s done in such a way that the database is dumped and placed into a separate container. There’s also a container for nginx and one for the binary itself.

If you mess around with the operation tests, you can figure out that the server crashes because of certain values. It crashes via panic, returns 500 on all requests, and crashes because RAM gets completely eaten.
That needs to be taken into account when launching.
We’ll monitor memory and check what responds on `/ping`.

You can get even trickier, and even stay within the assignment rules. Create a middleware, say in Python, that only checks `operation`, and just forwards all other requests as-is. It should inspect what number came in `operation`. If it’s “good”, let it through. If not, either return 404, or rewrite the request with `operation: 0`.
You can figure out the `operation` rules just by trying different numbers. Just not by brute force — use binary search, and start by changing the higher digits.
The `operation` rules:

`25769803776 <= 200 <= ...`<br>
`21474836481 <= 500 <= 25769803775`<br>
`17179869184 <= panic <= 21474836480`<br>
`12884901888 <= mem leak <= 17179869183`<br>
`1 < 200 <= 12884901887`<br>

But there’s a catch: before the number arrives — and it can arrive as anything from `0` to `int_max_go: 9223372036854775807` — it goes through a bitwise `&` with `F00000000`. And only after that does it go through the checks above. You can find that number in `gdb` if you play with requests when, for example, `operation=17179869184`.

Also, for performance, you should add indexing in the database for the queries that are fairly heavy. File: `commands.sql`.
```bash
openssl genpkey -algorithm RSA -out example.key -aes256
openssl req -new -key example.key -out example.csr
openssl x509 -req -days 365 -in example.csr -signkey example.key -out example.crt
openssl rsa -in example.key -out example.key
```

Let’s write an nginx config. It will do HTTPS via `openssl`. We’ll also add caching for `/long_dummy`.

### Tools used:

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
