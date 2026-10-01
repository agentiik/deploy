# Changelog

The releases of `deploy`.

Every repository of the project carries the same version and is tagged at the same moment, even where nothing changed, so an entry here may say that nothing was built. [Versioning](https://agentiik.github.io/docs#versioning) sets out why, and what a version promises before and after `1.0.0`.

`0.y.z` promises nothing beyond itself: what a release here describes may be gone in the next one.

## Unreleased

- `single-host/proxy/nginx.conf` passes on the web console's live connection, the WebSocket `GET /api/v1/live` opens: a `map` named for the file sets `Connection` from the request's `Upgrade`, which the server block passes on, since nginx drops both hop-by-hop headers otherwise; Caddy and Traefik pass a WebSocket on as they are. The `proxies` job's stand-in answers the handshake only where the proxy passed the upgrade on, and checks through each of the three proxies that it is upgraded and its first message arrives. The single-host README says what an nginx configuration copied before v0.6.0 needs.
- `single-host/compose.yaml` runs `init`, the API and the controller from one image, `ghcr.io/agentiik/agentiik`, which names v0.6.0 by default: each service gives its program as its command, `agentiik-api init`, `agentiik-api serve` and `agentiik-controller`, since the image has no entrypoint, and the controller keeps a container of its own, which never mounts the master key the API reads. The API's health check is `[CMD, agentiik-api, health]`. `runner` and `postgres-upgrade` keep their images, at v0.5.0 until v0.6.0 is published. A v0.5.0 installation upgrades with this `compose.yaml` and its own `.env`, as the `upgrade` job holds.
- The API serves the web console at the installation's address. `AGENTIIK_CONSOLE=off` in `.env`, which `compose.yaml` hands the API as `AGK_CONSOLE`, serves the API alone, the sign-in page included.
- The single-host README says how to try `main` before its release: `compose.yaml` downloaded from `main`, `AGENTIIK_VERSION=dev`, `docker compose pull` before each `up`, and `agk` from `main`.
- The `upgrade` job checks that each service runs the image its `compose.yaml` names for it at the version expected, rather than an image named after the service, since the API and the controller ran `api` and `controller` up to v0.5.0 and run `agentiik` after it. The workflow reads whether a version is published from `ghcr.io/agentiik/agentiik`.
- The `single-host` workflow checks the web console in each of its three modes, on its own and behind Caddy: its page at the root of the installation's address, carrying `<base href="/">`, and at an address of its own below it, each file the page names served with its type, a `POST` there answered 404; then, with `AGENTIIK_CONSOLE=off` in `.env`, every one of those addresses answered 404 while the sign-in page and the API still answer, and the console served again once the line is taken out.

## v0.5.0, 2026-09-30

- `single-host/` and `runner/` install `v0.5.0`: the images `compose.yaml` names by default, still `api` and `controller` beside `runner` and `postgres-upgrade`, `.env.example`, and the README's downloads, `docker compose ps` and `go install`. A v0.4.0 installation upgrades with v0.5.0's `compose.yaml` and its own `.env`, as the `upgrade` job holds.
- "What v0.5 does not do yet" says the console arrives in v0.6.0, served by the API from the one `agentiik` image that replaces `api` and `controller`, now that its repository has moved into `agentiik`; and that a webhook with `auth: mtls` refuses every caller behind a reverse proxy, since the API trusts no certificate a proxy forwards in a header.

## v0.4.0, 2026-09-30

- `single-host/` and `runner/` install `v0.4.0`: the images `compose.yaml` names by default, `.env.example`, and the README's downloads, `docker compose ps` and `go install`; "What v0.4 does not do yet" keeps its rows, none of which v0.4.0 delivers. A v0.3.0 installation upgrades with v0.4.0's `compose.yaml` and its own `.env`, as the `upgrade` job holds.
- The record workflow records `agk push`, `agk run`, `agk status` and `agk logs` against a single-host installation, on a three-step workflow with an input and a fan-out, for the site's home page, and uploads the cast and its poster as the artifact `agk-server-run`; it fails where the recording shows a token, a path of the machine or a host other than `localhost`.
- The record workflow makes its repositories on `main`, which the push prints, and writes the cast and its posters whole in its log with their digests, for a machine that may read the log and not the artifact.
- `single-host/README.md` makes its workflow repositories with `git init -b main`, since `agk push` creates the repository on the branch it pushes and prints it, and its first run shows v0.4.0's push naming `refs/heads/main`.

## v0.3.0, 2026-09-28

- `single-host/` and `runner/` install `v0.3.0`: the images `compose.yaml` names by default, `.env.example`, and the README's downloads, `docker compose ps` and `go install`.
- `single-host/README.md`: "What v0.3 does not do yet" leaves out creating a namespace through the API, which `agk namespace create NAME --owner LOGIN` does, and Upgrade says the API renews the bus credential itself.
- `runner/.env.example`: an administrator issues the join token.
- `single-host/README.md`: "The first administrator", created with the bootstrap token by `agk user create alice --admin`, then signed in from a browser and with `agk login`; "Change a setting" gives alice a new namespace rather than replacing the token.
- The single-host workflow runs the first administrator's commands up to the link and checks it, leaves out the blocks marked `<!-- ci: browser -->`, and replaces the bootstrap token in `.env` itself.
- `single-host/`: the API is no longer given `AGK_OPERATOR_TOKEN_FILE`, which v0.3.0 does not read, and `.env.example` calls the token in `.env` the bootstrap token.
- `proxy/nginx.conf` sets `X-Forwarded-For` from the connection, since the API counts sign-in attempts by its last entry; the Caddy and Traefik comments say they append it.
- The README states the free space a PostgreSQL major upgrade needs, and that `data/postgres-17` is a way back only before the new release has run.
- The single-host workflow upgrades the latest release, and `latest` to `dev`, with `compose.yaml` and `.env` alone, and checks that the token in `.env`, an earlier run with its outputs and the runner survive and that a new run succeeds.
- `single-host/`: PostgreSQL 18, its cluster still directly in `data/postgres`. A `postgres-upgrade` service upgrades the PostgreSQL 17 data of an installation to 18 at its next `docker compose up`, before PostgreSQL starts, and keeps the old cluster as `data/postgres-17`; nothing is asked of the person upgrading, even where v0.2.5's PostgreSQL was killed at its stop.
- `single-host/README.md`: the backup leaves out a kept cluster as it does the running one.
- The single-host workflow checks that `postgres-upgrade` is given the major version the postgres image runs, that a new installation starts on PostgreSQL 18 and that an upgrade runs 18 with the 17 cluster kept, upgrades `latest` to `dev` from the latest release's `compose.yaml`, and takes the highest version `compose.yaml` names by default as the one it runs.

## v0.2.5, 2026-09-26

- An installation of `v0.2.4` is not upgraded in place: its state is in Docker volumes, and `v0.2.5` keeps it in `AGENTIIK_DATA`. Remove it as its README said, then start anew.
- `single-host/`: NATS is off the host's network and publishes its bus port alone, `AGENTIIK_BUS_PORT`, so a program of the host on 8222 no longer stops it.
- `single-host/`, `runner/`: the state is in `AGENTIIK_DATA`, `./data` beside `compose.yaml` by default, one directory per service; PostgreSQL's socket alone stays a Docker volume.
- `single-host/`: `AGENTIIK_OPERATOR_TOKEN` is required in `.env`, and `docker compose up` refuses to start without it.
- `single-host/README.md`: the start is one block to paste, and backing up and removing follow `data/`.
- `runner/`: the runner is off the host's network, which it does not need.
- The single-host workflow checks the refusal without a token, runs the README with port 8222 held on the host, and checks what `data/` holds after the start, the backup and the removal.

## v0.2.4, 2026-09-26

- An installation made by `setup` up to `v0.2.3` is not upgraded in place: its state is in `AGENTIIK_DATA` on the host, and `v0.2.4` keeps it in Docker volumes. Install `v0.2.4` anew, then remove the old one as its README said.
- `single-host/`: a `bus` volume holds the control plane's bus credential, which the API renews and the controller reads; upgrading replaces `compose.yaml` rather than only `AGENTIIK_VERSION`.
- `single-host/`: the API has a health check, `agentiik-api health`, and the runner starts once the API answers.
- `single-host/` installs `v0.2.4` from `compose.yaml` alone: every default inside it, one optional `.env` applied at each `docker compose up -d`, an `init` service in place of `setup`, `add-runner` and the other files, state in Docker volumes, and `AGENTIIK_PROXY_URL` in place of `AGENTIIK_PUBLIC_URL`.
- `runner/`: a runner on another machine from one Compose file and its `.env`.
- The single-host workflow runs the README with no `.env`, with one and behind Caddy, and checks that a changed setting takes effect.

## v0.2.3, 2026-09-26

- `single-host/` installs `v0.2.3`.

## v0.2.2, 2026-09-26

- `single-host/`: behind a reverse proxy that terminates TLS, chosen by `AGENTIIK_PUBLIC_URL` in `.env`, with the API in plain HTTP on the loopback, the bus still on 4222 with its own TLS, ready configurations for Caddy, nginx and Traefik in `proxy/`, and the README run by CI behind Caddy too.

## v0.2.1, 2026-09-26

- `single-host/`: an installation on one Linux host with Docker Compose (PostgreSQL, NATS, the API, the controller and a runner), a `setup` script that prepares the host and joins the runner, and a README that is its user guide, whose commands CI runs verbatim through a first workflow run.

## v0.2.0, 2026-09-26

Nothing changed here beyond `CLAUDE.md`, copied from `.github` to name `homebrew-tap`. The version moves because every repository carries the same one, which [Versioning](https://agentiik.github.io/docs#versioning) sets out.

## v0.1.2, 2026-09-13

Nothing changed here. The version moves because every repository carries the same one, which [Versioning](https://agentiik.github.io/docs#versioning) sets out.

The release is documentation: a [Get started](https://agentiik.github.io/docs#get-started) chapter at the top of the site, written from a run against `v0.1.1` rather than from what the rest of the page promises, and a recorded session of the command line on the home page.

## v0.1.1, 2026-09-13

This file, and nothing else.

`v0.1.0` was tagged before its changelog was written, and the fix for that is not to move the tag. Within minutes of the push, `sum.golang.org` had recorded the tagged commit of `agentiik` and `bricks` in a public append-only log and `proxy.golang.org` had cached it, so moving `v0.1.0` would have left `go get` serving the old code for ever and made a direct fetch fail with a checksum mismatch that reads as a supply-chain attack. A tag is a name somebody else pins, and a name that quietly comes to mean something else is worse than a second name.

So `v0.1.0` stays exactly where it is, describing exactly what it shipped, and this release adds the description. Every repository gets it at the same version on the same day, as every release here does. From now on a version's entry is merged before its tag is placed, which is written down in the conventions the documentation fixes.

## v0.1.0, 2026-09-12

Nothing is built yet. The repository carries its README, its licence and the shared instructions, and is tagged because every repository is.

The Compose stacks, the installer and the migration notes for the three deployment profiles. The roadmap says which release fills this repository: <https://agentiik.github.io/docs/roadmap>.
