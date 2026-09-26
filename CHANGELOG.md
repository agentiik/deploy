# Changelog

The releases of `deploy`.

Every repository of the project carries the same version and is tagged at the same moment, even where nothing changed, so an entry here may say that nothing was built. [Versioning](https://agentiik.github.io/docs#versioning) sets out why, and what a version promises before and after `1.0.0`.

`0.y.z` promises nothing beyond itself: what a release here describes may be gone in the next one.

## Unreleased

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
