# Agentiik on a single host

One Linux machine runs the whole installation from one file, [`compose.yaml`](compose.yaml): PostgreSQL, the NATS bus, the API, the controller, one runner, and `init`, which prepares the rest at every start. It is [Profile A](https://agentiik.github.io/docs/#profile-a-a-single-host) of the documentation, for a homelab, a small team, or reproducing an incident. Nothing is redundant, on purpose.

Every command below is run, exactly as written here, on a fresh Ubuntu machine by [the single-host workflow](../.github/workflows/single-host.yml) on every change: as in [Start](#start), [on a server](#on-a-server), and [behind Caddy](#behind-a-reverse-proxy).

## What you need

| | |
| --- | --- |
| A Linux host, x86-64 or arm64 | The runner hands the Docker daemon paths on the host to bind, which Docker Desktop's virtual machine cannot see. `agk` runs anywhere. |
| Docker Engine 28 or later, with Compose 2.24 or later | Every component is a container, and so is every step of every workflow. Compose 2.24 reads the inline `configs` and `depends_on.restart` the file uses. |
| `curl`, `openssl`, `git`, `sudo` | To download the file, make a token and commit a workflow; `sudo` only to back up and remove what the containers wrote as root. |
| Ports 8443 and 4222 open | The API serves HTTPS on 8443 and the bus listens on 4222, both on every interface: open them to the machines that reach the installation, and nothing else. Behind a proxy, its 443 takes the place of 8443, which then listens on the loopback alone. Where 4222 is taken, `AGENTIIK_BUS_PORT` in `.env` moves the bus. |
| Go 1.27, or Homebrew, where you run `agk` | To install the command line. `agk push` also needs a Docker daemon, to resolve image tags to digests. |

## Start

In a directory of its own:

<!-- ci: none -->
```sh
mkdir -p ~/agentiik && cd ~/agentiik
curl -fsSLO https://raw.githubusercontent.com/agentiik/deploy/v0.2.5/single-host/compose.yaml
echo "AGENTIIK_OPERATOR_TOKEN=$(openssl rand -hex 32)" > .env
export AGENTIIK_TOKEN="$(sed -n 's/^AGENTIIK_OPERATOR_TOKEN=//p' .env)"
docker compose up -d --wait
```

`.env` holds the operator token, the one credential of a v0.2 installation, which may do everything and which `agk` reads as `AGENTIIK_TOKEN`: `compose.yaml` refuses to start without it. Every other setting has its default in `compose.yaml`, and [`.env.example`](.env.example) lists them all. The state is kept in `data/` beside `compose.yaml`, or where `AGENTIIK_DATA` in `.env` says.

### On a server

Where `agk` or a runner on another machine reaches the installation, `AGENTIIK_HOST` is the name or the address it reaches it at, which the certificate is issued to:

<!-- ci: direct -->
```sh
mkdir -p ~/agentiik && cd ~/agentiik
curl -fsSLO https://raw.githubusercontent.com/agentiik/deploy/v0.2.5/single-host/compose.yaml
echo "AGENTIIK_OPERATOR_TOKEN=$(openssl rand -hex 32)" > .env
echo 'AGENTIIK_HOST=agentiik.example.com' >> .env
export AGENTIIK_TOKEN="$(sed -n 's/^AGENTIIK_OPERATOR_TOKEN=//p' .env)"
docker compose up -d --wait
```

### Behind a reverse proxy

Where a reverse proxy on this host terminates TLS in front of the API, `AGENTIIK_PROXY_URL` names its address. The API then serves plain HTTP on `127.0.0.1:8443` alone, for the proxy to forward to, and every address it hands out is minted on that URL. The bus is NATS rather than HTTP, so it is not proxied: it keeps its own TLS on 4222, at `AGENTIIK_HOST`. Caddy, in a container:

<!-- ci: proxy -->
```sh
mkdir -p ~/agentiik && cd ~/agentiik
curl -fsSLO https://raw.githubusercontent.com/agentiik/deploy/v0.2.5/single-host/compose.yaml
curl -fsSLO https://raw.githubusercontent.com/agentiik/deploy/v0.2.5/single-host/proxy/Caddyfile
echo "AGENTIIK_OPERATOR_TOKEN=$(openssl rand -hex 32)" > .env
echo 'AGENTIIK_HOST=agentiik.example.com' >> .env
echo 'AGENTIIK_PROXY_URL=https://agentiik.example.com' >> .env
docker run --detach --name caddy --restart unless-stopped --network host -e AGENTIIK_PROXY_URL=https://agentiik.example.com \
  -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" -v caddy-data:/data caddy:2
```

Where the proxy's certificate is from an authority the system does not trust, such as Caddy's own for an IP address or a name like `agentiik.internal`, `AGENTIIK_CA` hands it to the runner, and `trust/` keeps it for `agk` and `curl`:

<!-- ci: proxy -->
```sh
mkdir -p trust
docker exec caddy sh -c 'until [ -s /data/caddy/pki/authorities/local/root.crt ]; do sleep 1; done; cat /data/caddy/pki/authorities/local/root.crt' > trust/proxy.pem
echo "AGENTIIK_CA=\"$(cat trust/proxy.pem)\"" >> .env
export AGENTIIK_TOKEN="$(sed -n 's/^AGENTIIK_OPERATOR_TOKEN=//p' .env)"
docker compose up -d --wait
```

| Proxy | Files in [`proxy/`](proxy/) | Where they go |
| --- | --- | --- |
| Caddy | `Caddyfile` | Mounted as above, with `AGENTIIK_PROXY_URL` in Caddy's environment. Caddy obtains and renews the certificate itself. |
| nginx | `nginx.conf` | `/etc/nginx/conf.d/agentiik.conf`, with your name and certificate in place of `agentiik.example.com`. |
| Traefik | `traefik.yaml`, `traefik-agentiik.yaml` | `/etc/traefik/`, with your name and an address for Let's Encrypt in place of the examples. |

Each passes a step's log stream on as it is written, the path undecoded (an artifact's URI is one segment whose slashes are `%2F`), and bodies of any size (a runner uploads artifacts of up to 5 GiB). Open the proxy's 443 and the bus's 4222, and nothing else.

### What runs

`init` runs first at every `docker compose up`, and brings the installation in line with `.env`; the other services wait for it.

<!-- ci: check data-dir -->
<!-- ci -->
```sh
docker compose ps --all
```

```text
NAME                          IMAGE                                      COMMAND                  SERVICE            STATUS
agentiik-api-1                ghcr.io/agentiik/api:v0.2.5                "/agentiik-api serve"    api                Up (healthy)
agentiik-controller-1         ghcr.io/agentiik/controller:v0.2.5         "/agentiik-controller"   controller         Up
agentiik-init-1               ghcr.io/agentiik/api:v0.2.5                "/agentiik-api init"     init               Exited (0)
agentiik-nats-1               nats:2-alpine                              "docker-entrypoint.s…"   nats               Up (healthy)
agentiik-postgres-1           postgres:18-alpine                         "docker-entrypoint.s…"   postgres           Up (healthy)
agentiik-postgres-upgrade-1   ghcr.io/agentiik/postgres-upgrade:v0.3.0   "/usr/local/bin/post…"   postgres-upgrade   Exited (0)
agentiik-runner-1             ghcr.io/agentiik/runner:v0.2.5             "/usr/local/bin/agk-…"   runner             Up
```

Everything the installation keeps is in `data/`, one directory per service, and the one other path it uses on the host is `/var/lib/agentiik/work`, where the runner lays out each step's files for the daemon to bind.

## Point agk at it

<!-- ci -->
```sh
go install github.com/agentiik/agentiik/cmd/agk@v0.2.5
export PATH="$PATH:$(go env GOPATH)/bin"
mkdir -p trust
docker compose cp api:/agentiik/trust/agentiik.pem trust/
export SSL_CERT_DIR="$PWD/trust"
```

`brew install agentiik/tap/agk` installs the same command line. `SSL_CERT_DIR` adds the certificate `init` made to the authorities `agk` trusts on Linux; on macOS, `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain agentiik.pem`. `AGENTIIK_SERVER` is the address, and `CURL_CA_BUNDLE` what `curl` trusts there:

<!-- ci: none -->
```sh
export AGENTIIK_SERVER=https://localhost:8443
export CURL_CA_BUNDLE="$PWD/trust/agentiik.pem"
```

With `AGENTIIK_HOST` set, `https://agentiik.example.com:8443`, and behind a proxy, its URL:

<!-- ci: direct -->
```sh
export AGENTIIK_SERVER=https://agentiik.example.com:8443
export CURL_CA_BUNDLE="$PWD/trust/agentiik.pem"
```

<!-- ci: proxy -->
```sh
export AGENTIIK_SERVER=https://agentiik.example.com
export CURL_CA_BUNDLE="$PWD/trust/proxy.pem"
```

## Run a first workflow

A workflow is a git repository with an `agentiik.yaml` at its root. `agk push` registers a commit in a namespace, and `agk run --namespace` starts it there and follows it to its end.

<!-- ci -->
```sh
mkdir -p ~/first-run && cd ~/first-run && git init -q
cat > agentiik.yaml <<'EOF'
apiVersion: agentiik.dev/v1
kind: Workflow
metadata:
  name: first-run
  namespace: demo
outputs:
  greeting:
    from: { step: greet, port: out }
    retain: 7d
steps:
  greet:
    image: alpine:3.21
    script:
      - echo "greet runs on $(uname -m)" >&2
      - echo "hello from ${AGK_STEP}"
      - echo "a file from ${AGK_STEP}" > /agk/out/files/greeting.txt
    outputs: [out]
EOF
git add agentiik.yaml && git commit -qm "A first workflow"
agk push --namespace demo
agk run --namespace demo 2>&1 | tee ~/first-run.log
run=$(awk '/ started at / { print $2; exit }' ~/first-run.log)
agk status "$run"
agk logs "$run"
curl -fsSL -H "Authorization: Bearer $AGENTIIK_TOKEN" "$AGENTIIK_SERVER/api/v1/artifacts/agk%3A%2F%2Frun%2F$run%2Fgreet%2Fout%2Fgreeting.txt"
cd ~/agentiik
```

```text
user namespace remapping is off on this daemon and this runner does not require it, so the floor is lifted: ...
alpine:3.21 resolved to alpine@sha256:ce64758a109eb420d874a118f87920e625e12d3634e03b4a5573fd9f6e5d3507
demo/first-run@9d4e925 pushed to https://localhost:8443
1 step, 1 file, 0 included files, 0 manifests, 1 tag resolved to its digest
run 01M3EF42G80SR9XW17YWGEYTTT of demo/first-run@9d4e925 started at https://localhost:8443
    0.6s  greet  succeeded, out 1
first-run succeeded in 0.6s: 1 step, 1 container
greeting: 1 item
...
greet | greet runs on x86_64
greet | driver: the container exited 0: the output envelopes are published
a file from greet
```

`agk status` says how the run and each step stand, and `agk logs` prints what each step wrote on standard error; what it writes on standard output becomes its output, as [Get started](https://agentiik.github.io/docs/#get-started) shows. A file it leaves in `/agk/out/files/` becomes an artifact, kept for the seven days `retain` says, which `curl` fetches last by its URI, percent-encoded as one segment of the path.

## Change a setting

Edit `.env`, then `docker compose up -d`: Compose recreates every service whose settings changed, `init` brings the installation in line with them, and the services that read what it writes restart. A new `AGENTIIK_HOST` gets a new certificate, a new `AGENTIIK_NAMESPACE` is created beside the previous one, a new `AGENTIIK_OPERATOR_TOKEN` replaces the previous one. It is named apart from `AGENTIIK_TOKEN`, which `agk` reads, because Compose prefers a variable of the shell to the same one in `.env`: exported for `agk`, it would hide every change made in `.env`. `docker compose restart` does not read `.env` again, so it applies nothing.

A second namespace, and a new operator token, which stops the previous one working:

<!-- ci: check before-change -->
<!-- ci -->
```sh
echo 'AGENTIIK_NAMESPACE=team' >> .env
sed -i '/^AGENTIIK_OPERATOR_TOKEN=/d' .env
echo "AGENTIIK_OPERATOR_TOKEN=$(openssl rand -hex 32)" >> .env
docker compose up -d --wait
export AGENTIIK_TOKEN="$(sed -n 's/^AGENTIIK_OPERATOR_TOKEN=//p' .env)"
```
<!-- ci: check after-change -->

Another namespace is also `docker compose run --rm --no-deps api namespace create NAME`, which leaves `.env` as it is.

## Upgrade

Download the new release's `compose.yaml` in place of the old one, since a release may change the services as well as their version, and keep `.env`; remove `AGENTIIK_VERSION` from `.env` if it pins the old one. Then:

```sh
docker compose up -d --wait
```

`init` migrates the database before the API and the controller start again on the new images. `agk` is upgraded the way it was installed. Where a release moves PostgreSQL to a new major version, as v0.3.0 moves it from 17 to 18, `postgres-upgrade` upgrades `data/postgres` with `pg_upgrade` before PostgreSQL starts, and keeps the previous cluster beside it as `data/postgres-17`, the way back, for you to remove once you no longer need it. Nothing else is asked of you: [the single-host workflow](../.github/workflows/single-host.yml) upgrades the latest release, and `latest` to `dev`, this way on every change, and checks that the operator token, the runs made before and the runner still work.

An installation of v0.2.4 kept its state in Docker volumes rather than `data/`, and is not upgraded in place: remove it as its README said, then start anew.

The bus credential of the API and the controller lasts 90 days, and the API warns from 14 days before its end. `init` renews it at any `docker compose up` in that time; `docker compose up -d --force-recreate` also restarts the API and the controller on it.

## Add a runner on another machine

Any Linux machine with Docker Engine 28 can run steps for the installation, as long as it reaches `AGENTIIK_HOST` on 4222, and the API on 8443 or the proxy's 443; nothing connects to it. It joins a pool with a single-use token the operator issues, and takes the steps whose `runs_on` names its labels. On the installation's host, a pool for its label, and a join token, valid an hour:

<!-- ci: direct proxy -->
```sh
curl -fsS -H "Authorization: Bearer $AGENTIIK_TOKEN" -H 'Content-Type: application/json' \
  --data '{"pool":{"name":"lab","labels":["zone=lab"],"namespaces":[],"resource_ceilings":{}}}' "$AGENTIIK_SERVER/api/v1/runner-pools"
JOIN_TOKEN=$(curl -fsS -H "Authorization: Bearer $AGENTIIK_TOKEN" -H 'Content-Type: application/json' \
  --data '{"labels":["zone=lab"]}' "$AGENTIIK_SERVER/api/v1/runner-pools/lab/join-tokens" | sed -n 's/.*"token" *: *"\([^"]*\)".*/\1/p')
echo "$JOIN_TOKEN"
```

On the other machine, in a directory of its own, the certificates in `trust/` here (`agentiik.pem`, and `proxy.pem` behind a proxy whose authority the system does not trust), the installation's address as that machine reaches it, and the token:

```sh
AGENTIIK_SERVER=https://agentiik.example.com:8443
JOIN_TOKEN=agkjoin_...
```

Then its own Compose file, [`runner/compose.yaml`](../runner/compose.yaml), and a `.env` for it ([`runner/.env.example`](../runner/.env.example) says what each line is):

<!-- ci: other machine -->
```sh
curl -fsSLO https://raw.githubusercontent.com/agentiik/deploy/v0.2.5/runner/compose.yaml
cat > .env <<EOF
AGENTIIK_API=$AGENTIIK_SERVER
AGENTIIK_JOIN_TOKEN=$JOIN_TOKEN
AGENTIIK_LABELS=zone=lab
AGENTIIK_CA="$(cat ./*.pem)"
EOF
docker compose up -d
```

The runner joins at its first start, and restarts with the machine. `docker compose logs runner` there follows it. Back on the installation's host, a step for the lab:

<!-- ci: direct proxy -->
```sh
mkdir -p ~/on-lab && cd ~/on-lab && git init -q
cat > agentiik.yaml <<'EOF'
apiVersion: agentiik.dev/v1
kind: Workflow
metadata:
  name: on-lab
  namespace: demo
steps:
  where:
    image: alpine:3.21
    runs_on: [zone=lab]
    script:
      - echo "where runs on $(hostname)" >&2
    outputs: [out]
EOF
git add agentiik.yaml && git commit -qm "A step for the lab"
agk push --namespace demo
agk run --namespace demo
cd ~/agentiik
```

The same program runs without a container too, as a static binary under systemd: [Installing a runner](https://agentiik.github.io/docs/#installing-a-runner). To remove the machine, there:

<!-- ci: other machine -->
```sh
docker compose down
sudo rm -rf data /var/lib/agentiik/work
```

## Back up

The database and `data/`, taken together, since a run restored without its objects points at artifacts that no longer exist. The database is dumped rather than copied, since its files copied while it runs may not restore. Where `.env` sets `AGENTIIK_DATA`, that directory takes the place of `data` here and below:

<!-- ci -->
```sh
docker compose exec -T postgres pg_dump -U postgres -Fc agentiik > agentiik.dump
sudo tar -czf agentiik-data.tar.gz --exclude='data/postgres*' data
```
<!-- ci: check backup -->

The archive holds the master key, which opens every secret in the dump: keep the two apart, or encrypt them.

## Remove

Every container, image and key, and the state, which the containers wrote as root:

<!-- ci -->
```sh
docker compose down --rmi all --volumes
sudo rm -rf data /var/lib/agentiik/work
```
<!-- ci: check removed -->

Behind Caddy, `docker rm --force caddy && docker volume rm caddy-data` too.

## What v0.2 does not do yet

| What | Today | When |
| --- | --- | --- |
| Users, groups, sign-in | One operator token may do everything. | v0.3.0 brings principals and a bootstrap token. |
| Creating a namespace through the API | `AGENTIIK_NAMESPACE`, or `docker compose run --rm --no-deps api namespace create NAME`, on the installation's host. | v0.3.0, with the access model. |
| The console | Not part of this stack. | Its own releases. |
| Object store | On disk in `data/objects`, not MinIO. | v0.9.0 |
| `network: egress` | Refused rather than opened. | v0.9.0 |
| A certificate from a public authority | `init` signs its own, unless [a reverse proxy](#behind-a-reverse-proxy) in front serves the API with its own; the bus keeps `init`'s. Yours goes in with `docker compose cp` to `init:/init/api/tls/server.pem` and `server.key`, then `docker compose up -d --force-recreate`: `init` never replaces a certificate it did not issue. | |
