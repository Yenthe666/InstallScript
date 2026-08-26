FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

# Install base tools needed by the installer script.
RUN set -eux; \
    timezone=$(cat /etc/timezone 2>/dev/null || echo Etc/UTC); \
    export TZ="${timezone}"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      sudo ca-certificates curl wget gnupg lsb-release locales apt-utils tzdata \
      systemd systemd-sysv dbus; \
    ln -snf "/usr/share/zoneinfo/${timezone}" /etc/localtime; \
    echo "${timezone}" > /etc/timezone; \
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen; \
    locale-gen en_US.UTF-8; \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; \
    # Remove unnecessary systemd services for container use \
    systemctl mask \
      dev-hugepages.mount \
      sys-fs-fuse-connections.mount \
      sys-kernel-config.mount \
      display-manager.service \
      graphical.target \
      systemd-logind.service \
      systemd-remount-fs.service \
      getty.target \
      console-getty.service; \
    rm -rf /var/lib/apt/lists/*

# Initialize systemd and keep container running
CMD ["/lib/systemd/systemd"]
