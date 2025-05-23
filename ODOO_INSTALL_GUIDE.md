# Odoo Installation Guide using installer.sh

## Introduction

This guide provides step-by-step instructions on how to use the `installer.sh` script to automate the installation of Odoo on a Debian-based Linux system. The script handles system updates, dependency installation, PostgreSQL setup, Odoo source code download, Python environment configuration, wkhtmltopdf installation, and Odoo service setup.

## Prerequisites

Before you begin, ensure you have the following:

*   A server running a Debian-based Linux distribution (e.g., Ubuntu 18.04 LTS, Ubuntu 20.04 LTS, Ubuntu 22.04 LTS).
    *   **Note:** The `wkhtmltopdf` version (0.12.5) included in the script is known to work well with Ubuntu 18.04 (Bionic). For other Ubuntu versions or Debian distributions, if you encounter issues with PDF generation, you might need to find and install a `wkhtmltopdf` package compatible with `libssl1.1` or a version of `wkhtmltopdf` suitable for your specific OS.
*   `sudo` or root access on the server.
*   Basic familiarity with the Linux command line.
*   Internet access on the server to download packages and the Odoo source code.

## Steps to Install Odoo

Follow these steps to install Odoo using the provided script:

1.  **Download the script:**

    Open your terminal and use `wget` to download the `installer.sh` script from the repository.

    ```bash
    wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPOSITORY/YOUR_BRANCH/installer.sh -O installer.sh
    ```

    **Note:** Replace `YOUR_USERNAME`, `YOUR_REPOSITORY`, and `YOUR_BRANCH` with the actual username, repository name, and branch where the `installer.sh` script is located.

2.  **Make the script executable:**

    Once downloaded, you need to give the script execute permissions.

    ```bash
    chmod +x installer.sh
    ```

3.  **Run the script:**

    Execute the script using `sudo`. This is necessary because the script will install system packages, create a system user for Odoo, and set up a system service.

    ```bash
    sudo ./installer.sh
    ```

    The script will display its progress as it executes each step. This process might take some time depending on your server's performance and internet speed.

## Post-Installation

After the script finishes, Odoo should be installed and running.

1.  **Verify Odoo service:**

    You can check the status of the Odoo service to ensure it's active and running:

    ```bash
    sudo systemctl status odoo18.service
    ```

    Look for an "active (running)" status. If there are issues, the output of this command or the log file (see below) can help diagnose them.

2.  **Accessing Odoo:**

    Open your web browser and navigate to `http://<your_server_ip>:8069`, replacing `<your_server_ip>` with the actual IP address or domain name of your server.

    You should see the Odoo database creation page or login page.

## Important Notes

*   **Default Passwords:**
    *   The script sets a default **master admin password** for Odoo to `admin`. This is used to create, manage, and restore databases from the Odoo interface.
    *   The PostgreSQL user `odoo18` is created with the password `123456`.
    *   **It is STRONGLY recommended to change both of these passwords immediately in a production environment.** The Odoo master password can be changed in the Odoo configuration file. The PostgreSQL user password should be changed using `psql` and then updated in the Odoo configuration file.

*   **Odoo Configuration File:**
    *   The main Odoo configuration file is located at `/etc/odoo18.conf`. You can modify this file to change settings like passwords, database connection details, addons paths, etc.

*   **Log File:**
    *   Odoo application logs are written to `/var/log/odoo/odoo18.log`. Check this file for errors or detailed operational messages.

*   **Odoo Source Code:**
    *   The Odoo source code is downloaded to `/opt/odoo18`.
    *   The Python virtual environment for Odoo is located at `/opt/odoo18/venv`.

*   **Customization:**
    *   The script installs Odoo from the `master` branch by default, which typically corresponds to the latest development version. If you need a specific Odoo version (e.g., 16.0, 17.0), you would need to modify the `git clone` command in the `installer.sh` script to specify the desired branch (e.g., `--branch 17.0`).
    *   The script uses specific versions for dependencies like `wkhtmltopdf` (0.12.5). If you are installing a different Odoo version or on a significantly different OS environment, these dependencies might need to be adjusted. Always refer to the Odoo documentation for the specific version you intend to install.

## Troubleshooting

*   **`wkhtmltopdf` issues:**
    *   If PDF reports are not generated correctly or you see errors related to `wkhtmltopdf`, ensure `libssl1.1` is installed and compatible with your OS version. The version of `libssl1.1` provided by the script is for Ubuntu 18.04/20.04. For newer systems (like Ubuntu 22.04+ which use `libssl3`), you might need to find an alternative `wkhtmltopdf` package (e.g., version 0.12.6 or higher compiled against `libssl3`) or install `libssl1.1` from older repositories if safe and possible.
    *   Alternatively, consider using a `wkhtmltopdf` package specifically built for your distribution if the one in the script fails.

*   **Odoo service not starting:**
    *   If the `odoo18.service` fails to start, first check its status with `sudo systemctl status odoo18.service` and `journalctl -xeu odoo18.service` for more detailed error messages.
    *   Examine the Odoo log file at `/var/log/odoo/odoo18.log` for application-specific errors. Common issues include incorrect database credentials in `/etc/odoo18.conf`, port conflicts, or problems with Python dependencies.
    *   Ensure the paths in `/etc/systemd/system/odoo18.service` (especially `ExecStart`) and `/etc/odoo18.conf` (e.g., `addons_path`, `logfile`) are correct and the `odoo18` user has the necessary permissions.

This guide should help you get Odoo up and running using the automation script. Remember to secure your installation by changing default passwords.
