FROM node:22-bookworm-slim

# Node 22 is already present from the base image, so install.sh's
# install_node_npm_interactive() path (the only sudo caller) is never reached.
# install.sh requires >=20.6.0; node:22 satisfies it.

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates git jq python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Non-root user. No sudo installed at all -- if anything tries to escalate,
# it fails loudly instead of silently succeeding.
# No explicit UID: the node base image already owns 1000, and nothing is
# volume-mounted here, so there is no host UID to line up with.
RUN useradd -m -s /bin/bash bench
USER bench
WORKDIR /home/bench

# Pin every agent-state path inside the container. Nothing resolves to a
# host path, and auth.json can only ever be read from /home/bench/.prime/agent.
ENV PRIME_AGENT_CODING_AGENT_DIR=/home/bench/.prime/agent \
    HOME=/home/bench \
    PATH=/home/bench/.npm-global/bin:/home/bench/.local/bin:$PATH

# install.sh runs `npm install -g`, which targets the root-owned global prefix
# (/usr/local/lib/node_modules) and fails with EACCES for an unprivileged user.
# Point npm at a user-owned prefix so the install stays non-root rather than
# reaching for sudo.
RUN npm config set prefix /home/bench/.npm-global

RUN mkdir -p /home/bench/.prime/agent /home/bench/work /home/bench/results

# Version pinned at build time so A and B run against identical bits.
ARG PRIME_AGENT_VERSION
ENV PRIME_AGENT_VERSION=${PRIME_AGENT_VERSION}
RUN curl -fsSL https://app.primeintellect.ai/prime-agent/install.sh -o /tmp/install.sh \
    && sh /tmp/install.sh \
    && rm /tmp/install.sh

# Assert no host credential ever lands here.
RUN test ! -f /home/bench/.prime/agent/auth.json || (echo "FAIL: auth.json present at build" && exit 1)

WORKDIR /home/bench/work
CMD ["bash"]
