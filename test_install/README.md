# Odoo 19 Installer Test Environment

This folder provides a minimal Docker setup to exercise the `odoo_install.sh` script in a clean Ubuntu 24.04 container.
The setup for Debian is similar and can be found in the `debian/` subfolder.

## Prerequisites
- Docker 24+
- Docker Compose plugin (`docker compose` CLI)

## Build the Image
```bash
docker compose build
```

## Start the Test Container
Run the container detached so it stays online for manual testing:
```bash
docker compose up -d
```

## Run the Installer Script Inside the Container
1. Attach to the container shell:
   ```bash
   docker compose exec odoo19 bash
   ```
2. Make the script executable (first run only):
   ```bash
   chmod +x /opt/odoo-install/odoo_install.sh
   ```
3. Execute the installer:
   ```bash
   /opt/odoo-install/odoo_install.sh
   ```

The script runs as root inside the container, so the bundled `sudo` calls succeed without additional configuration. The Docker image already sets locale and timezone data to avoid interactive prompts from `tzdata`.

## Reset the Environment
To destroy the test container and start fresh:
```bash
docker compose down -v
```

Re-run the **Build** and **Start** steps to begin another test cycle.
