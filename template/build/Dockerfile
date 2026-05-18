FROM ubuntu:latest

ARG USER=coder
ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    less \
    locales \
    nano \
    npm \
    openssh-client \
    python3 \
    python3-pip \
    ripgrep \
    sudo \
    unzip \
    wget \
    xz-utils \
    zsh \
 && locale-gen en_US.UTF-8 \
 && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Node/npm are needed for Codex CLI and Claude Code CLI.
RUN npm install -g npm@latest \
 && npm install -g @openai/codex@latest @anthropic-ai/claude-code@latest \
 && npm cache clean --force

# uv latest, installed system-wide.
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh \
 && chmod +x /usr/local/bin/uv /usr/local/bin/uvx

# pixi latest. Official installer defaults to ~/.pixi/bin, so install as root then expose globally.
ENV PIXI_HOME=/opt/pixi
RUN curl -fsSL https://pixi.sh/install.sh | bash \
 && ln -sf /opt/pixi/bin/pixi /usr/local/bin/pixi

# Create workspace user.
RUN useradd --groups sudo --create-home --shell /bin/bash "${USER}" \
 && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USER}" \
 && chmod 0440 "/etc/sudoers.d/${USER}"

USER ${USER}
WORKDIR /home/${USER}

ENV PATH="/home/${USER}/.local/bin:/home/${USER}/.pixi/bin:/opt/pixi/bin:/usr/local/bin:${PATH}"

RUN mkdir -p /home/${USER}/project
