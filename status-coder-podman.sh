#!/usr/bin/env bash
set -euo pipefail

uid="$(id -u)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-${uid}}"

podman_root="${PODMAN_ROOT:-${HOME}/.local/share/containers-coder/storage}"
podman_runroot="${PODMAN_RUNROOT:-/tmp/podman-coder-runroot-${uid}}"
podman_sock="${PODMAN_SOCK:-${XDG_RUNTIME_DIR}/podman/podman.sock}"

podman_cmd=(
  podman
  --root "${podman_root}"
  --runroot "${podman_runroot}"
  --storage-driver overlay
)

"${podman_cmd[@]}" ps --pod --filter pod=coder-podman
printf '\nRecent Coder logs:\n'
"${podman_cmd[@]}" logs --tail 80 coder
