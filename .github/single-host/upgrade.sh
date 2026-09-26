# shellcheck shell=bash
# Sourced by each step of the upgrade job, which installs a deployment the way a person did, runs a workflow on it, upgrades it by changing compose.yaml and .env alone, and checks that nothing else was needed. What one step records for a later one is kept in $RUNNER_TEMP/upgrade, since each step is a shell of its own.

installation=$HOME/agentiik
state=$RUNNER_TEMP/upgrade
mkdir -p "$state"

# fail says what the upgrade broke, naming where it started from, and ends the step.
fail() {
  echo "upgrading $FROM_LABEL with compose.yaml and .env alone: $*" >&2
  exit 1
}

# token is the operator token in .env, which agk reads as AGENTIIK_TOKEN.
token() {
  sed -n 's/^AGENTIIK_OPERATOR_TOKEN=//p' "$installation/.env"
}

# api reads one route of the installation with the operator token.
api() {
  curl -fsS -H "Authorization: Bearer $AGENTIIK_TOKEN" "$AGENTIIK_SERVER$1"
}

# images_are checks that the installation runs the images of one version, the one it was installed or upgraded to.
images_are() {
  local want=$1 service image
  for service in init:api api:api controller:controller runner:runner; do
    image=$(cd "$installation" && docker compose ps --all --format '{{.Image}}' "${service%%:*}")
    if [ "$image" != "ghcr.io/agentiik/${service#*:}:$want" ]; then
      fail "the service ${service%%:*} runs $image, where ghcr.io/agentiik/${service#*:}:$want was expected"
    fi
  done
}

# run_workflow pushes and runs the workflow of ~/upgrade-run to its end, keeping what agk printed in $state/NAME.log, and prints the run's identifier.
run_workflow() {
  local log=$state/$1.log
  (cd ~/upgrade-run && agk push --namespace demo >&2 && agk run --namespace demo 2>&1 | tee "$log" >&2) ||
    fail "a run of upgrade-run did not succeed $2, as $log above says"
  awk '/ started at / { print $2; exit }' "$log"
}

# snapshot keeps in $state/NAME what the installation answers about a run: its state, each step's verdict and the digests of what it published, both outputs of the workflow, and the file greet left as an artifact. Two snapshots of one run are the same file for file, whatever the version answering.
snapshot() {
  local run=$1 dir=$state/$2 name
  mkdir -p "$dir"
  api "/api/v1/runs/$run" | jq -S '{
      state, namespace, workflow, commit, outputs,
      steps: ([.steps[] | {step, verdict, ports: ((.ports // {}) | map_values({digest, items}))}] | sort_by(.step))
    }' >"$dir/run.json" || fail "run $run could not be read $3"
  for name in greeting shout; do
    api "/api/v1/runs/$run/outputs/$name" >"$dir/output-$name" || fail "the output $name of run $run could not be read $3"
  done
  api "/api/v1/artifacts/agk%3A%2F%2Frun%2F$run%2Fgreet%2Fout%2Fgreeting.txt" >"$dir/greeting.txt" ||
    fail "the artifact greeting.txt of run $run could not be read $3"
  if [ "$(jq -r .state "$dir/run.json")" != succeeded ]; then
    fail "run $run reads as $(jq -r .state "$dir/run.json") $3, where it succeeded"
  fi
}

# ready_runners prints the runners that are ready and have said so at a heartbeat since SECONDS, a Unix time, and fails where none has within three minutes. A reported state alone is what the runner last said, which may be from before the upgrade.
ready_runners() {
  local since=$1 runners ready
  for _ in $(seq 90); do
    # shellcheck disable=SC2016 # $since is jq's, given with --argjson
    if runners=$(api /api/v1/runners 2>/dev/null) &&
      ready=$(jq -r --argjson since "$since" '.runners[]
          | select(.state != "revoked" and .reported_state == "ready")
          | select((.last_seen_at // "" | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | try fromdateiso8601 catch 0) >= $since)
          | "\(.runner) \(.agent_version)"' <<<"$runners") &&
      [ -n "$ready" ]; then
      echo "$ready"
      return 0
    fi
    sleep 2
  done
  echo "the runners as the installation lists them: ${runners:-none}" >&2
  return 1
}
