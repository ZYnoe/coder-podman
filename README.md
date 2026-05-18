# Coder on rootless Podman

This directory runs the Coder Docker install pattern with Podman and no sudo.

## Start

```bash
cd ~/coder-podman
./start-coder-podman.sh
```

Open <http://localhost:7080>.

## Configuration

Set these environment variables before starting if needed:

```bash
export CODER_ACCESS_URL=http://localhost:7080
export CODER_VERSION=latest
export POSTGRES_USER=username
export POSTGRES_PASSWORD=password
export POSTGRES_DB=coder
```

For a remote-accessible deployment, set `CODER_ACCESS_URL` to an address that
workspaces can reach.

## Stop

```bash
cd ~/coder-podman
./stop-coder-podman.sh
```

Data is stored in Podman volumes `coder_data` and `coder_home` under
`~/.local/share/containers-coder/storage`.

## Podman socket for templates

The Coder container bind-mounts the host rootless Podman API socket at
`/var/run/docker.sock` and exports:

```bash
DOCKER_HOST=unix:///var/run/docker.sock
```

Terraform templates using the `kreuzwerker/docker` provider should use the
in-container socket path:

```hcl
provider "docker" {
  host = "unix:///var/run/docker.sock"
}
```

`start-coder-podman.sh` runs the Coder container as container UID `0:0` so it
maps back to the host user that owns the rootless Podman socket. PostgreSQL and
Coder data remain in the existing `coder_data` and `coder_home` volumes.

Validation commands:

```bash
curl --unix-socket /run/user/$(id -u)/podman/podman.sock http://d/_ping
./status-coder-podman.sh
podman --root ~/.local/share/containers-coder/storage \
  --runroot /tmp/podman-coder-runroot-$(id -u) \
  --storage-driver overlay \
  inspect coder --format '{{.Config.User}} {{json .Config.Env}} {{json .Mounts}}'
```
