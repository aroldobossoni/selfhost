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
import time
import json
from pathlib import Path
import requests
from requests.exceptions import RequestException

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from scripts.utils import (
    log_info, log_warn, log_error, log_step,
    run_cmd, get_project_root, read_tfvars, write_tfvars,
    check_ssh, check_docker, terraform_output, ensure_ssh_key,
    cleanup_docker_resources, copy_ssh_key_to_container
)
from scripts.infisical_client import InfisicalClient


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


def rotate_tfstate_backups(project_root: Path, max_backups: int = 3) -> None:
    """Rotate terraform.tfstate backups, keeping only the last N."""
    backup_dir = project_root / "tfstate.backup"
    backup_dir.mkdir(exist_ok=True)

    # Move any .backup files from root to backup dir
    for backup_file in project_root.glob("terraform.tfstate.*.backup"):
        dest = backup_dir / backup_file.name
        shutil.move(str(backup_file), str(dest))
        log_info(f"Moved {backup_file.name} to tfstate.backup/")

    # Get all backups sorted by modification time (oldest first)
    backups = sorted(backup_dir.glob("terraform.tfstate.*.backup"), key=lambda f: f.stat().st_mtime)

    # Remove oldest backups if we have more than max_backups
    while len(backups) > max_backups:
        oldest = backups.pop(0)
        oldest.unlink()
        log_info(f"Removed old backup: {oldest.name}")


class Deployer:
    """Manages the deployment lifecycle."""

    def __init__(self):
        self.project_root = get_project_root()
        self.backup_dir = self.project_root / "tfstate.backup"

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
        targets: list = None,
        auto_approve: bool = True,
        refresh: bool = True
    ) -> bool:
        """Run terraform apply."""
        cmd = ["terraform", "apply"]

        # Support single target or multiple targets
        if targets:
            for t in targets:
                cmd.extend(["-target", t])
        elif target:
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

    def terraform_destroy(self, auto_approve: bool = True, refresh: bool = True) -> bool:
        """Run terraform destroy."""
        cmd = ["terraform", "destroy"]
        if auto_approve:
            cmd.append("-auto-approve")
        if not refresh:
            cmd.append("-refresh=false")

        try:
            run_cmd(cmd, cwd=str(self.project_root), check=True)
            return True
        except Exception as e:
            log_error(f"Terraform destroy failed: {e}")
            return False

    def has_credentials(self) -> bool:
        """Check if Infisical credentials exist (in environment, Terraform outputs, or Infisical)."""
        # Check environment variables first
        if os.getenv("TF_VAR_infisical_client_id") and os.getenv("TF_VAR_infisical_client_secret"):
            return True
        
        # Check Terraform outputs
        client_id = terraform_output("infisical_client_id")
        client_secret = terraform_output("infisical_client_secret")
        if client_id and client_secret:
            return True
        
        # Try to get from Infisical if available
        docker_host = terraform_output("docker_container_ip")
        infisical_port = read_tfvars("infisical_port") or "8080"
        project_id = terraform_output("infisical_project_id")
        admin_token = os.getenv("TF_VAR_infisical_admin_token")
        
        if docker_host and docker_host != "dhcp" and project_id and admin_token:
            try:
                client = InfisicalClient(docker_host, int(infisical_port))
                client_id = client.get_secret(project_id, "production", "INFISICAL_CLIENT_ID", admin_token)
                client_secret = client.get_secret(project_id, "production", "INFISICAL_CLIENT_SECRET", admin_token)
                if client_id and client_secret:
                    log_info("Found credentials in Infisical")
                    # Export for Terraform
                    os.environ["TF_VAR_infisical_client_id"] = client_id
                    os.environ["TF_VAR_infisical_client_secret"] = client_secret
                    return True
            except Exception as e:
                log_warn(f"Could not check Infisical for credentials: {e}")
        
        return False

    def get_enable_infisical(self) -> bool:
        """Get current enable_infisical value from terraform.tfvars."""
        value = read_tfvars("enable_infisical")
        return value == "true" if value else False

    # =========================================================================
    # Deployment Phases
    # =========================================================================

    def phase1(self) -> bool:
        """Phase 1: Deploy LXC container with Docker and get IP from Proxmox API."""
        log_step("Phase 1: Deploying Docker LXC...")

        # Apply LXC module and data source for container IP
        targets = ["module.docker_lxc", "data.http.container_interfaces"]
        if not self.terraform_apply(targets=targets):
            return False

        log_info("Phase 1 complete!")
        log_info("Get container IP: terraform output docker_container_ip")
        return True

    def phase2(self, docker_host: str, docker_ssh_user: str) -> bool:
        """Phase 2: Deploy Infisical containers."""
        log_step("Phase 2: Deploying Infisical containers...")

        # Clean up any orphaned Docker resources first
        cleanup_docker_resources(docker_host, docker_ssh_user)

        # First apply with target
        if not self.terraform_apply(target="module.infisical", refresh=False):
            log_warn("Apply failed, retrying after cleanup...")
            cleanup_docker_resources(docker_host, docker_ssh_user)
            if not self.terraform_apply(target="module.infisical"):
                return False

        # Wait for Infisical API to be ready
        infisical_port = read_tfvars("infisical_port") or "8080"
        infisical_url = f"http://{docker_host}:{infisical_port}"
        log_info(f"Waiting for Infisical API at {infisical_url}...")
        
        client = InfisicalClient(docker_host, int(infisical_port))
        if not client.wait_for_api(max_retries=60):
            log_warn("Infisical API not ready after 2 minutes, continuing anyway...")

        log_info("Phase 2 complete!")
        return True

    def bootstrap(self) -> bool:
        """Phase 3: Bootstrap Infisical and create Machine Identity."""
        log_step("Phase 3: Bootstrap Infisical...")

        # Get Infisical connection info
        docker_host = terraform_output("docker_container_ip")
        if not docker_host or docker_host == "dhcp":
            log_error("Could not get Docker host IP")
            return False
        
        infisical_port = read_tfvars("infisical_port") or "8080"
        infisical_url = f"http://{docker_host}:{infisical_port}"
        
        admin_email = read_tfvars("infisical_admin_email")
        org_name = read_tfvars("infisical_org_name")
        admin_password = terraform_output("infisical_admin_password")
        project_name = read_tfvars("infisical_project_name") or "selfhost"
        
        if not admin_email or not org_name:
            log_error("infisical_admin_email and infisical_org_name must be set")
            return False
        
        if not admin_password:
            log_error("Could not get admin password from Terraform state")
            return False

        # Step 1: Check if bootstrap token exists (environment or Infisical)
        admin_token = os.getenv("TF_VAR_infisical_admin_token")
        org_id = os.getenv("TF_VAR_infisical_org_id")
        
        if not admin_token or not org_id:
            log_info("Running bootstrap script (creates admin user and org)...")
            try:
                result = run_cmd(
                    [
                        sys.executable,
                        str(self.project_root / "scripts" / "bootstrap_infisical.py"),
                        infisical_url,
                        admin_email,
                        admin_password,
                        org_name,
                        "--check-existing"
                    ],
                    capture=True,
                    check=False
                )
                
                if result.returncode == 0:
                    # Parse JSON from stdout (logs go to stderr)
                    json_line = None
                    for line in result.stdout.strip().split('\n'):
                        if line.strip().startswith('{'):
                            json_line = line.strip()
                    
                    if json_line:
                        bootstrap_data = json.loads(json_line)
                        admin_token = bootstrap_data.get("token")
                        org_id = bootstrap_data.get("org_id")
                        
                        if admin_token and org_id:
                            # Export as environment variables for Terraform
                            os.environ["TF_VAR_infisical_admin_token"] = admin_token
                            os.environ["TF_VAR_infisical_org_id"] = org_id
                            log_info("Bootstrap token captured and exported")
                        else:
                            log_error("Bootstrap returned invalid data")
                            return False
                    else:
                        log_error("No JSON found in bootstrap output")
                        log_error(f"Output: {result.stdout}")
                        return False
                else:
                    log_error(f"Bootstrap script failed: {result.stdout}")
                    if result.stderr:
                        log_error(f"Error: {result.stderr}")
                    return False
            except Exception as e:
                log_error(f"Failed to run bootstrap script: {e}")
                return False
        else:
            log_info("Bootstrap token already available in environment")

        # Step 2: Re-init to pick up new variables
        log_info("Re-initializing Terraform with bootstrap token...")
        self.terraform_init(upgrade=True)

        # Step 3: Check if Machine Identity already exists in Infisical
        # Get project ID first (may need to create it)
        project_id = terraform_output("infisical_project_id")
        if not project_id:
            log_info("Project may not exist yet, will be created")
        
        # Step 4: Create Machine Identity using Terraform resources
        log_info("Creating Machine Identity via Terraform...")
        if not self.terraform_apply():
            log_error("Failed to create Machine Identity")
            return False

        # Step 5: Verify credentials were created
        client_id = terraform_output("infisical_client_id")
        client_secret = terraform_output("infisical_client_secret")
        
        if client_id and client_secret:
            log_info("Machine Identity created successfully!")
            # Credentials are automatically stored in Infisical by Terraform resources
            return True

        log_warn("Machine Identity creation may require another apply")
        return True

    def phase4(self, docker_host: str = None) -> bool:
        """Phase 4: Apply Infisical provider resources."""
        log_step("Phase 4: Applying Infisical resources...")

        if not self.has_credentials():
            log_warn("No credentials available, skipping Phase 4")
            return True

        # Ensure Infisical is accessible before applying
        if docker_host:
            infisical_port = read_tfvars("infisical_port") or "8080"
            infisical_url = f"http://{docker_host}:{infisical_port}"
            
            log_info(f"Checking Infisical API at {infisical_url}...")
            client = InfisicalClient(docker_host, int(infisical_port))
            if not client.wait_for_api(max_retries=30):
                log_error("Infisical API not accessible. Ensure containers are running.")
                return False

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

        # Rotate tfstate backups (keep last 3)
        rotate_tfstate_backups(self.project_root, max_backups=3)

        # Check tools
        if not self.check_tools():
            return False

        # Ensure Proxmox token exists (create if missing or invalid)
        proxmox_host = read_tfvars("pm_host")
        proxmox_ssh_user = read_tfvars("proxmox_ssh_user")
        proxmox_pve_user = read_tfvars("proxmox_pve_user") or "root@pam"
        proxmox_token_name = read_tfvars("proxmox_token_name") or "terraform"
        current_token_id = read_tfvars("pm_api_token_id")
        current_token_secret = read_tfvars("pm_api_token_secret")
        pm_api_url = read_tfvars("pm_api_url")
        
        # Always try to ensure token exists before Terraform uses it
        if proxmox_host and proxmox_ssh_user:
            log_step("Ensuring Proxmox token exists...")
            token_needs_creation = False
            token_needs_rotation = False
            
            # Check if token is configured
            if not current_token_id or not current_token_secret:
                log_info("No Proxmox token configured, will create one")
                token_needs_creation = True
            else:
                # Token configured, verify it exists on Proxmox AND validate secret
                log_info(f"Verifying Proxmox token: {current_token_id}")
                try:
                    # Try to list tokens to verify it exists
                    result = run_cmd(
                        [
                            "ssh", "-o", "StrictHostKeyChecking=no",
                            f"{proxmox_ssh_user}@{proxmox_host}",
                            f"pveum user token list {proxmox_pve_user} --output-format json"
                        ],
                        capture=True,
                        check=False
                    )
                    if result.returncode == 0:
                        tokens = json.loads(result.stdout)
                        token_exists = any(t.get("tokenid", "") == proxmox_token_name for t in tokens)
                        if not token_exists:
                            log_warn(f"Token {current_token_id} not found on Proxmox, will create new one")
                            token_needs_creation = True
                        else:
                            # Token exists, but we can't verify secret via SSH
                            # Try a quick API call to validate the secret
                            log_info("Token exists, validating secret via API...")
                            try:
                                resp = requests.get(
                                    f"{pm_api_url}/version",
                                    headers={"Authorization": f"PVEAPIToken={current_token_id}={current_token_secret}"},
                                    timeout=5,
                                    verify=read_tfvars("pm_tls_insecure") != "true"
                                )
                                if resp.status_code == 200:
                                    log_info("Proxmox token validated successfully")
                                else:
                                    log_warn(f"Token validation returned status {resp.status_code}, will rotate")
                                    token_needs_rotation = True
                            except RequestException as e:
                                if hasattr(e, 'response') and e.response is not None and e.response.status_code == 401:
                                    log_warn("Token secret is invalid, will rotate to get new secret")
                                    token_needs_rotation = True
                                else:
                                    log_warn(f"Could not validate token via API: {e}, will rotate to be safe")
                                    token_needs_rotation = True
                    else:
                        log_warn("Could not verify token, will try to create if needed")
                        token_needs_creation = True
                except Exception as e:
                    log_warn(f"Could not verify token: {e}, will try to create if needed")
                    token_needs_creation = True
            
            # Rotate token if secret is invalid
            if token_needs_rotation:
                log_step("Rotating Proxmox token to get valid secret...")
                try:
                    result = run_cmd(
                        [
                            sys.executable,
                            str(self.project_root / "scripts" / "proxmox_token.py"),
                            proxmox_host,
                            proxmox_ssh_user,
                            proxmox_pve_user,
                            proxmox_token_name,
                            "--rotate"
                        ],
                        capture=True,
                        check=False
                    )
                    if result.returncode == 0:
                        try:
                            # Extract JSON line from output (last line with {)
                            json_line = None
                            for line in result.stdout.strip().split('\n'):
                                if line.strip().startswith('{'):
                                    json_line = line.strip()
                            if not json_line:
                                log_error(f"No JSON found in output: {result.stdout}")
                                return False
                            token_data = json.loads(json_line)
                            token_id = token_data.get("token_id", "")
                            token_secret = token_data.get("token_secret", "")
                            if token_id and token_secret:
                                write_tfvars("pm_api_token_id", token_id)
                                write_tfvars("pm_api_token_secret", token_secret)
                                log_info(f"Rotated and saved Proxmox token: {token_id}")
                            else:
                                log_error("Failed to parse rotated token")
                                return False
                        except json.JSONDecodeError as e:
                            log_error(f"Rotated token output is not valid JSON: {e}")
                            log_error(f"Output: {result.stdout}")
                            return False
                    else:
                        log_error(f"Could not rotate token: {result.stdout}")
                        return False
                except Exception as e:
                    log_error(f"Could not rotate Proxmox token: {e}")
                    return False
            
            # Create token if needed
            elif token_needs_creation:
                log_step("Creating Proxmox token...")
                try:
                    result = run_cmd(
                        [
                            sys.executable,
                            str(self.project_root / "scripts" / "proxmox_token.py"),
                            proxmox_host,
                            proxmox_ssh_user,
                            proxmox_pve_user,
                            proxmox_token_name
                        ],
                        capture=True,
                        check=False
                    )
                    if result.returncode == 0:
                        # Parse token from JSON output (extract JSON line)
                        try:
                            json_line = None
                            for line in result.stdout.strip().split('\n'):
                                if line.strip().startswith('{'):
                                    json_line = line.strip()
                            if not json_line:
                                log_error(f"No JSON found in output: {result.stdout}")
                                return False
                            token_data = json.loads(json_line)
                            token_id = token_data.get("token_id", "")
                            token_secret = token_data.get("token_secret", "")
                            if token_id and token_secret:
                                # Update terraform.tfvars
                                write_tfvars("pm_api_token_id", token_id)
                                write_tfvars("pm_api_token_secret", token_secret)
                                log_info(f"Created and saved Proxmox token: {token_id}")
                            else:
                                log_error("Failed to parse token from script output")
                                log_error(f"Output: {result.stdout}")
                                return False
                        except json.JSONDecodeError:
                            log_error(f"Script output is not valid JSON: {result.stdout}")
                            return False
                    else:
                        # Check if token already exists error - try to rotate to get secret
                        if "already exists" in result.stdout.lower() or "already exists" in (result.stderr or "").lower():
                            log_warn("Token already exists but secret not available, rotating to get new secret...")
                            # Try to rotate to get a new secret
                            rotate_result = run_cmd(
                                [
                                    sys.executable,
                                    str(self.project_root / "scripts" / "proxmox_token.py"),
                                    proxmox_host,
                                    proxmox_ssh_user,
                                    proxmox_pve_user,
                                    proxmox_token_name,
                                    "--rotate"
                                ],
                                capture=True,
                                check=False
                            )
                            if rotate_result.returncode == 0:
                                try:
                                    # Extract JSON line from output (logs go to stderr, JSON to stdout)
                                    json_line = None
                                    for line in rotate_result.stdout.strip().split('\n'):
                                        if line.strip().startswith('{'):
                                            json_line = line.strip()
                                    if not json_line:
                                        log_error(f"No JSON found in rotated token output: {rotate_result.stdout}")
                                        return False
                                    token_data = json.loads(json_line)
                                    token_id = token_data.get("token_id", "")
                                    token_secret = token_data.get("token_secret", "")
                                    if token_id and token_secret:
                                        write_tfvars("pm_api_token_id", token_id)
                                        write_tfvars("pm_api_token_secret", token_secret)
                                        log_info(f"Rotated and saved Proxmox token: {token_id}")
                                    else:
                                        log_error("Failed to parse rotated token")
                                        return False
                                except json.JSONDecodeError as e:
                                    log_error(f"Rotated token output is not valid JSON: {e}")
                                    log_error(f"Output: {rotate_result.stdout}")
                                    return False
                            else:
                                log_error("Could not rotate existing token")
                                log_error(f"Output: {rotate_result.stdout}")
                                return False
                        else:
                            log_error("Could not create Proxmox token automatically")
                            log_error(f"Script output: {result.stdout}")
                            if result.stderr:
                                log_error(f"Script error: {result.stderr}")
                            log_error("Please create token manually:")
                            log_error(f"  ssh {proxmox_ssh_user}@{proxmox_host} 'pveum user token add {proxmox_pve_user} {proxmox_token_name}'")
                            log_error("Or set TF_VAR_pm_api_token_* environment variables")
                            return False
                except json.JSONDecodeError as e:
                    log_error(f"Could not parse token JSON: {e}")
                    return False
                except Exception as e:
                    log_error(f"Could not create Proxmox token: {e}")
                    return False

        # Ensure SSH key
        _, public_key = ensure_ssh_key()

        # Run linters
        if not self.run_linters():
            return False

        # Init Terraform
        if not self.terraform_init():
            return False

        # Get SSH users from config
        docker_ssh_user = read_tfvars("docker_ssh_user")
        proxmox_ssh_user = read_tfvars("proxmox_ssh_user")
        
        if not docker_ssh_user:
            log_error("docker_ssh_user not set in terraform.tfvars")
            return False
        if not proxmox_ssh_user:
            log_error("proxmox_ssh_user not set in terraform.tfvars")
            return False

        # Phase 1: Deploy LXC (always run to ensure container exists and get IP)
        if not self.phase1():
            return False

        # Get docker host IP from Terraform output (obtained from Proxmox API)
        docker_host = terraform_output("docker_container_ip")

        if not docker_host or docker_host == "dhcp":
            log_error("Could not obtain container IP from Proxmox API")
            log_info("Check if container is running: ssh root@proxmox 'pct status <vmid>'")
            return False

        log_info(f"Docker host: {docker_host}")

        # Check SSH connectivity (quick check, no long wait)
        log_step(f"Checking SSH connectivity to {docker_host}...")

        if not check_ssh(docker_host, docker_ssh_user):
            # Copy SSH key via Proxmox if needed
            proxmox_host = read_tfvars("pm_host")
            container_id = terraform_output("docker_container_id")
            if container_id:
                container_id = container_id.replace("proxmox/lxc/", "")

            if proxmox_host and container_id:
                log_info("Copying SSH key to container...")
                copy_ssh_key_to_container(proxmox_host, proxmox_ssh_user, container_id, public_key)

            # Brief wait for SSH (max 10 seconds)
            import time
            for i in range(5):
                if check_ssh(docker_host, docker_ssh_user):
                    break
                time.sleep(2)
            else:
                log_error(f"SSH not available at {docker_host}")
                log_info(f"Try manually: ssh {docker_ssh_user}@{docker_host}")
                return False

        log_info("SSH is available!")

        # Check Docker
        if not check_docker(docker_host, docker_ssh_user):
            log_error("Docker not responding via SSH")
            log_info(f"Try: ssh {docker_ssh_user}@{docker_host} 'service docker start'")
            return False

        log_info("Docker is available!")

        # Phase 2-4: Only if Infisical is enabled
        if self.get_enable_infisical():
            # Phase 2: Deploy Infisical containers
            if not self.phase2(docker_host, docker_ssh_user):
                return False

            # Phase 3: Bootstrap
            if not self.has_credentials():
                if not self.bootstrap():
                    log_warn("Bootstrap not completed. Run 'make bootstrap' when ready.")
                    return True

            # Phase 4: Apply Infisical resources
            if not self.phase4(docker_host):
                return False
        else:
            log_info("Infisical disabled (enable_infisical = false), skipping phases 2-4")

        print("\n" + "=" * 50)
        print("  Deployment Complete!")
        print("=" * 50 + "\n")

        # Show outputs
        run_cmd(["terraform", "output"], cwd=str(self.project_root))
        return True

    def destroy(self) -> bool:
        """Destroy all infrastructure in correct order."""
        log_step("Destroying infrastructure...")

        # 1. Remove Infisical provider resources from state (avoid auth errors)
        log_info("Removing Infisical resources from state...")
        infisical_resources = [
            "module.infisical.infisical_secret.proxmox_token_id[0]",
            "module.infisical.infisical_secret.proxmox_token_secret[0]",
            "module.infisical.infisical_secret.client_id[0]",
            "module.infisical.infisical_secret.client_secret[0]",
            "module.infisical.infisical_secret.postgres_password[0]",
            "module.infisical.infisical_secret.encryption_key[0]",
            "module.infisical.infisical_secret.jwt_signing_key[0]",
            "module.infisical.infisical_secret.admin_password[0]",
            "module.infisical.infisical_project_environment.production[0]",
            "module.infisical.infisical_project.main[0]",
            "module.infisical.infisical_identity_universal_auth_client_secret.terraform_controller[0]",
            "module.infisical.infisical_identity_universal_auth.terraform_controller[0]",
            "module.infisical.infisical_identity.terraform_controller[0]",
            "module.infisical.null_resource.bootstrap[0]",
            "module.infisical.null_resource.proxmox_token_cleanup[0]",
        ]
        for resource in infisical_resources:
            run_cmd(
                ["terraform", "state", "rm", resource],
                cwd=str(self.project_root),
                check=False,
            )

        # 2. Cleanup Docker resources via SSH
        docker_host = terraform_output("docker_container_ip")
        docker_ssh_user = read_tfvars("docker_ssh_user")
        if docker_host and docker_host != "dhcp" and docker_ssh_user and check_ssh(docker_host, docker_ssh_user):
            cleanup_docker_resources(docker_host, docker_ssh_user)

        # 3. Remove module.infisical from state
        log_info("Removing Infisical module from state...")
        run_cmd(
            ["terraform", "state", "rm", "module.infisical"],
            cwd=str(self.project_root),
            check=False,
        )

        # 4. Destroy remaining infrastructure (LXC)
        # Use -refresh=false to avoid trying to refresh Infisical resources
        log_info("Destroying remaining infrastructure...")
        if not self.terraform_destroy(refresh=False):
            log_warn("Terraform destroy had errors, continuing cleanup...")


        log_info("Destroy complete!")
        return True


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
        "phase2": lambda: deployer.phase2(
            terraform_output("docker_container_ip") or "",
            read_tfvars("docker_ssh_user") or ""
        ),
    }

    if command not in commands:
        log_error(f"Unknown command: {command}")
        print(__doc__)
        sys.exit(1)

    success = commands[command]()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

