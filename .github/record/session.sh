#!/usr/bin/env bash
# The session the home page plays, run by the record workflow inside asciinema, in the workflow repository .github/record/pi committed on its own: agk against an installation, each command one a person types after Get started, shown after a prompt, run, then left on screen a moment. The installation, agk pointed at it and the credential are the workflow's, off camera. RUN_LOG, outside the repository, keeps what agk run printed, since agk status and agk logs name the run it started.
set -euo pipefail

# A prompt as a terminal draws one, the repository's directory then $, and the command after it.
prompt() {
  printf '\033[1;34m%s\033[0m \033[2m$\033[0m %s\n' "${PWD##*/}" "$1"
  sleep 1
}

prompt "cat agentiik.yaml"
cat agentiik.yaml
sleep 3

prompt "agk push --namespace demo"
agk push --namespace demo
sleep 2

prompt "agk run --namespace demo --input darts=1000000"
agk run --namespace demo --input darts=1000000 2>&1 | tee "$RUN_LOG"
run=$(awk '/ started at / { print $2; exit }' "$RUN_LOG")
if [ -z "$run" ]; then
  echo "agk run printed no line naming the run it started" >&2
  exit 1
fi
sleep 2

prompt "agk status $run"
agk status "$run"
sleep 2

prompt "agk logs $run throw"
agk logs "$run" throw
sleep 2
