# shellcheck shell=bash
# Sourced by the README's script after "Change a setting", which wrote a new AGENTIIK_OPERATOR_TOKEN and
# AGENTIIK_NAMESPACE in .env and ran docker compose up -d: both have taken effect, with nothing but
# that. The new token is accepted and the previous one refused, and a workflow runs end to end in
# the new namespace, on the runner restarted with the rest.

# The API restarts after init, so the new token is waited for rather than expected at once.
pools="$AGENTIIK_SERVER/api/v1/runner-pools"
for _ in $(seq 60); do
  curl -fsS -o /dev/null -H "Authorization: Bearer $AGENTIIK_TOKEN" "$pools" 2>/dev/null && break
  sleep 2
done
curl -fsS -o /dev/null -H "Authorization: Bearer $AGENTIIK_TOKEN" "$pools"

# shellcheck disable=SC2154 # set by before-change.sh, in the same shell
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $previous_token" "$pools")
case $status in
401 | 403) ;;
*)
  echo "the previous operator token was answered $status after it was replaced in .env, where it is refused" >&2
  exit 1
  ;;
esac

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
