FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base tools needed by the installer script.
RUN set -eux; \
    timezone=$(cat /etc/timezone 2>/dev/null || echo Etc/UTC); \
    export TZ="${timezone}"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      sudo ca-certificates curl wget gnupg lsb-release locales apt-utils tzdata; \
    ln -snf "/usr/share/zoneinfo/${timezone}" /etc/localtime; \
    echo "${timezone}" > /etc/timezone; \
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen; \
    locale-gen en_US.UTF-8; \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; \
    rm -rf /var/lib/apt/lists/*

# Minimal base; you will run the Odoo script manually inside.
CMD ["sleep", "infinity"]
