"""Docker cleanup utilities via SSH."""

from .utils import log_info, log_warn, log_step, run_cmd


def cleanup_docker_resources(host: str, user: str, network_name: str = "infisical") -> bool:
    """Clean up Docker containers, volumes, and networks via SSH."""
    log_step("Cleaning up Docker resources...")

    cleanup_script = f'''
        # Find containers connected to network
        CONTAINERS=$(docker network inspect {network_name} --format '{{{{range .Containers}}}}{{{{.Name}}}} {{{{end}}}}' 2>/dev/null || echo '')

        if [ -n "$CONTAINERS" ]; then
            echo "Stopping containers: $CONTAINERS"
            for container in $CONTAINERS; do
                docker stop "$container" 2>/dev/null || true
                docker rm -f "$container" 2>/dev/null || true
            done
        fi

        # Also stop/remove known infisical containers by name
        for container in infisical infisical-postgres infisical-redis; do
            docker stop "$container" 2>/dev/null || true
            docker rm -f "$container" 2>/dev/null || true
        done

        # Force disconnect all containers from network
        docker network inspect {network_name} --format '{{{{range $key, $value := .Containers}}}}{{{{println $key}}}}{{{{end}}}}' 2>/dev/null | while read container_id; do
            if [ -n "$container_id" ]; then
                docker network disconnect -f {network_name} "$container_id" 2>/dev/null || true
            fi
        done

        # Force remove network if it exists
        docker network rm {network_name} 2>/dev/null || true

        # Remove volumes (important: this deletes all data!)
        for volume in {network_name}_postgres_data {network_name}_redis_data; do
            docker volume rm "$volume" 2>/dev/null || true
        done
        echo "Docker cleanup completed (containers, network, volumes)"
    '''

    try:
        result = run_cmd(
            ["ssh", "-o", "StrictHostKeyChecking=no", f"{user}@{host}", cleanup_script],
            capture=True,
            check=False
        )

        if result.returncode == 0:
            log_info("Docker cleanup completed")
            return True

        log_warn(f"Docker cleanup had issues: {result.stderr}")
        return True  # Non-fatal

    except Exception as e:
        log_warn(f"Docker cleanup failed: {e}")
        return True  # Non-fatal


def copy_ssh_key_to_container(
    proxmox_host: str,
    proxmox_user: str,
    container_id: str,
    public_key: str
) -> bool:
    """Copy SSH public key to LXC container via Proxmox."""
    log_step(f"Copying SSH key to container {container_id}...")

    # Check if key already exists
    check_cmd = f"pct exec {container_id} -- cat /root/.ssh/authorized_keys 2>/dev/null"
    try:
        result = run_cmd(
            ["ssh", "-o", "StrictHostKeyChecking=no", f"{proxmox_user}@{proxmox_host}", check_cmd],
            capture=True,
            check=False
        )

        # Extract key fingerprint to compare
        key_part = public_key.split()[1] if len(public_key.split()) > 1 else public_key
        if key_part in result.stdout:
            log_info("SSH key already exists in container")
            return True

    except Exception:
        pass  # Continue to add key

    # Add key to container
    add_cmd = f'''pct exec {container_id} -- sh -c '
        mkdir -p /root/.ssh &&
        chmod 700 /root/.ssh &&
        echo "{public_key}" >> /root/.ssh/authorized_keys &&
        chmod 600 /root/.ssh/authorized_keys
    ' '''

    try:
        run_cmd(
            ["ssh", "-o", "StrictHostKeyChecking=no", f"{proxmox_user}@{proxmox_host}", add_cmd],
            capture=True,
            check=True
        )
        log_info("SSH key copied to container")
        return True

    except Exception as e:
        log_warn(f"Failed to copy SSH key: {e}")
        return False

