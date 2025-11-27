"""Infisical API client for bootstrap and configuration."""

import time
from typing import Optional
import requests
from requests.exceptions import RequestException

from .utils import log_info, log_warn, log_error


class InfisicalClient:
    """Client for interacting with Infisical API."""

    def __init__(self, host: str, port: int):
        self.base_url = f"http://{host}:{port}"
        self.admin_token: Optional[str] = None
        self.org_id: Optional[str] = None

    def wait_for_api(self, max_retries: int = 60, interval: int = 2) -> bool:
        """Wait for Infisical API to be ready."""
        log_info(f"Waiting for Infisical API at {self.base_url}...")

        for i in range(max_retries):
            try:
                resp = requests.get(
                    f"{self.base_url}/api/status",
                    timeout=5
                )
                if resp.status_code == 200:
                    log_info("Infisical API is ready!")
                    return True
            except RequestException:
                pass

            if i % 10 == 0 and i > 0:
                log_info(f"Still waiting... ({i}/{max_retries})")
            time.sleep(interval)

        log_error("Infisical API not ready after timeout")
        return False

    def bootstrap(
        self,
        email: str,
        password: str,
        org_name: str
    ) -> bool:
        """Bootstrap Infisical instance with admin user and organization."""
        log_info("Attempting Infisical bootstrap...")

        try:
            resp = requests.post(
                f"{self.base_url}/api/v1/admin/bootstrap",
                json={
                    "email": email,
                    "password": password,
                    "organization": org_name
                },
                timeout=30
            )

            if resp.status_code == 200:
                data = resp.json()
                self.admin_token = data["identity"]["credentials"]["token"]
                self.org_id = data["organization"]["id"]
                log_info("Bootstrap successful!")
                return True

            if resp.status_code == 400:
                error_msg = resp.text
                if "already" in error_msg.lower():
                    log_warn("Instance already bootstrapped")
                    return False
                log_error(f"Bootstrap failed: {error_msg}")
                return False

            log_error(f"Bootstrap failed with status {resp.status_code}: {resp.text}")
            return False

        except RequestException as e:
            log_error(f"Bootstrap request failed: {e}")
            return False

    def create_machine_identity(self, name: str = "Terraform-Controller") -> Optional[dict]:
        """Create a Machine Identity with Universal Auth for Terraform."""
        if not self.admin_token or not self.org_id:
            log_error("No admin token available. Run bootstrap first.")
            return None

        headers = {"Authorization": f"Bearer {self.admin_token}"}

        # Step 1: Create Identity
        log_info(f"Creating Machine Identity '{name}'...")
        try:
            resp = requests.post(
                f"{self.base_url}/api/v1/identities",
                headers=headers,
                json={
                    "name": name,
                    "organizationId": self.org_id
                },
                timeout=30
            )

            if resp.status_code not in [200, 201]:
                log_error(f"Failed to create identity: {resp.text}")
                return None

            identity = resp.json()["identity"]
            identity_id = identity["id"]
            log_info(f"Identity created with ID: {identity_id}")

        except RequestException as e:
            log_error(f"Failed to create identity: {e}")
            return None

        # Step 2: Attach Universal Auth to Identity
        log_info("Attaching Universal Auth...")
        try:
            resp = requests.post(
                f"{self.base_url}/api/v1/auth/universal-auth/identities/{identity_id}",
                headers=headers,
                json={
                    "clientSecretTrustedIps": [{"ipAddress": "0.0.0.0/0"}],
                    "accessTokenTTL": 7200,
                    "accessTokenMaxTTL": 7200,
                    "accessTokenNumUsesLimit": 0
                },
                timeout=30
            )

            if resp.status_code not in [200, 201]:
                log_error(f"Failed to attach Universal Auth: {resp.text}")
                return None

            ua_data = resp.json()["identityUniversalAuth"]
            client_id = ua_data["clientId"]
            log_info(f"Universal Auth attached. Client ID: {client_id[:8]}...")

        except RequestException as e:
            log_error(f"Failed to attach Universal Auth: {e}")
            return None

        # Step 3: Create Client Secret
        log_info("Creating Client Secret...")
        try:
            resp = requests.post(
                f"{self.base_url}/api/v1/auth/universal-auth/identities/{identity_id}/client-secrets",
                headers=headers,
                json={
                    "description": "Terraform Controller Secret",
                    "numUsesLimit": 0,  # Unlimited
                    "ttl": 0  # Never expires
                },
                timeout=30
            )

            if resp.status_code not in [200, 201]:
                log_error(f"Failed to create client secret: {resp.text}")
                return None

            secret_data = resp.json()
            client_secret = secret_data["clientSecret"]
            log_info("Client Secret created successfully!")

            return {
                "client_id": client_id,
                "client_secret": client_secret,
                "identity_id": identity_id
            }

        except RequestException as e:
            log_error(f"Failed to create client secret: {e}")
            return None

    def is_bootstrapped(self) -> bool:
        """Check if Infisical is already bootstrapped."""
        try:
            resp = requests.post(
                f"{self.base_url}/api/v1/admin/bootstrap",
                json={"email": "", "password": "", "organization": ""},
                timeout=10
            )
            # 400 with "already" message means bootstrapped
            return resp.status_code == 400 and "already" in resp.text.lower()
        except RequestException:
            return False

