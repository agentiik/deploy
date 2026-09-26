# Agentiik on a single host

One Linux machine runs the whole installation with Docker Compose: PostgreSQL, the NATS bus, the API, the controller and one runner. It is [Profile A](https://agentiik.github.io/docs/#profile-a-a-single-host) of the documentation, for a homelab, a small team, or reproducing an incident. Nothing is redundant, on purpose.

Every command below is run, exactly as written here, on a fresh Ubuntu machine by [the single-host workflow](../.github/workflows/single-host.yml) on every change.

## What you need

| | |
| --- | --- |
| A Linux host, x86-64 or arm64 | macOS and Windows are not runner hosts: the runner hands the Docker daemon paths on the host to bind, which Docker Desktop's virtual machine cannot see. `agk` runs anywhere. |
| Docker Engine 28 or later, with the Compose plugin | Every component is a container, and so is every step of every workflow. |
| `sudo`, `openssl`, `curl`, `git` | `setup` writes under `/etc`, `/var/lib`, `/run` and `/srv`, and makes the certificate and the keys. |
| Port 8443 free, and 4222 and 8222 on the loopback | The API serves HTTPS on 8443 on every interface; the bus and its health check listen on `127.0.0.1` alone. |
| Go 1.27, or Homebrew, where you run `agk` | To install the command line. `agk push` also needs a Docker daemon, to resolve image tags to digests. |

## Install

```sh
git clone https://github.com/agentiik/deploy.git
cd deploy/single-host
```

<!-- ci -->
```sh
cp .env.example .env
```

`.env` holds the choices this host makes. The one to change first is `AGENTIIK_HOST`, the name clients reach the API at, which the certificate is issued to; `localhost` works for trying it on one machine. `AGENTIIK_VERSION` is the one variable that picks what runs, and every other file follows it.

<!-- ci -->
```sh
AGENTIIK_TOKEN="$(sudo ./setup)"
export AGENTIIK_TOKEN
```

`setup` prepares everything the host needs once, then starts the installation. It says what it does on standard error, and prints the operator token on standard output, which the line above keeps in your shell and nowhere else:

```text
setup: installing Agentiik v0.2.1 at https://localhost:8443, keeping its state in /srv/agentiik
setup: the secrets tmpfs is mounted at /run/agentiik/secrets, and /etc/fstab mounts it at boot
setup: made a certificate for DNS:localhost,IP:127.0.0.1, valid 825 days
setup: wrote the master key, the presign key, the database passwords and a new operator token's hash
setup: pulling the images
The installation's bus identity is in /agentiik/bus.
...
applied 0001_state.sql
...
agentiik is the role the API and the controller connect as, NOSUPERUSER NOBYPASSRLS
setup: the namespace demo exists, and the default pool carries zone=local
setup: the API answers at https://localhost:8443
This host joined pool default as runner 01K....
...
setup: the runner is ready
setup: Agentiik v0.2.1 is running at https://localhost:8443. Clients trust /srv/agentiik/trust/agentiik.pem.
```

The operator token is the one credential of a v0.2 installation: it may do everything, and only its SHA-256 is written down. Save it in a password manager now, `echo "$AGENTIIK_TOKEN"`. Lost, it is replaced by running `sudo ./setup` again, which keeps everything else and mints a new one.

<!-- ci -->
```sh
docker compose ps
```

```text
NAME                    IMAGE                                COMMAND                  SERVICE      STATUS
agentiik-api-1          ghcr.io/agentiik/api:v0.2.1          "/agentiik-api serve"    api          Up
agentiik-controller-1   ghcr.io/agentiik/controller:v0.2.1   "/agentiik-controller"   controller   Up
agentiik-nats-1         nats:2-alpine                        "docker-entrypoint.s…"   nats         Up (healthy)
agentiik-postgres-1     postgres:17-alpine                   "docker-entrypoint.s…"   postgres     Up (healthy)
agentiik-runner-1       ghcr.io/agentiik/runner:v0.2.1       "/usr/local/bin/agk-…"   runner       Up
```

## Point agk at it

<!-- ci -->
```sh
go install github.com/agentiik/agentiik/cmd/agk@v0.2.1
export PATH="$PATH:$(go env GOPATH)/bin"
export AGENTIIK_SERVER=https://localhost:8443
export SSL_CERT_DIR=/srv/agentiik/trust
```

`brew install agentiik/tap/agk` installs the same command line. `AGENTIIK_SERVER` is the address, `AGENTIIK_TOKEN` the credential, and `SSL_CERT_DIR` adds the certificate `setup` made to the authorities `agk` trusts on Linux. From another machine, copy `/srv/agentiik/trust/agentiik.pem` there and trust it: `SSL_CERT_DIR` on Linux, and on macOS `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain agentiik.pem`.

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
steps:
  greet:
    image: alpine:3.21
    script:
      - echo "greet runs on $(uname -m)" >&2
      - echo "hello from ${AGK_STEP}"
    outputs: [out]
EOF
git add agentiik.yaml && git commit -qm "A first workflow"
agk push --namespace demo
agk run --namespace demo 2>&1 | tee run.log
run=$(awk '/ started at / { print $2; exit }' run.log)
agk status "$run"
agk logs "$run"
cd -
```

```text
alpine:3.21 resolved to alpine@sha256:...
demo/first-run@1a2b3c4 pushed to https://localhost:8443
1 step, 1 file, 0 included files, 0 manifests, 1 tag resolved to its digest
run 01K... of demo/first-run@1a2b3c4 started at https://localhost:8443
    0.0s  greet  running
    2.1s  greet  succeeded, out 1
first-run succeeded in 2.1s: 1 step, 1 container
greeting: 1 item
run 01K...: https://localhost:8443/api/v1/demo/runs/01K...
```

`agk status` says how the run and each step stand, and `agk logs` prints what each step wrote on standard error; what it writes on standard output becomes its output, as the [Get started](https://agentiik.github.io/docs/#get-started) chapter shows.

## Operate it

The installation starts again with the host: every container restarts unless it was stopped, and `/etc/fstab` mounts the secrets tmpfs.

<!-- ci -->
```sh
docker compose stop
docker compose up --detach --wait
```

A backup is the database and the files under `/srv/agentiik`, taken together, since a run restored without its objects points at artifacts that no longer exist:

<!-- ci -->
```sh
docker compose exec -T postgres pg_dump -U postgres -Fc agentiik > agentiik.dump
sudo tar -C /srv/agentiik -czf agentiik-files.tar.gz api bus objects tls trust database-password postgres-password
```

The archive holds the master key, which opens every secret in the dump: keep the two apart, or encrypt them.

To upgrade, set `AGENTIIK_VERSION` in `.env` to the new version and run `sudo ./setup` again: it pulls, migrates, restarts, and prints a new operator token.

The bus credential of the API and the controller expires after 90 days, and the API warns from 14 days before. To renew it:

```sh
docker compose run --rm --no-deps api bus-credential /agentiik/bus
docker compose restart api controller
```

To uninstall, removing every container, image, key and piece of data:

<!-- ci -->
```sh
docker compose down --rmi all --volumes
sudo umount /run/agentiik/secrets
sudo sed -i '\| /run/agentiik/secrets |d' /etc/fstab
sudo rm -rf /srv/agentiik /var/lib/agentiik /etc/agentiik /run/agentiik
```

## What v0.2 does not do yet

| What | Today | When |
| --- | --- | --- |
| Users, groups, sign-in | One operator token may do everything. | v0.3.0 brings principals and a bootstrap token. |
| Creating a namespace | No route yet: `setup` creates `AGENTIIK_NAMESPACE`, and another is one line, `docker compose exec -T postgres psql -U postgres -d agentiik -c "insert into namespaces (name) values ('team')"`. | With the access model. |
| The default pool | Created with no label, and a runner claims at least one, so `setup` gives it the runner's labels. | A decision the documentation has to make. |
| The console | Not part of this stack. | Its own releases. |
| Object store | On disk under `/srv/agentiik/objects`, not MinIO. | v0.9.0 |
| `network: egress` | Refused rather than opened. | v0.9.0 |
| A certificate from a public authority | `setup` signs its own. Replace `tls/server.pem` and `tls/server.key` with yours, put its authority in `trust/` or empty it, and restart the API and NATS. | |

## Build from source instead

`compose.build.yaml` builds the three Agentiik images from the source of any tag or branch of [agentiik/agentiik](https://github.com/agentiik/agentiik) rather than pulling them from ghcr.io. Uncomment `COMPOSE_FILE` in `.env`, set `AGENTIIK_VERSION` to that tag or branch, and run `sudo ./setup`: it builds before it starts anything, which takes a few minutes.
