#!/usr/bin/env python3
"""
Proxmox Token Management Script

Creates or rotates Proxmox API tokens via SSH (pveum command).
Used by Terraform to auto-manage Proxmox tokens.

Usage:
    python scripts/proxmox_token.py <proxmox_host> <ssh_user> <pve_user> <token_name> [--rotate]
"""

import sys
import json
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from scripts.utils import log_info, log_warn, log_error, run_cmd


def list_tokens(proxmox_host: str, ssh_user: str, pve_user: str) -> list:
    """List all tokens for a Proxmox user."""
    try:
        cmd = [
            "ssh", "-o", "StrictHostKeyChecking=no",
            f"{ssh_user}@{proxmox_host}",
            f"pveum user token list {pve_user} --output-format json"
        ]
        result = run_cmd(cmd, capture=True, check=False)
        if result.returncode == 0 and result.stdout.strip():
            return json.loads(result.stdout)
        return []
    except Exception as e:
        log_warn(f"Could not list tokens: {e}")
        return []


def token_exists(proxmox_host: str, ssh_user: str, pve_user: str, token_name: str) -> bool:
    """Check if a token with given name exists."""
    tokens = list_tokens(proxmox_host, ssh_user, pve_user)
    # Token list returns just the token name, not full-tokenid
    return any(token.get("tokenid", "") == token_name for token in tokens)


def remove_token(proxmox_host: str, ssh_user: str, token_id: str) -> bool:
    """Remove a Proxmox token."""
    try:
        # Extract user and token name from token_id (e.g., "root@pam!terraform" -> "root@pam terraform")
        parts = token_id.split("!")
        if len(parts) != 2:
            log_error(f"Invalid token_id format: {token_id}")
            return False
        
        pve_user = parts[0]
        token_name = parts[1]
        
        cmd = [
            "ssh", "-o", "StrictHostKeyChecking=no",
            f"{ssh_user}@{proxmox_host}",
            f"pveum user token delete {pve_user} {token_name}"
        ]
        result = run_cmd(cmd, capture=True, check=False)
        return result.returncode == 0
    except Exception as e:
        log_error(f"Failed to remove token: {e}")
        return False


def create_token(
    proxmox_host: str,
    ssh_user: str,
    pve_user: str,
    token_name: str,
    rotate: bool = False
) -> dict:
    """
    Create a new Proxmox API token.
    
    Returns:
        dict with 'token_id' and 'token_secret' keys
    """
    # If rotating, remove old token first
    if rotate:
        tokens = list_tokens(proxmox_host, ssh_user, pve_user)
        for token in tokens:
            token_name_from_list = token.get("tokenid", "")
            if token_name_from_list == token_name:
                # Build full token_id for removal
                full_token_id = f"{pve_user}!{token_name}"
                log_info(f"Rotating: removing old token: {full_token_id}")
                remove_token(proxmox_host, ssh_user, full_token_id)
    
    # Create new token (pveum will fail if token exists and we're not rotating)
    log_info(f"Creating Proxmox token: {pve_user}!{token_name}")
    try:
        cmd = [
            "ssh", "-o", "StrictHostKeyChecking=no",
            f"{ssh_user}@{proxmox_host}",
            f"pveum user token add {pve_user} {token_name} --output-format json"
        ]
        result = run_cmd(cmd, capture=True, check=True)
        
        # Parse JSON output
        output = json.loads(result.stdout)
        # pveum returns "full-tokenid" not "tokenid"
        token_id = output.get("full-tokenid", "") or output.get("tokenid", "")
        token_secret = output.get("value", "")
        
        if not token_id or not token_secret:
            log_error(f"Failed to parse token output. Got: {result.stdout}")
            raise ValueError("Token creation failed: missing token_id or secret")
        
        log_info(f"Token created successfully: {token_id}")
        return {
            "token_id": token_id,
            "token_secret": token_secret
        }
    except subprocess.CalledProcessError as e:
        # If token already exists and we're not rotating, that's an error
        if "already exists" in (e.stderr or "").lower() or "already exists" in (e.stdout or "").lower():
            if not rotate:
                log_error(f"Token {pve_user}!{token_name} already exists. Use --rotate to replace it.")
            else:
                log_error(f"Failed to rotate token (may have been removed but creation failed)")
            sys.exit(1)
        log_error(f"Failed to create token: {e}")
        if e.stdout:
            log_error(f"Output: {e.stdout}")
        if e.stderr:
            log_error(f"Error: {e.stderr}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        log_error(f"Failed to parse token output: {e}")
        sys.exit(1)
    except Exception as e:
        log_error(f"Unexpected error: {e}")
        sys.exit(1)


def main():
    """Main entry point."""
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)
    
    proxmox_host = sys.argv[1]
    ssh_user = sys.argv[2]
    pve_user = sys.argv[3]
    token_name = sys.argv[4]
    rotate = "--rotate" in sys.argv
    
    # Create or rotate token
    # If token exists and we're not rotating, create_token will fail with clear error
    token_data = create_token(proxmox_host, ssh_user, pve_user, token_name, rotate)
    
    # Output JSON for Terraform
    print(json.dumps(token_data))


if __name__ == "__main__":
    main()

