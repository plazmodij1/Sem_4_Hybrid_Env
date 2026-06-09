from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
import json
import base64
import requests
from datetime import datetime

app = FastAPI(title="Hybrid Cloud Deployment Engine")

FRONTEND_URL = os.getenv("FRONTEND_CORS_ORIGIN", "http://localhost:8080")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Change this to the specific AWS frontend URL later for security
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Environment Variables
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = os.getenv("REPO_OWNER")
REPO_NAME = os.getenv("REPO_NAME")
PFSENSE_IP = os.getenv("PFSENSE_IP", "127.0.0.1") # Replace with actual public IP in ECS config
TRAEFIK_PORT = os.getenv("TRAEFIK_PORT", "3055")
TRAEFIK_PORT = os.getenv("TRAEFIK_PORT", "3055")
FRONTEND_URL = os.getenv("FRONTEND_CORS_ORIGIN", "http://localhost:8080")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Change this to the specific AWS frontend URL later for security
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class DeployRequest(BaseModel):
    user_id: str
    role: str
    container_template: str
    custom_name: str

class AdminUpdateRequest(BaseModel):
    user_id: str
    role: str
    container_name: str
    updated_parameters: dict

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
    file_path = f"deployments/{payload.custom_name}.json"
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/contents/{file_path}"
    
    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    data = {
        "message": f"GitOps Trigger: Deploy {payload.custom_name} by {payload.user_id}",
        "content": base64.b64encode(config_json_str.encode("utf-8")).decode("utf-8"),
        "branch": "deployments"
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

@app.put("/api/config/update")
async def update_configuration(payload: AdminUpdateRequest):
    # 1. Enforce RBAC based on the payload (Payload-based trust)
    if payload.role.lower() != "admin":
        raise HTTPException(status_code=403, detail="Admin privileges required.")

    file_path = f"deployments/{payload.container_name}.json"
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/contents/{file_path}"

    get_url = f"{url}?ref=deployments"

    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }

    # 2. Fetch the current configuration from GitHub
    get_response = requests.get(get_url, headers=headers)
    if get_response.status_code != 200:
        raise HTTPException(status_code=404, detail=f"Configuration for '{payload.container_name}' not found.")

    file_data = get_response.json()
    file_sha = file_data["sha"] # Required by GitHub to authorize an update
    
    # Decode existing content
    current_content_str = base64.b64decode(file_data["content"]).decode("utf-8")
    current_config = json.loads(current_content_str)

    # 3. Merge the new parameters into the existing injected_parameters
    if "injected_parameters" not in current_config:
        current_config["injected_parameters"] = {}
        
    current_config["injected_parameters"].update(payload.updated_parameters)
    
    updated_json_str = json.dumps(current_config, indent=2)

    # 4. Push the new commit back to GitHub
    put_data = {
        "message": f"GitOps Admin Trigger: {payload.user_id} updated {payload.container_name}",
        "content": base64.b64encode(updated_json_str.encode("utf-8")).decode("utf-8"),
        "branch": "deployments",
        "sha": file_sha 
    }

    put_response = requests.put(url, headers=headers, json=put_data)

    if put_response.status_code in [200, 201]:
        return {
            "status": "success", 
            "message": f"Configuration for {payload.container_name} updated successfully in Git."
        }
    else:
        raise HTTPException(status_code=put_response.status_code, detail=put_response.text)