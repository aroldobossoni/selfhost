#!/usr/bin/env python3
"""
Minimal Infisical bootstrap script.
Only performs initial admin/org setup that has no Terraform resource equivalent.
After bootstrap, Terraform takes over using infisical_identity resources.

Usage:
    python bootstrap_infisical.py <url> <email> <password> <org_name> [--check-existing]

Outputs:
    JSON to stdout: {"token": "...", "org_id": "..."}
    Logs to stderr for human readability
"""

import sys
import json
from pathlib import Path
import requests
from requests.exceptions import RequestException

sys.path.insert(0, str(Path(__file__).parent.parent))

from scripts.infisical_client import InfisicalClient


def log_info(msg: str) -> None:
    print(f"[INFO] {msg}", file=sys.stderr)


def log_error(msg: str) -> None:
    print(f"[ERROR] {msg}", file=sys.stderr)


def check_existing_bootstrap(base_url: str, email: str, password: str) -> dict | None:
    """Check if Infisical is already bootstrapped and try to get token."""
    log_info("Checking if Infisical is already bootstrapped...")
    
    try:
        # Try to login with provided credentials
        resp = requests.post(
            f"{base_url}/api/v1/auth/login",
            json={
                "email": email,
                "password": password
            },
            timeout=10
        )
        
        if resp.status_code == 200:
            data = resp.json()
            token = data.get("token") or data.get("accessToken")
            if token:
                # Get organization info
                headers = {"Authorization": f"Bearer {token}"}
                org_resp = requests.get(
                    f"{base_url}/api/v1/organization",
                    headers=headers,
                    timeout=10
                )
                if org_resp.status_code == 200:
                    org_data = org_resp.json()
                    org_id = org_data.get("organization", {}).get("_id") or org_data.get("organization", {}).get("id")
                    if org_id:
                        log_info("Found existing bootstrap, using existing credentials")
                        return {
                            "token": token,
                            "org_id": org_id
                        }
    except RequestException:
        pass
    
    return None


def bootstrap(base_url: str, email: str, password: str, org_name: str) -> dict | None:
    """Bootstrap Infisical with admin user and organization."""
    log_info("Attempting Infisical bootstrap...")

    try:
        resp = requests.post(
            f"{base_url}/api/v1/admin/bootstrap",
            json={
                "email": email,
                "password": password,
                "organization": org_name
            },
            timeout=30
        )

        if resp.status_code == 200:
            data = resp.json()
            log_info("Bootstrap successful!")
            return {
                "token": data["identity"]["credentials"]["token"],
                "org_id": data["organization"]["id"]
            }

        if resp.status_code == 400 and "already" in resp.text.lower():
            log_info("Instance already bootstrapped, checking for existing credentials...")
            # Try to get token via login
            return check_existing_bootstrap(base_url, email, password)

        log_error(f"Bootstrap failed: {resp.status_code} - {resp.text}")
        return None

    except RequestException as e:
        log_error(f"Bootstrap request failed: {e}")
        return None


def main():
    if len(sys.argv) < 5:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    email = sys.argv[2]
    password = sys.argv[3]
    org_name = sys.argv[4]
    check_existing = "--check-existing" in sys.argv

    # Parse host and port from URL
    url_parts = url.replace("http://", "").replace("https://", "").split(":")
    host = url_parts[0]
    port = int(url_parts[1]) if len(url_parts) > 1 else 8080
    
    # Wait for API using InfisicalClient
    client = InfisicalClient(host, port)
    if not client.wait_for_api():
        sys.exit(1)

    # Check for existing bootstrap first if requested
    if check_existing:
        result = check_existing_bootstrap(url, email, password)
        if result:
            print(json.dumps(result))
            sys.exit(0)

    # Bootstrap
    result = bootstrap(url, email, password, org_name)

    if result:
        # Output JSON to stdout (for Terraform/deploy.py to capture)
        print(json.dumps(result))
        log_info("Bootstrap completed successfully")
    else:
        log_error("Bootstrap failed and no existing credentials found")
        log_error("Manual intervention required or destroy and recreate Infisical")
        sys.exit(1)


if __name__ == "__main__":
    main()

