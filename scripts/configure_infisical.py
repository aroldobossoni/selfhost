#!/usr/bin/env python3
"""
Configure Infisical: Bootstrap and create Machine Identity.
Called by Terraform null_resource to automate initial setup.

Usage:
    python configure_infisical.py <url> <email> <password> <org_name>
"""

import sys
import os
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from scripts.infisical_client import InfisicalClient
from scripts.utils import log_info, log_error


def main():
    """Main entry point for Terraform null_resource."""
    if len(sys.argv) < 5:
        print("Usage: python configure_infisical.py <url> <email> <password> <org_name>")
        sys.exit(1)

    url = sys.argv[1]
    email = sys.argv[2]
    password = sys.argv[3]
    org_name = sys.argv[4]

    credentials_file = Path("infisical_token.auto.tfvars")

    # Check if already configured
    if credentials_file.exists():
        with open(credentials_file, 'r', encoding='utf-8') as f:
            content = f.read()
        if "infisical_client_id" in content and '""' not in content:
            log_info("Credentials file exists. Skipping.")
            sys.exit(0)

    # Parse host and port from URL
    # URL format: http://host:port
    url_parts = url.replace("http://", "").replace("https://", "").split(":")
    host = url_parts[0]
    if len(url_parts) < 2:
        log_error("Port must be specified in URL (e.g., http://host:8080)")
        sys.exit(1)
    port = int(url_parts[1])

    # Create client and bootstrap
    client = InfisicalClient(host, port)

    if not client.wait_for_api():
        log_error("API not ready")
        sys.exit(1)

    if not client.bootstrap(email, password, org_name):
        if client.is_bootstrapped():
            log_error("Instance already bootstrapped but no credentials saved")
            log_error("Manual intervention required")
        sys.exit(1)

    # Create Machine Identity
    creds = client.create_machine_identity("Terraform-Controller")

    if not creds:
        log_error("Failed to create Machine Identity")
        sys.exit(1)

    # Save credentials
    log_info(f"Saving credentials to {credentials_file}...")
    with open(credentials_file, 'w', encoding='utf-8') as f:
        f.write(f'infisical_client_id     = "{creds["client_id"]}"\n')
        f.write(f'infisical_client_secret = "{creds["client_secret"]}"\n')
        if client.admin_token:
            f.write(f'infisical_token         = "{client.admin_token}"\n')

    log_info("Done!")


if __name__ == "__main__":
    main()

