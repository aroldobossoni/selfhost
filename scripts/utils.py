"""Utility functions for selfhost automation scripts."""

import subprocess
import sys
import os
import re
from pathlib import Path
from typing import Optional, Tuple

# ANSI Colors
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color


def log_info(msg: str) -> None:
    """Log info message in green."""
    print(f"{Colors.GREEN}[INFO]{Colors.NC} {msg}")


def log_warn(msg: str) -> None:
    """Log warning message in yellow."""
    print(f"{Colors.YELLOW}[WARN]{Colors.NC} {msg}")


def log_error(msg: str) -> None:
    """Log error message in red."""
    print(f"{Colors.RED}[ERROR]{Colors.NC} {msg}")


def log_step(msg: str) -> None:
    """Log step message in blue."""
    print(f"{Colors.BLUE}[STEP]{Colors.NC} {msg}")


def run_cmd(
    cmd: list[str],
    capture: bool = False,
    check: bool = True,
    cwd: Optional[str] = None
) -> subprocess.CompletedProcess:
    """Run a shell command."""
    return subprocess.run(
        cmd,
        capture_output=capture,
        text=True,
        check=check,
        cwd=cwd
    )


def get_project_root() -> Path:
    """Get the project root directory."""
    return Path(__file__).parent.parent


def read_tfvars(key: str) -> Optional[str]:
    """Read a value from terraform.tfvars."""
    tfvars_path = get_project_root() / "terraform.tfvars"
    if not tfvars_path.exists():
        return None

    with open(tfvars_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Match key = "value" or key = value
    pattern = rf'^{key}\s*=\s*"?([^"\n]+)"?'
    match = re.search(pattern, content, re.MULTILINE)
    return match.group(1).strip() if match else None


def write_tfvars(key: str, value: str, tfvars_file: str = "terraform.tfvars") -> None:
    """Write or update a value in terraform.tfvars."""
    tfvars_path = get_project_root() / tfvars_file

    if tfvars_path.exists():
        with open(tfvars_path, 'r', encoding='utf-8') as f:
            content = f.read()
    else:
        content = ""

    # Check if key exists
    pattern = rf'^{key}\s*=.*$'
    if re.search(pattern, content, re.MULTILINE):
        # Update existing
        content = re.sub(pattern, f'{key} = "{value}"', content, flags=re.MULTILINE)
    else:
        # Append new
        content += f'\n{key} = "{value}"\n'

    with open(tfvars_path, 'w', encoding='utf-8') as f:
        f.write(content)


def check_ssh(host: str, timeout: int = 5) -> bool:
    """Check if SSH is available on a host."""
    try:
        result = run_cmd(
            ["ssh", "-o", f"ConnectTimeout={timeout}",
             "-o", "StrictHostKeyChecking=no",
             "-o", "BatchMode=yes",
             f"root@{host}", "exit"],
            capture=True,
            check=False
        )
        return result.returncode == 0
    except Exception:
        return False


def check_docker(host: str) -> bool:
    """Check if Docker is available via SSH."""
    try:
        result = run_cmd(
            ["ssh", "-o", "ConnectTimeout=5",
             "-o", "StrictHostKeyChecking=no",
             f"root@{host}", "docker", "version"],
            capture=True,
            check=False
        )
        return result.returncode == 0
    except Exception:
        return False


def terraform_output(name: str) -> Optional[str]:
    """Get a Terraform output value."""
    try:
        result = run_cmd(
            ["terraform", "output", "-raw", name],
            capture=True,
            check=False,
            cwd=str(get_project_root())
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    return None


def ensure_ssh_key() -> Tuple[str, str]:
    """Ensure SSH key exists and return (private_path, public_key)."""
    ssh_dir = Path.home() / ".ssh"
    ssh_dir.mkdir(mode=0o700, exist_ok=True)

    # Check for existing keys
    for key_type in ["id_ed25519", "id_rsa"]:
        key_path = ssh_dir / key_type
        pub_path = ssh_dir / f"{key_type}.pub"
        if key_path.exists() and pub_path.exists():
            log_info(f"SSH key exists: {key_path}")
            with open(pub_path, 'r', encoding='utf-8') as f:
                return str(key_path), f.read().strip()

    # Generate new key
    key_path = ssh_dir / "id_ed25519"
    log_info("Generating new SSH key...")
    run_cmd([
        "ssh-keygen", "-t", "ed25519",
        "-f", str(key_path),
        "-N", "",
        "-C", f"{os.getenv('USER', 'user')}@selfhost"
    ])

    with open(f"{key_path}.pub", 'r', encoding='utf-8') as f:
        return str(key_path), f.read().strip()

