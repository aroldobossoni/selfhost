#!/usr/bin/env python3
"""
Intelligent Terraform deployment script.
Replaces apply.sh with a modular Python approach.

Usage:
    python scripts/deploy.py apply      # Full intelligent deploy
    python scripts/deploy.py bootstrap  # Bootstrap Infisical only
    python scripts/deploy.py destroy    # Destroy infrastructure
    python scripts/deploy.py phase1     # Deploy LXC only
    python scripts/deploy.py phase2     # Deploy Infisical containers only
    python scripts/deploy.py deps       # Check system dependencies
"""

import sys
import os
import shutil
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from scripts.utils import (
    log_info, log_warn, log_error, log_step,
    run_cmd, get_project_root, read_tfvars, write_tfvars,
    check_ssh, check_docker, terraform_output, ensure_ssh_key
)
from scripts.infisical_client import InfisicalClient
from scripts.docker_client import cleanup_docker_resources, copy_ssh_key_to_container


def check_dependencies(auto_install: bool = True) -> bool:
    """Check and install system dependencies."""
    log_step("Checking system dependencies...")

    import subprocess
    import tempfile

    # APT packages that can be auto-installed
    apt_packages = []

    deps = {
        "terraform": ("terraform", "https://developer.hashicorp.com/terraform/install"),
        "tflint": ("tflint", "https://github.com/terraform-linters/tflint#installation"),
        "python3": ("python3", "python3"),
        "ssh": ("openssh-client", "openssh-client"),
        "curl": ("curl", "curl"),
    }

    missing_manual = []
    for cmd, (pkg, install_hint) in deps.items():
        if shutil.which(cmd):
            log_info(f"✓ {cmd}")
        else:
            if pkg in ["python3", "openssh-client", "curl"]:
                apt_packages.append(pkg)
                log_warn(f"✗ {cmd} (will install)")
            else:
                log_error(f"✗ {cmd} - Install: {install_hint}")
                missing_manual.append(cmd)

    # Check python3-venv
    py_version = f"{sys.version_info.major}.{sys.version_info.minor}"
    venv_pkg = f"python{py_version}-venv"
    venv_ok = False

    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            result = subprocess.run(
                [sys.executable, "-m", "venv", f"{tmpdir}/test_venv"],
                capture_output=True, text=True
            )
            venv_ok = result.returncode == 0
    except Exception:
        pass

    if venv_ok:
        log_info("✓ python3-venv")
    else:
        apt_packages.append(venv_pkg)
        log_warn(f"✗ python3-venv (will install {venv_pkg})")

    # Check pip
    try:
        import pip  # noqa: F401
        log_info("✓ pip")
    except ImportError:
        apt_packages.append("python3-pip")
        log_warn("✗ pip (will install)")

    # Install missing APT packages
    if apt_packages and auto_install:
        log_step(f"Installing: {' '.join(apt_packages)}")
        result = subprocess.run(
            ["sudo", "apt", "install", "-y"] + apt_packages,
            capture_output=False
        )
        if result.returncode != 0:
            log_error("Failed to install packages. Run manually:")
            log_error(f"  sudo apt install -y {' '.join(apt_packages)}")
            return False
        log_info("Packages installed successfully!")

    if missing_manual:
        log_error(f"\n{len(missing_manual)} dependencies require manual installation.")
        return False

    log_info("\nAll dependencies satisfied!")
    return True


class Deployer:
    """Manages the deployment lifecycle."""

    def __init__(self):
        self.project_root = get_project_root()
        self.credentials_file = self.project_root / "infisical_token.auto.tfvars"

    def check_tools(self) -> bool:
        """Check if required tools are installed."""
        log_step("Checking required tools...")

        tools = ["terraform", "tflint"]
        missing = []

        for tool in tools:
            try:
                run_cmd(["which", tool], capture=True, check=True)
            except Exception:
                missing.append(tool)

        if missing:
            log_error(f"Missing required tools: {', '.join(missing)}")
            return False

        log_info("All required tools available")
        return True

    def run_linters(self) -> bool:
        """Run tflint on Terraform files."""
        log_step("Running tflint...")

        try:
            run_cmd(
                ["tflint", "--recursive", "--format", "compact"],
                cwd=str(self.project_root),
                check=True
            )
            log_info("tflint passed!")
            return True
        except Exception as e:
            log_error(f"tflint failed: {e}")
            return False

    def terraform_init(self, upgrade: bool = False) -> bool:
        """Initialize Terraform."""
        log_step("Initializing Terraform...")

        cmd = ["terraform", "init"]
        if upgrade:
            cmd.append("-upgrade")

        try:
            run_cmd(cmd, cwd=str(self.project_root), check=True)
            log_info("Terraform initialized")
            return True
        except Exception as e:
            log_error(f"Terraform init failed: {e}")
            return False

    def terraform_apply(
        self,
        target: str = None,
        auto_approve: bool = True,
        refresh: bool = True
    ) -> bool:
        """Run terraform apply."""
        cmd = ["terraform", "apply"]

        if target:
            cmd.extend(["-target", target])
        if auto_approve:
            cmd.append("-auto-approve")
        if not refresh:
            cmd.append("-refresh=false")

        try:
            run_cmd(cmd, cwd=str(self.project_root), check=True)
            return True
        except Exception as e:
            log_error(f"Terraform apply failed: {e}")
            return False

    def terraform_destroy(self, auto_approve: bool = True) -> bool:
        """Run terraform destroy."""
        cmd = ["terraform", "destroy"]
        if auto_approve:
            cmd.append("-auto-approve")

        try:
            run_cmd(cmd, cwd=str(self.project_root), check=True)
            return True
        except Exception as e:
            log_error(f"Terraform destroy failed: {e}")
            return False

    def has_credentials(self) -> bool:
        """Check if Infisical credentials exist."""
        if not self.credentials_file.exists():
            return False

        with open(self.credentials_file, 'r', encoding='utf-8') as f:
            content = f.read()

        return (
            "infisical_client_id" in content and
            "infisical_client_secret" in content and
            '""' not in content  # Not empty values
        )

    def save_credentials(self, client_id: str, client_secret: str, token: str = "") -> None:
        """Save Infisical credentials to auto.tfvars file."""
        log_info(f"Saving credentials to {self.credentials_file.name}...")

        with open(self.credentials_file, 'w', encoding='utf-8') as f:
            f.write(f'infisical_client_id     = "{client_id}"\n')
            f.write(f'infisical_client_secret = "{client_secret}"\n')
            if token:
                f.write(f'infisical_token         = "{token}"\n')

        log_info("Credentials saved")

    def set_enable_infisical(self, enabled: bool) -> None:
        """Set enable_infisical in terraform.tfvars."""
        value = "true" if enabled else "false"
        write_tfvars("enable_infisical", value)
        log_info(f"enable_infisical set to {value}")

    def get_enable_infisical(self) -> bool:
        """Get current enable_infisical value."""
        value = read_tfvars("enable_infisical")
        return value == "true" if value else False

    # =========================================================================
    # Deployment Phases
    # =========================================================================

    def phase1(self) -> bool:
        """Phase 1: Deploy LXC container with Docker."""
        log_step("Phase 1: Deploying Docker LXC...")

        self.set_enable_infisical(False)

        if not self.terraform_apply(target="module.docker_lxc"):
            return False

        log_info("Phase 1 complete!")
        log_info("Get container IP: terraform output docker_container_ip")
        return True

    def phase2(self, docker_host: str) -> bool:
        """Phase 2: Deploy Infisical containers."""
        log_step("Phase 2: Deploying Infisical containers...")

        # Clean up any orphaned Docker resources first
        cleanup_docker_resources(docker_host)

        self.set_enable_infisical(True)

        # First apply with target
        if not self.terraform_apply(target="module.infisical", refresh=False):
            log_warn("Apply failed, retrying after cleanup...")
            cleanup_docker_resources(docker_host)
            if not self.terraform_apply(target="module.infisical"):
                return False

        log_info("Phase 2 complete!")
        return True

    def bootstrap(self) -> bool:
        """Phase 3: Bootstrap Infisical and create Machine Identity."""
        log_step("Phase 3: Bootstrap Infisical...")

        if self.has_credentials():
            log_info("Credentials already exist, skipping bootstrap")
            return True

        # Get configuration from tfvars
        docker_host = read_tfvars("docker_host_ip")
        port = int(read_tfvars("infisical_port") or "8080")
        email = read_tfvars("infisical_admin_email")
        org_name = read_tfvars("infisical_org_name") or "Selfhost"

        if not docker_host or not email:
            log_error("Missing required variables: docker_host_ip, infisical_admin_email")
            return False

        # Get admin password from Terraform state (generated by random_password)
        # We need to read it from terraform output or state
        # For now, we'll trigger terraform to run the bootstrap via null_resource
        log_info("Running Terraform bootstrap resource...")

        if not self.terraform_apply(target="null_resource.configure_infisical"):
            log_error("Bootstrap via Terraform failed")
            return False

        if self.has_credentials():
            log_info("Bootstrap completed successfully!")
            return True

        log_error("Bootstrap completed but no credentials found")
        return False

    def phase4(self) -> bool:
        """Phase 4: Apply Infisical provider resources."""
        log_step("Phase 4: Applying Infisical resources...")

        if not self.has_credentials():
            log_warn("No credentials available, skipping Phase 4")
            return True

        # Re-init to pick up any provider changes
        self.terraform_init(upgrade=True)

        # Full apply
        if not self.terraform_apply():
            return False

        log_info("Phase 4 complete!")
        return True

    # =========================================================================
    # Main Commands
    # =========================================================================

    def apply(self) -> bool:
        """Intelligent full deployment."""
        print("\n" + "=" * 50)
        print("  Selfhost Intelligent Deploy")
        print("=" * 50 + "\n")

        # Check tools
        if not self.check_tools():
            return False

        # Ensure SSH key
        _, public_key = ensure_ssh_key()

        # Run linters
        if not self.run_linters():
            return False

        # Init Terraform
        if not self.terraform_init():
            return False

        # Get docker host IP
        docker_host = read_tfvars("docker_host_ip")

        if not docker_host:
            log_warn("docker_host_ip not set")
            if not self.phase1():
                return False
            log_warn("Add docker_host_ip to terraform.tfvars and run again")
            return True

        log_info(f"Docker host: {docker_host}")

        # Check SSH connectivity
        log_step(f"Checking SSH connectivity to {docker_host}...")

        if not check_ssh(docker_host):
            log_warn("SSH not available")

            # Try Phase 1
            if not self.phase1():
                return False

            # Try to copy SSH key via Proxmox
            proxmox_host = read_tfvars("pm_host")
            container_id = terraform_output("docker_container_id")
            if container_id:
                container_id = container_id.replace("proxmox/lxc/", "")

            if proxmox_host and container_id:
                copy_ssh_key_to_container(proxmox_host, container_id, public_key)

            # Wait for SSH
            log_info("Waiting for SSH to become available...")
            import time
            for i in range(30):
                if check_ssh(docker_host):
                    log_info("SSH is now available!")
                    break
                time.sleep(2)
            else:
                log_warn("SSH still not available. Run again when ready.")
                return True

        log_info("SSH is available!")

        # Check Docker
        if not check_docker(docker_host):
            log_error("Docker not responding via SSH")
            log_info(f"Try: ssh root@{docker_host} 'service docker start'")
            return False

        log_info("Docker is available!")

        # Phase 2: Deploy Infisical containers
        if not self.phase2(docker_host):
            return False

        # Sync all resources
        log_info("Syncing all resources...")
        self.terraform_apply()

        # Phase 3: Bootstrap
        if not self.has_credentials():
            if not self.bootstrap():
                log_warn("Bootstrap not completed. Run 'make bootstrap' when ready.")
                return True

        # Phase 4: Apply Infisical resources
        if not self.phase4():
            return False

        print("\n" + "=" * 50)
        print("  Deployment Complete!")
        print("=" * 50 + "\n")

        # Show outputs
        run_cmd(["terraform", "output"], cwd=str(self.project_root))
        return True

    def destroy(self) -> bool:
        """Destroy all infrastructure."""
        log_step("Destroying infrastructure...")

        docker_host = read_tfvars("docker_host_ip")
        if docker_host and check_ssh(docker_host):
            cleanup_docker_resources(docker_host)

        return self.terraform_destroy()


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    command = sys.argv[1]

    # Handle deps command before creating Deployer (no project context needed)
    if command == "deps":
        success = check_dependencies()
        sys.exit(0 if success else 1)

    deployer = Deployer()

    # Change to project root
    os.chdir(str(deployer.project_root))

    commands = {
        "apply": deployer.apply,
        "bootstrap": deployer.bootstrap,
        "destroy": deployer.destroy,
        "phase1": deployer.phase1,
        "phase2": lambda: deployer.phase2(read_tfvars("docker_host_ip") or ""),
    }

    if command not in commands:
        log_error(f"Unknown command: {command}")
        print(__doc__)
        sys.exit(1)

    success = commands[command]()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

