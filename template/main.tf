terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

locals {
  username = data.coder_workspace_owner.me.name
}

provider "coder" {}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  startup_script = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail

    export PATH="$HOME/.local/bin:$HOME/.pixi/bin:/opt/pixi/bin:/usr/local/bin:$PATH"

    mkdir -p "$HOME/.local/bin" "$HOME/.local/lib" "$HOME/project"

    echo "==> Versions"
    ubuntu_version="$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2- | tr -d '"')"
    echo "Ubuntu: $ubuntu_version"
    git --version || true
    node --version || true
    npm --version || true
    uv --version || true
    pixi --version || true
    codex --version || true
    claude --version || true

    echo "==> Installing/updating code-server"
    if [ ! -x "$HOME/.local/bin/code-server" ]; then
      curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix="$HOME/.local"
    fi

    echo "==> Installing VS Code extensions for code-server"
    # code-server uses Open VSX by default. These may fail if not available there.
    # The '|| true' keeps the workspace usable even if a marketplace extension is unavailable.
    "$HOME/.local/bin/code-server" --install-extension OpenAI.chatgpt || true
    "$HOME/.local/bin/code-server" --install-extension anthropic.claude-code || true

    echo "==> Starting code-server"
    pkill -f "code-server.*13337" || true
    "$HOME/.local/bin/code-server" \
      --auth none \
      --port 13337 \
      --host 0.0.0.0 \
      "$HOME/project" \
      > "$HOME/.code-server.log" 2>&1 &
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Ubuntu"
    key          = "2_ubuntu"
    script       = "grep PRETTY_NAME /etc/os-release | cut -d= -f2- | tr -d '\"'"
    interval     = 3600
    timeout      = 1
  }

  metadata {
    display_name = "uv"
    key          = "3_uv"
    script       = "uv --version | awk '{print $2}'"
    interval     = 3600
    timeout      = 1
  }

  metadata {
    display_name = "pixi"
    key          = "4_pixi"
    script       = "pixi --version | awk '{print $2}'"
    interval     = 3600
    timeout      = 1
  }

  metadata {
    display_name = "Codex"
    key          = "5_codex"
    script       = "codex --version 2>/dev/null | head -n1 || echo unavailable"
    interval     = 3600
    timeout      = 2
  }

  metadata {
    display_name = "Claude Code"
    key          = "6_claude"
    script       = "claude --version 2>/dev/null | head -n1 || echo unavailable"
    interval     = 3600
    timeout      = 2
  }
}

resource "coder_app" "code_server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code Server"
  url          = "http://localhost:13337/?folder=/home/${local.username}/project"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

# Coder-maintained File Browser module.
# It exposes a web file manager as a Coder app.
module "filebrowser" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/filebrowser/coder"
  version = "1.1.5"

  agent_id      = coder_agent.main.id
  folder        = "/home/${local.username}"
  database_path = ".config/filebrowser.db"
  subdomain     = false
  agent_name    = "main"
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"

  lifecycle {
    ignore_changes = all
  }
}

resource "docker_image" "main" {
  name = "coder-${data.coder_workspace.me.id}"

  build {
    context = "./build"
    build_args = {
      USER = local.username
    }
  }

  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count

  image = docker_image.main.name
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"

  hostname = data.coder_workspace.me.name

  entrypoint = [
    "sh",
    "-c",
    replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")
  ]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/${local.username}"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
}
