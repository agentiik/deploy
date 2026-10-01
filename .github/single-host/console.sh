# shellcheck shell=bash
# Sourced by the README's script after "The first administrator", with the installation answering at
# AGENTIIK_SERVER, on its own or behind Caddy: the web console is served at the root of that address,
# an address of its own below it is answered the same page, and the files the page names are served
# beside it; any method but GET or HEAD is answered 404 there, as a route nobody registered is. With
# AGENTIIK_CONSOLE=off in .env, none of it is served, while the sign-in page and the API still
# answer. The console is put back after, as the rest of the README expects it.

cd ~/agentiik || exit

# status prints what an address answers a method with, its body kept in $RUNNER_TEMP/console.body.
status() {
  curl -sS -o "$RUNNER_TEMP/console.body" -w '%{http_code}' -X "$1" "$2"
}

# The console's page, and each file it names, a script and a style sheet among them.
if [ "$(status GET "$AGENTIIK_SERVER/")" != 200 ] || ! grep -q '<div id="console">' "$RUNNER_TEMP/console.body"; then
  echo "$AGENTIIK_SERVER/ did not answer the console's page:" >&2
  head -c 2000 "$RUNNER_TEMP/console.body" >&2
  exit 1
fi
if ! grep -q '<base href="/">' "$RUNNER_TEMP/console.body"; then
  echo "the console's page at the root of $AGENTIIK_SERVER does not carry <base href=\"/\">, which its addresses resolve from:" >&2
  grep -i '<base' "$RUNNER_TEMP/console.body" >&2
  exit 1
fi
cp "$RUNNER_TEMP/console.body" "$RUNNER_TEMP/console.page"
named=$(grep -oE '(src|href)="\./[^"]+"' "$RUNNER_TEMP/console.page" | sed -E 's/^(src|href)="\.\/(.*)"$/\2/')
if ! grep -q '\.js$' <<<"$named" || ! grep -q '\.css$' <<<"$named"; then
  echo "the console's page names no script or no style sheet: $named" >&2
  exit 1
fi
while read -r file; do
  type=$(curl -fsS -o /dev/null -w '%{content_type}' "$AGENTIIK_SERVER/$file") || {
    echo "$AGENTIIK_SERVER/$file, which the console's page names, did not answer" >&2
    exit 1
  }
  case "$file:$type" in
  *.js:text/javascript* | *.css:text/css* | *.svg:image/svg+xml*) ;;
  *)
    echo "$AGENTIIK_SERVER/$file was answered as $type" >&2
    exit 1
    ;;
  esac
done <<<"$named"

# An address of the console's below the root, as a link sent by somebody opens it.
if [ "$(status GET "$AGENTIIK_SERVER/demo/runs")" != 200 ] || ! cmp -s "$RUNNER_TEMP/console.body" "$RUNNER_TEMP/console.page"; then
  echo "$AGENTIIK_SERVER/demo/runs was not answered the console's page" >&2
  exit 1
fi
if [ "$(status POST "$AGENTIIK_SERVER/demo/runs")" != 404 ]; then
  echo "a POST to $AGENTIIK_SERVER/demo/runs was not answered 404, as an address nobody registered is" >&2
  exit 1
fi

# Off: no console anywhere, the sign-in page and the API as before. The API restarts after init, so
# what it answers is waited for rather than expected at once.
echo 'AGENTIIK_CONSOLE=off' >>.env
docker compose up -d --wait
for _ in $(seq 60); do
  [ "$(status GET "$AGENTIIK_SERVER/")" = 404 ] && break
  sleep 2
done
for address in / /demo/runs; do
  code=$(status GET "$AGENTIIK_SERVER$address")
  if [ "$code" != 404 ]; then
    echo "$AGENTIIK_SERVER$address was answered $code with AGENTIIK_CONSOLE=off, where no console is served" >&2
    exit 1
  fi
done
if [ "$(status GET "$AGENTIIK_SERVER/auth/enrol")" != 200 ]; then
  echo "the sign-in page's $AGENTIIK_SERVER/auth/enrol did not answer with AGENTIIK_CONSOLE=off, which leaves it served" >&2
  exit 1
fi
agk whoami >/dev/null || {
  echo "the API did not answer agk with AGENTIIK_CONSOLE=off" >&2
  exit 1
}

sed -i '/^AGENTIIK_CONSOLE=/d' .env
docker compose up -d --wait
for _ in $(seq 60); do
  [ "$(status GET "$AGENTIIK_SERVER/")" = 200 ] && break
  sleep 2
done
if ! cmp -s "$RUNNER_TEMP/console.body" "$RUNNER_TEMP/console.page"; then
  echo "the console was not served again once AGENTIIK_CONSOLE=off was taken out of .env" >&2
  exit 1
fi
