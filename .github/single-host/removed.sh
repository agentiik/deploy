# shellcheck shell=bash
# Sourced by the README's script after "Remove": nothing of the installation is left, neither its
# state, nor the work root, nor a container or a volume of the project.

for path in data /var/lib/agentiik/work; do
  if [ -e "$path" ]; then
    echo "$path is still there after the README removed the installation" >&2
    exit 1
  fi
done
left=$(docker ps --all --quiet --filter label=com.docker.compose.project=agentiik)
left="$left$(docker volume ls --quiet --filter label=com.docker.compose.project=agentiik)"
if [ -n "$left" ]; then
  echo "containers or volumes of the project agentiik are left after the README removed it: $left" >&2
  exit 1
fi
