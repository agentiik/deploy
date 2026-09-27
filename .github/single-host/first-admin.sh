# shellcheck shell=bash
# Sourced by the README's script after "The first administrator", which created alice with the
# bootstrap token and gave her the namespace demo. The test has no browser to open the link in and
# register a passkey, nor to run agk login, so it checks what leads there, and that the bootstrap
# token goes on working until alice has signed in, since the rest of the README runs with it here.

user=$(agk user show alice -o json) || exit
if ! jq -e '.admin and (has("last_sign_in_at") | not)' <<<"$user" >/dev/null; then
  echo "alice is not an administrator who has never signed in after agk user create alice --admin: $user" >&2
  exit 1
fi

grants=$(agk grants demo -o json) || exit
if ! jq -e 'any(.grants[]; .principal == "alice" and .role == "owner")' <<<"$grants" >/dev/null; then
  echo "alice holds no owner grant on demo after agk share demo --user alice --role owner: $grants" >&2
  exit 1
fi

# The link, asked for again as the README says to for one that lapsed: a fresh one, the one printed
# before revoked. It opens the enrolment page on the address agk reaches, which the certificate the
# README trusted serves, and carries its code after the #, which a browser never sends.
created=$(agk user create alice --admin) || exit
link=$(grep '^https://' <<<"$created" || true)
code=${link#"$AGENTIIK_SERVER/auth/enrol#"}
if [ "$code" = "$link" ] || ! grep -Eqx 'agkenrol_[A-Za-z0-9_-]{43,}' <<<"$code"; then
  echo "agk user create alice --admin printed no link to $AGENTIIK_SERVER/auth/enrol with an enrolment code after its #: $created" >&2
  exit 1
fi
if ! curl -fsS -o /dev/null "${link%%#*}"; then
  echo "the enrolment page ${link%%#*} did not answer over the certificate the README trusts" >&2
  exit 1
fi

me=$(agk whoami -o json) || exit
if ! jq -e '.principal == "operator" and .admin' <<<"$me" >/dev/null; then
  echo "the bootstrap token no longer answers as the administrator operator, while alice has not signed in: $me" >&2
  exit 1
fi
