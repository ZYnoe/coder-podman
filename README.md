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
