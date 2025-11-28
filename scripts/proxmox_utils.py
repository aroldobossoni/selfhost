"""Proxmox utility functions for LXC management via SSH."""

import os
import sys
import time
from pathlib import Path

sys_path = Path(__file__).parent.parent
sys.path.insert(0, str(sys_path))

from scripts.utils import log_info, log_warn, log_error, run_cmd


def download_template(proxmox_host: str, ssh_user: str, storage: str, template_name: str) -> bool:
    """
    Download LXC template if not exists.
    
    Args:
        proxmox_host: Proxmox host IP or hostname
        ssh_user: SSH user for Proxmox host
        storage: Storage name (e.g., 'local')
        template_name: Template name (e.g., 'alpine-3.19-default_20240101_amd64.tar.xz')
    
    Returns:
        True if template exists or was downloaded successfully
    """
    log_info(f"Checking template '{template_name}' on storage '{storage}'...")
    
    # Check if template exists
    check_cmd = f"pveam list {storage} | grep -q '{template_name}'"
    result = run_cmd(
        ["ssh", "-o", "StrictHostKeyChecking=no", f"{ssh_user}@{proxmox_host}", check_cmd],
        capture=True,
        check=False
    )
    
    if result.returncode == 0:
        log_info(f"Template '{template_name}' already exists")
        return True
    
    # Download template
    log_info(f"Downloading template '{template_name}'...")
    download_cmd = f"pveam download {storage} {template_name}"
    result = run_cmd(
        ["ssh", "-o", "StrictHostKeyChecking=no", f"{ssh_user}@{proxmox_host}", download_cmd],
        capture=True,
        check=False
    )
    
    if result.returncode == 0:
        log_info(f"Template '{template_name}' downloaded successfully")
        return True
    
    log_error(f"Failed to download template '{template_name}': {result.stderr}")
    return False


def install_docker(
    proxmox_host: str,
    ssh_user: str,
    container_id: str,
    install_compose: bool = True
) -> bool:
    """
    Install Docker and SSH on Alpine LXC container.
    
    Args:
        proxmox_host: Proxmox host IP or hostname
        ssh_user: SSH user for Proxmox host
        container_id: LXC container ID (VMID)
        install_compose: Whether to install Docker Compose
    
    Returns:
        True if installation was successful
    """
    log_info(f"Installing Docker on container {container_id}...")
    
    # Wait for container to be ready
    time.sleep(10)
    
    # Build package list
    packages = "docker docker-cli openssh"
    if install_compose:
        packages += " docker-compose"
    
    # Install Docker and SSH
    install_cmd = f'''
        apk update && \
        apk add --no-cache {packages} && \
        rc-update add docker boot && \
        rc-update add sshd boot && \
        ssh-keygen -A && \
        service docker start && \
        service sshd start
    '''
    
    result = run_cmd(
        [
            "ssh", "-o", "StrictHostKeyChecking=no",
            f"{ssh_user}@{proxmox_host}",
            f"pct exec {container_id} -- sh -c '{install_cmd}'"
        ],
        capture=True,
        check=False
    )
    
    if result.returncode != 0:
        log_error(f"Failed to install Docker: {result.stderr}")
        return False
    
    log_info("Docker installed successfully")
    
    # Setup SSH directory
    setup_ssh_cmd = "mkdir -p /root/.ssh && chmod 700 /root/.ssh"
    run_cmd(
        [
            "ssh", "-o", "StrictHostKeyChecking=no",
            f"{ssh_user}@{proxmox_host}",
            f"pct exec {container_id} -- sh -c '{setup_ssh_cmd}'"
        ],
        capture=True,
        check=False
    )
    
    # Copy Proxmox host public key to container (ed25519 only)
    copy_key_cmd = f"cat /root/.ssh/id_ed25519.pub | pct exec {container_id} -- sh -c 'cat >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys'"
    run_cmd(
        [
            "ssh", "-o", "StrictHostKeyChecking=no",
            f"{ssh_user}@{proxmox_host}",
            copy_key_cmd
        ],
        capture=True,
        check=False
    )
    
    # Copy local machine's public key if available (ed25519 only)
    local_key_path = Path.home() / ".ssh" / "id_ed25519.pub"
    if local_key_path.exists():
        local_key = local_key_path.read_text().strip()
        add_key_cmd = f"pct exec {container_id} -- sh -c 'echo \"{local_key}\" >> /root/.ssh/authorized_keys'"
        run_cmd(
            [
                "ssh", "-o", "StrictHostKeyChecking=no",
                f"{ssh_user}@{proxmox_host}",
                add_key_cmd
            ],
            capture=True,
            check=False
        )
        log_info("Local SSH key added to container")
    
    log_info("Docker installation and SSH setup completed")
    return True


def main():
    """CLI entry point for standalone execution."""
    import sys
    
    if len(sys.argv) < 2:
        print("Usage:")
        print("  download_template <proxmox_host> <ssh_user> <storage> <template_name>")
        print("  install_docker <proxmox_host> <ssh_user> <container_id> [install_compose]")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "download_template":
        if len(sys.argv) < 6:
            print("Usage: download_template <proxmox_host> <ssh_user> <storage> <template_name>")
            sys.exit(1)
        success = download_template(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
        sys.exit(0 if success else 1)
    
    elif command == "install_docker":
        if len(sys.argv) < 5:
            print("Usage: install_docker <proxmox_host> <ssh_user> <container_id> [install_compose]")
            sys.exit(1)
        install_compose = sys.argv[5].lower() == "true" if len(sys.argv) > 5 else True
        success = install_docker(sys.argv[2], sys.argv[3], sys.argv[4], install_compose)
        sys.exit(0 if success else 1)
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()

