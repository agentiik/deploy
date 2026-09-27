# shellcheck shell=bash
# Sourced by the README's script once the installation is up: every service keeps its state in
# data/ beside compose.yaml, and no Docker volume holds any of it, PostgreSQL's socket aside.

for dir in api bus controller nats objects postgres runner runner-state; do
  if ! sudo test -d "data/$dir"; then
    echo "data/$dir is missing after docker compose up, where compose.yaml keeps that service's state" >&2
    exit 1
  fi
done
for file in postgres/PG_VERSION api/master-key; do
  if ! sudo test -s "data/$file"; then
    echo "data/$file is missing or empty after docker compose up, where the installation keeps it" >&2
    exit 1
  fi
done

# A new installation starts on the major version of PostgreSQL compose.yaml runs, its cluster directly in data/postgres.
want=$(sed -n 's/^ *image: postgres:\([0-9]*\)-alpine$/\1/p' compose.yaml)
if [ "$(sudo cat data/postgres/PG_VERSION)" != "$want" ]; then
  echo "data/postgres holds a cluster of PostgreSQL $(sudo cat data/postgres/PG_VERSION), where compose.yaml runs $want" >&2
  exit 1
fi

volumes=$(docker volume ls --quiet --filter label=com.docker.compose.project=agentiik)
if [ "$volumes" != agentiik_socket ]; then
  echo "the installation's Docker volumes are $volumes, where PostgreSQL's socket alone is kept in one" >&2
  exit 1
fi
