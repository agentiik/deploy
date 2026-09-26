# shellcheck shell=bash
# Sourced by the README's script after "Back up": the dump is a database, and the archive holds the
# master key and the objects, without PostgreSQL's files, which the dump stands for.

if ! docker compose exec -T postgres pg_restore --list <agentiik.dump >/dev/null; then
  echo "agentiik.dump is not a dump pg_restore reads" >&2
  exit 1
fi
contents=$(tar -tzf agentiik-data.tar.gz)
for want in data/api/master-key data/objects/ data/runner-state/; do
  if ! grep -qxF "$want" <<<"$contents"; then
    echo "agentiik-data.tar.gz does not hold $want" >&2
    exit 1
  fi
done
if grep -q '^data/postgres' <<<"$contents"; then
  echo "agentiik-data.tar.gz holds PostgreSQL's files, which the dump stands for" >&2
  exit 1
fi
