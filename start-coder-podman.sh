#!/usr/bin/env bash
set -euo pipefail

uid="$(id -u)"

export CODER_VERSION="${CODER_VERSION:-latest}"
export CODER_REPO="${CODER_REPO:-ghcr.io/coder/coder}"
export POSTGRES_USER="${POSTGRES_USER:-username}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-password}"
export POSTGRES_DB="${POSTGRES_DB:-coder}"
export CODER_ACCESS_URL="${CODER_ACCESS_URL:-http://localhost:7080}"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-${uid}}"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

podman_root="${PODMAN_ROOT:-${HOME}/.local/share/containers-coder/storage}"
podman_runroot="${PODMAN_RUNROOT:-/tmp/podman-coder-runroot-${uid}}"
podman_sock="${PODMAN_SOCK:-${XDG_RUNTIME_DIR}/podman/podman.sock}"

podman_cmd=(
  podman
  --root "${podman_root}"
  --runroot "${podman_runroot}"
  --storage-driver overlay
)

mkdir -p "$(dirname "${podman_sock}")" "${podman_root}" "${podman_runroot}"

if [[ ! -S "${podman_sock}" ]]; then
  nohup "${podman_cmd[@]}" system service "unix://${podman_sock}" --time=0 \
    >"${HOME}/coder-podman/podman-service.log" 2>&1 &
fi

for _ in {1..50}; do
  if [[ -S "${podman_sock}" ]] && "${podman_cmd[@]}" info >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

"${podman_cmd[@]}" pod exists coder-podman \
  || "${podman_cmd[@]}" pod create --name coder-podman -p 7080:7080

if ! "${podman_cmd[@]}" container exists coder-postgres; then
  "${podman_cmd[@]}" volume exists coder_data \
    || "${podman_cmd[@]}" volume create coder_data >/dev/null

  "${podman_cmd[@]}" run -d \
    --name coder-postgres \
    --pod coder-podman \
    -e POSTGRES_USER="${POSTGRES_USER}" \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    -e POSTGRES_DB="${POSTGRES_DB}" \
    -v coder_data:/var/lib/postgresql/data \
    docker.io/library/postgres:17 >/dev/null
else
  "${podman_cmd[@]}" start coder-postgres >/dev/null
fi

printf 'Waiting for PostgreSQL'
for _ in {1..60}; do
  if "${podman_cmd[@]}" exec coder-postgres \
    pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; then
    printf '\n'
    break
  fi
  printf '.'
  sleep 1
done

if ! "${podman_cmd[@]}" exec coder-postgres \
  pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; then
  printf '\nPostgreSQL did not become ready in time.\n' >&2
  exit 1
fi

if ! "${podman_cmd[@]}" volume exists coder_home; then
  "${podman_cmd[@]}" volume create coder_home >/dev/null
fi

if ! "${podman_cmd[@]}" container exists coder; then
  "${podman_cmd[@]}" run -d \
    --name coder \
    --pod coder-podman \
    -e CODER_PG_CONNECTION_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:5432/${POSTGRES_DB}?sslmode=disable" \
    -e CODER_HTTP_ADDRESS="0.0.0.0:7080" \
    -e CODER_ACCESS_URL="${CODER_ACCESS_URL}" \
    -v "${podman_sock}:/var/run/docker.sock" \
    -v coder_home:/home/coder \
    "${CODER_REPO}:${CODER_VERSION}" >/dev/null
else
  "${podman_cmd[@]}" start coder >/dev/null
fi

cat <<EOF
Coder is starting.

URL: ${CODER_ACCESS_URL}
Podman socket: ${podman_sock}
Logs:
  ${HOME}/coder-podman/status-coder-podman.sh
  ${podman_cmd[*]} logs -f coder
EOF
