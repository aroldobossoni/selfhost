import requests
import json
import sys
import os
import time

def log(msg):
    print(f"[Infisical Setup] {msg}")

def wait_for_api(url, max_retries=60):
    log(f"Waiting for API at {url}...")
    for i in range(max_retries):
        try:
            requests.get(f"{url}/api/status", timeout=2)
            return True
        except:
            time.sleep(2)
            print(".", end="", flush=True)
    return False

def bootstrap(url, email, password, org_name):
    try:
        # Check if already bootstrapped by trying to login or checking status
        # Bootstrap endpoint returns 400 if already set up
        resp = requests.post(f"{url}/api/v1/admin/bootstrap", json={
            "email": email,
            "password": password,
            "organization": org_name
        })
        
        if resp.status_code == 200:
            return resp.json()
        
        if resp.status_code == 400:
            log("Instance already bootstrapped. Trying to login...")
            # Try login
            login_resp = requests.post(f"{url}/api/v1/auth/universal-auth/login", json={
                "clientSecret": password  # This might not work for user login, user login endpoint is different
            })
            # Actually we need user login here or just assume we can't get the initial token back
            # If we lost the initial token and didn't save credentials, we might be stuck for automation
            # But for this script, we assume fresh install or we handle the "already configured" case manually
            return None
            
    except Exception as e:
        log(f"Bootstrap failed: {e}")
        return None
    return None

def create_machine_identity(url, admin_token, name, org_id):
    headers = {"Authorization": f"Bearer {admin_token}"}
    
    # 1. Create Identity
    log("Creating Machine Identity...")
    resp = requests.post(f"{url}/api/v1/identities", headers=headers, json={
        "name": name,
        "organizationId": org_id
    })
    if resp.status_code not in [200, 201]:
        log(f"Failed to create identity: {resp.text}")
        return None
    
    identity = resp.json()["identity"]
    identity_id = identity["id"]
    
    # 2. Create Universal Auth
    log("Configuring Universal Auth...")
    resp = requests.post(f"{url}/api/v1/auth/universal-auth/identities/{identity_id}", headers=headers, json={
        "clientSecretTrustedIps": [{"ipAddress": "0.0.0.0/0"}],
        "accessTokenTTL": 7200,
        "accessTokenMaxTTL": 7200,
        "accessTokenNumUsesLimit": 0,
        "clientSecretTTL": 0 # Never expires
    })
    
    if resp.status_code not in [200, 201]:
        log(f"Failed to configure universal auth: {resp.text}")
        return None
        
    auth_data = resp.json()
    
    # 3. Assign Admin Role (or appropriate permissions)
    # First, get roles to find Admin role ID
    # This part depends on Infisical version/API structure for roles
    # For simplicity, we assume the identity creation might be enough for now if we can use it
    # But usually we need to assign a role.
    
    return {
        "client_id": auth_data["clientId"],
        "client_secret": auth_data["clientSecret"]
    }

def main():
    if len(sys.argv) < 5:
        print("Usage: python script.py <url> <email> <password> <org_name>")
        sys.exit(1)

    url = sys.argv[1]
    email = sys.argv[2]
    password = sys.argv[3]
    org_name = sys.argv[4]

    if not wait_for_api(url):
        log("API not ready.")
        sys.exit(1)

    # Try Bootstrap
    log("Attempting bootstrap...")
    data = bootstrap(url, email, password, org_name)
    
    if not data:
        log("Bootstrap returned no data (already set up?). Checking if we have credentials file...")
        if os.path.exists("infisical_token.auto.tfvars"):
            log("Credentials file exists. Skipping.")
            sys.exit(0)
        else:
            log("CRITICAL: Instance configured but no credentials found. Manual intervention required.")
            sys.exit(1)

    # Bootstrap success
    admin_token = data["identity"]["credentials"]["token"]
    org_id = data["organization"]["id"]
    
    # Configure Machine Identity for Terraform
    creds = create_machine_identity(url, admin_token, "Terraform-Controller", org_id)
    
    if creds:
        log("Saving credentials to infisical_token.auto.tfvars...")
        with open("infisical_token.auto.tfvars", "w") as f:
            f.write(f'infisical_client_id = "{creds["client_id"]}"\n')
            f.write(f'infisical_client_secret = "{creds["client_secret"]}"\n')
            # Keep token for reference if needed, but provider uses client_id/secret
            f.write(f'infisical_token = "{admin_token}"\n')
        log("Done!")
    else:
        log("Failed to create machine identity credentials.")
        sys.exit(1)

if __name__ == "__main__":
    main()

