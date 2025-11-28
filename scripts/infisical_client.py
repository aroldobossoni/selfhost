"""Infisical API client for bootstrap and configuration."""

import time
from typing import Optional
import requests
from requests.exceptions import RequestException

from .utils import log_info, log_error


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

    def get_secret(self, project_id: str, env_slug: str, secret_name: str, access_token: str) -> Optional[str]:
        """Get a secret value from Infisical."""
        try:
            headers = {"Authorization": f"Bearer {access_token}"}
            resp = requests.get(
                f"{self.base_url}/api/v3/secrets/{secret_name}",
                headers=headers,
                params={
                    "workspaceId": project_id,
                    "environment": env_slug
                },
                timeout=10
            )
            if resp.status_code == 200:
                data = resp.json()
                secret = data.get("secret", {})
                return secret.get("secretValue") or secret.get("value")
            return None
        except RequestException:
            return None
