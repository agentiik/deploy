# Changelog

The releases of `deploy`.

Every repository of the project carries the same version and is tagged at the same moment, even where nothing changed, so an entry here may say that nothing was built. [Versioning](https://agentiik.github.io/docs#versioning) sets out why, and what a version promises before and after `1.0.0`.

`0.y.z` promises nothing beyond itself: what a release here describes may be gone in the next one.

## Unreleased

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
