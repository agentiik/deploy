# shellcheck shell=bash
# What a runner host needs before join, shared by setup, on the installation's own host, and by
# add-runner, on another machine. Sourced, with say and die defined and run as root.

# The account every Agentiik image runs as, which owns what the runner reads and writes.
agent=65532

# The tmpfs secret values are written on before a step is given them. The runner refuses one that
# is not a tmpfs mounted noexec,nosuid,nodev.
secrets=/run/agentiik/secrets

# The runner's image, as every flag of the container form, beside the paths its constants name,
# the same on the host and in its container since the Docker daemon resolves bind sources on the
# host. It reaches the API and the bus through the host's network, and trusts the certificate in
# /etc/agentiik/trust beside the system's own authorities.
# shellcheck disable=SC2034 # used by add-runner
runner_container=(
  --network host --userns host
  --cap-drop ALL --cap-add CHOWN --cap-add FOWNER --cap-add DAC_OVERRIDE
  -e SSL_CERT_DIR=/etc/agentiik/trust
  -v /var/run/docker.sock:/var/run/docker.sock
  -v /var/lib/agentiik:/var/lib/agentiik
  -v "$secrets:$secrets"
  -v /etc/agentiik:/etc/agentiik
)

prepare_runner_host() {
  install -d -m 0755 /etc/agentiik /etc/agentiik/trust
  install -d -m 0700 -o "$agent" -g "$agent" /var/lib/agentiik

  # Mounted now, and by the line in /etc/fstab at every boot.
  grep -qs " $secrets " /etc/fstab ||
    printf 'tmpfs %s tmpfs noexec,nosuid,nodev,size=64m,mode=0700,uid=%s,gid=%s 0 0\n' "$secrets" "$agent" "$agent" >>/etc/fstab
  install -d -m 0700 "$secrets"
  grep -qs " $secrets " /proc/mounts || mount "$secrets"
  say "the secrets tmpfs is mounted at $secrets, and /etc/fstab mounts it at boot"

  local remap
  if docker info --format '{{json .SecurityOptions}}' | grep -q 'name=userns'; then
    remap="# This daemon remaps user namespaces, so the runner keeps its floor.
require_userns_remap = true"
  else
    remap="# This daemon does not remap user namespaces, and the runner refuses such a daemon unless this
# line says otherwise. false gives up that floor on this host: root in a step's container is root on
# this host, and a process that escapes a container is that account rather than an unprivileged one
# that maps to no real user. Remap the daemon (userns-remap in /etc/docker/daemon.json), set this to
# true and restart the runner to keep it.
require_userns_remap = false"
  fi
  cat >/etc/agentiik/runner.toml <<TOML
# Written by github.com/agentiik/deploy. https://agentiik.github.io/docs/#configuration lists every key.

$remap

# The tmpfs, mounted noexec,nosuid,nodev, that secret values are written on before a step is given them.
secrets_dir = "$secrets"
TOML
  chmod 0644 /etc/agentiik/runner.toml
}
