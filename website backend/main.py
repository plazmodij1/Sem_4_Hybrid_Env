from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
import json
import base64
import requests
from datetime import datetime

app = FastAPI(title="Hybrid Cloud Deployment Engine")

# Environment Variables
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = os.getenv("REPO_OWNER")
REPO_NAME = os.getenv("REPO_NAME")
PFSENSE_IP = os.getenv("PFSENSE_IP", "127.0.0.1") # Replace with actual public IP in ECS config
TRAEFIK_PORT = os.getenv("TRAEFIK_PORT", "15000")

class DeployRequest(BaseModel):
    user_id: str
    role: str
    container_template: str
    custom_name: str

@app.post("/api/deploy")
async def trigger_deployment(payload: DeployRequest):
    # Enforce basic RBAC from the payload (Cognito/Keycloak validation would wrap this)
    if payload.role not in ["user", "admin"]:
        raise HTTPException(status_code=403, detail="Unauthorized role.")

    # 1. Calculate the pure DNS route for Traefik
    routing_url = f"{payload.custom_name}.{PFSENSE_IP}.nip.io"
    
    # 2. Calculate the actual clickable URL for the user
    clickable_url = f"http://{routing_url}:{TRAEFIK_PORT}"

    # 3. Compile the deployment configuration
    deployment_config = {
        "container_name": payload.custom_name,
        "routing_url": routing_url,
        "target_environment": "on-prem", # Or dynamic based on template
        "injected_parameters": {
            "listen_port": "80", 
            "database_name": f"{payload.custom_name}_db",
            "auto_generated_credential_secret_id": f"secret-{payload.custom_name}"
        }
    }
    
    config_json_str = json.dumps(deployment_config, indent=2)

    # 4. GitHub REST API - Push Commit to Main
    file_path = f"deployments/{payload.custom_name}-{int(datetime.timestamp(datetime.now()))}.json"
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/contents/{file_path}"
    
    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    data = {
        "message": f"GitOps Trigger: Deploy {payload.custom_name} by {payload.user_id}",
        "content": base64.b64encode(config_json_str.encode("utf-8")).decode("utf-8"),
        "branch": "main"
    }

    response = requests.put(url, headers=headers, json=data)

    if response.status_code in [200, 201]:
        return {
            "status": "success", 
            "message": "GitOps pipeline triggered successfully.",
            "access_url": clickable_url
        }
    else:
        raise HTTPException(status_code=response.status_code, detail=response.text)