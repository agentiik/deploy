# shellcheck shell=bash
# Sourced by the README's script after "Change a setting", which wrote AGENTIIK_NAMESPACE in .env, ran
# docker compose up -d and gave alice the new namespace: it has taken effect, with nothing but that,
# and a workflow runs end to end there, on the runner restarted with the rest.

grants=$(agk grants team -o json) || exit
if ! jq -e 'any(.grants[]; .principal == "alice" and .role == "owner")' <<<"$grants" >/dev/null; then
  echo "alice holds no owner grant on team after agk share team --user alice --role owner: $grants" >&2
  exit 1
fi

mkdir -p ~/team-run && cd ~/team-run && git init -q || exit
cat >agentiik.yaml <<'EOF'
apiVersion: agentiik.dev/v1
kind: Workflow
metadata:
  name: team-run
  namespace: team
steps:
  greet:
    image: alpine:3.21
    script:
      - echo "hello from the namespace team"
    outputs: [out]
EOF
git add agentiik.yaml && git commit -qm "A workflow in the new namespace"
agk push --namespace team
agk run --namespace team
cd ~/agentiik || exit

# The other setting the README says a change applies: a new AGENTIIK_OPERATOR_TOKEN replaces the
# bootstrap token until the first administrator has signed in, which nobody does here, since the
# test has no browser. The new token is accepted and the previous one refused, and the rest of the
# README runs with the new one.
previous_token=$AGENTIIK_TOKEN
sed -i '/^AGENTIIK_OPERATOR_TOKEN=/d' .env
echo "AGENTIIK_OPERATOR_TOKEN=$(openssl rand -hex 32)" >>.env
docker compose up -d --wait
AGENTIIK_TOKEN=$(sed -n 's/^AGENTIIK_OPERATOR_TOKEN=//p' .env)
export AGENTIIK_TOKEN

# The API restarts after init, so the new token is waited for rather than expected at once.
pools="$AGENTIIK_SERVER/api/v1/runner-pools"
for _ in $(seq 60); do
  curl -fsS -o /dev/null -H "Authorization: Bearer $AGENTIIK_TOKEN" "$pools" 2>/dev/null && break
  sleep 2
done
curl -fsS -o /dev/null -H "Authorization: Bearer $AGENTIIK_TOKEN" "$pools"

status=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $previous_token" "$pools")
case $status in
401 | 403) ;;
*)
  echo "the previous bootstrap token was answered $status after it was replaced in .env, where it is refused" >&2
  exit 1
  ;;
esac
