from fastapi import FastAPI, HTTPException, APIRouter, BackgroundTasks
from pydantic import BaseModel
import os
import json
import base64
import requests
import boto3
from datetime import datetime

app = FastAPI(title="Hybrid Cloud Deployment Engine")

# Environment Variables
github_token = os.getenv("GITHUB_TOKEN")
repo_owner = os.getenv("REPO_OWNER")
repo_name = os.getenv("REPO_NAME")
cluster_name = os.getenv("ECS_CLUSTER_NAME", "your-cluster-name")
alb_listener_arn = os.getenv("ALB_LISTENER_ARN")
domain_suffix = os.getenv("DOMAIN_SUFFIX", "sandbox.fontys-proftask.lat")

tagging_client = boto3.client('resourcegroupstaggingapi', region_name='eu-central-1')
ecs_client = boto3.client('ecs', region_name='eu-central-1')
elbv2_client = boto3.client('elbv2')


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

@app.post("/api/deploy") # Ensure this matches your frontend fetch URL!
def trigger_deployment(payload: DeployRequest):
    # Enforce basic RBAC
    if payload.role not in ["user", "admin"]:
        raise HTTPException(status_code=403, detail="Unauthorized role.")

    # --- NEW: Template Registry ---
    # This acts as our database of available containers
    TEMPLATE_REGISTRY = {
        "website-template-1": {
            "image": "nginx:latest",
            "listen_port": "80",
            "target_environment": "aws" # Let's send template 1 to the cloud
        },
        "website-template-2": {
            "image": "httpd:alpine", # Apache
            "listen_port": "8080",
            "target_environment": "aws" # Let's send template 2 to the local Swarm
        }
    }

    # Validate that the requested template actually exists in our registry
    if payload.container_template not in TEMPLATE_REGISTRY:
        raise HTTPException(status_code=400, detail=f"Unknown template: {payload.container_template}")

    # Fetch the specific config for the chosen template
    selected_template = TEMPLATE_REGISTRY[payload.container_template]

    # 1. Calculate the pure DNS route for Traefik / ALB
    routing_url = f"{payload.custom_name}.{domain_suffix}"
    
    # 2. Calculate the actual clickable URL for the user
    clickable_url = f"http://{routing_url}"

    # 3. Compile the deployment configuration using the Template Registry data
    deployment_config = {
        "container_name": payload.custom_name,
        "user_id": payload.user_id,
        "template_id": payload.container_template,
        "routing_url": routing_url,
        "target_environment": selected_template["target_environment"], 
        "injected_parameters": {
            "image": selected_template["image"],
            "listen_port": selected_template["listen_port"], 
        }
    }
    
    config_json_str = json.dumps(deployment_config, indent=2)

    # 4. GitHub REST API - Push Commit to Deployments branch
    file_path = f"deployments/{payload.custom_name}.json"
    url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/contents/{file_path}"
    
    headers = {
        "Authorization": f"Bearer {github_token}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    data = {
        "message": f"GitOps Trigger: Deploy {payload.custom_name} ({payload.container_template})",
        "content": base64.b64encode(config_json_str.encode("utf-8")).decode("utf-8"),
        "branch": "deployments"
    }

    try:
        response = requests.put(url, headers=headers, json=data, timeout=10)
    except requests.exceptions.RequestException as e:
        print(f"Network error reaching GitHub: {e}")
        raise HTTPException(status_code=500, detail="Cannot reach GitHub API. Check AWS NAT/VPC routing.")
    
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
    url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/contents/{file_path}"

    get_url = f"{url}?ref=deployments"

    headers = {
        "Authorization": f"Bearer {github_token}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    container_name = payload.container_name



    # ==========================================================
    # STEP 1: PRE-UPDATE CLEANUP (Wipe old network & compute)
    # ==========================================================
    try:
        if alb_listener_arn:
            target_host = f"{container_name}.{domain_suffix}"
            target_group_arn = None
            rule_arn = None

            print(f"[Update Workflow] Clearing out old networking for: {target_host}")

            # Find the existing ALB rule matching this host header
            rules_response = elbv2_client.describe_rules(ListenerArn=alb_listener_arn)
            for rule in rules_response.get('Rules', []):
                for condition in rule.get('Conditions', []):
                    if condition.get('Field') == 'host-header':
                        if target_host in condition.get('HostHeaderConfig', {}).get('Values', []):
                            rule_arn = rule['RuleArn']
                            for action in rule.get('Actions', []):
                                if action.get('Type') == 'forward':
                                    target_group_arn = action.get('TargetGroupArn')
                                    break

            # Delete old rule
            if rule_arn:
                print(f"[Update Workflow] Deleting old ALB Rule: {rule_arn}")
                elbv2_client.delete_rule(RuleArn=rule_arn)
                import time
                time.sleep(1) # Give AWS a brief window to process dissociation

            # Delete old target group
            if target_group_arn:
                print(f"[Update Workflow] Deleting old Target Group: {target_group_arn}")
                elbv2_client.delete_target_group(TargetGroupArn=target_group_arn)

    except Exception as e:
        print(f"[Update Workflow] Warning during network cleanup: {str(e)}")

    try:
        # Find and terminate the old running ECS task
        print(f"[Update Workflow] Finding active container instance for '{container_name}' to terminate...")
        paginator = ecs_client.get_paginator('list_tasks')
        all_task_arns = []
        for page in paginator.paginate(cluster=cluster_name, desiredStatus='RUNNING'):
            all_task_arns.extend(page.get('taskArns', []))

        if all_task_arns:
            for i in range(0, len(all_task_arns), 100):
                batch = all_task_arns[i:i+100]
                describe_response = ecs_client.describe_tasks(cluster=cluster_name, tasks=batch, include=['TAGS'])
                
                for task in describe_response.get('tasks', []):
                    tags = {tag['key']: tag['value'] for tag in task.get('tags', [])}
                    if tags.get('ContainerName') == container_name:
                        print(f"[Update Workflow] Terminating old ECS Task: {task['taskArn']}")
                        ecs_client.stop_task(
                            cluster=cluster_name,
                            task=task['taskArn'],
                            reason="System recycling instance for configuration update"
                        )
                        break
    except Exception as e:
        print(f"[Update Workflow] Warning during compute termination: {str(e)}")

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

def execute_background_teardown(container_name: str, user_id: str):
    """
    Executes the long-running AWS and GitHub teardown processes.
    This runs in a separate thread so the main FastAPI app can answer health checks.
    """
    # ==========================================
    # PHASE 1: Network Teardown (ALB & Target Group)
    # ==========================================
    try:
        if alb_listener_arn:
            target_host = f"{container_name}.{domain_suffix}"
            target_group_arn = None
            rule_arn = None

            print(f"[Background] Starting network teardown for: {target_host}")

            rules_response = elbv2_client.describe_rules(ListenerArn=alb_listener_arn)
            
            for rule in rules_response.get('Rules', []):
                for condition in rule.get('Conditions', []):
                    if condition.get('Field') == 'host-header':
                        if target_host in condition.get('HostHeaderConfig', {}).get('Values', []):
                            rule_arn = rule['RuleArn']
                            for action in rule.get('Actions', []):
                                if action.get('Type') == 'forward':
                                    target_group_arn = action.get('TargetGroupArn')
                                    break

            if rule_arn:
                print(f"[Background] Deleting ALB Rule: {rule_arn}")
                elbv2_client.delete_rule(RuleArn=rule_arn)

            if target_group_arn:
                print(f"[Background] Deleting Target Group: {target_group_arn}")
                elbv2_client.delete_target_group(TargetGroupArn=target_group_arn)

    except Exception as e:
        print(f"[Background] ALB Teardown Error: {str(e)}")


    # ==========================================
    # PHASE 2: Terminate Compute (AWS ECS)
    # ==========================================
    try:
        paginator = ecs_client.get_paginator('list_tasks')
        all_task_arns = []
        for page in paginator.paginate(cluster=cluster_name, desiredStatus='RUNNING'):
            all_task_arns.extend(page.get('taskArns', []))

        target_task_arn = None

        if all_task_arns:
            for i in range(0, len(all_task_arns), 100):
                batch = all_task_arns[i:i+100]
                describe_response = ecs_client.describe_tasks(cluster=cluster_name, tasks=batch, include=['TAGS'])

                for task in describe_response.get('tasks', []):
                    tags = {tag['key']: tag['value'] for tag in task.get('tags', [])}
                    if tags.get('ContainerName') == container_name and tags.get('Owner') == user_id:
                        target_task_arn = task['taskArn']
                        break
                
                if target_task_arn:
                    break

        if target_task_arn:
            ecs_client.stop_task(
                cluster=cluster_name,
                task=target_task_arn,
                reason="User requested deletion via self-service portal"
            )
            print(f"[Background] Terminating ECS Task: {target_task_arn}")
        else:
            print(f"[Background] Warning: No running task found for '{container_name}'")

    except Exception as e:
        print(f"[Background] ECS Termination Error: {str(e)}")


    # ==========================================
    # PHASE 3: Clean State (GitHub GitOps)
    # ==========================================
    try:
        file_path = f"deployments/{container_name}.json"
        url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/contents/{file_path}"
        
        headers = {
            "Authorization": f"Bearer {github_token}",
            "Accept": "application/vnd.github.v3+json"
        }

        get_url = f"{url}?ref=deployments"
        get_response = requests.get(get_url, headers=headers)
        
        if get_response.status_code == 200:
            file_sha = get_response.json()["sha"]

            delete_data = {
                "message": f"GitOps Teardown: {user_id} deleted {container_name}",
                "sha": file_sha,
                "branch": "deployments"
            }

            delete_response = requests.delete(url, headers=headers, json=delete_data)
            if delete_response.status_code in [200, 201]:
                print(f"[Background] State removed from GitOps pipeline for '{container_name}'.")
            else:
                print(f"[Background] GitHub Delete Failed: {delete_response.text}")
        else:
            print(f"[Background] GitOps state for '{container_name}' not found. Status: {get_response.status_code}")
            
    except Exception as e:
         print(f"[Background] GitHub GitOps Clean Error: {str(e)}")


@app.delete("/api/deployments/{container_name}")
async def delete_container(container_name: str, user_id: str, role: str, background_tasks: BackgroundTasks):
    """
    Tears down the ALB routing, terminates the ECS container, and deletes the GitOps state file.
    Runs asynchronously to prevent ALB health check failures.
    """
    # Enforce RBAC (Basic validation)
    if role not in ["user", "admin"]:
        raise HTTPException(status_code=403, detail="Unauthorized role.")

    # 1. Queue the heavy lifting to run in the background
    background_tasks.add_task(execute_background_teardown, container_name, user_id)

    # 2. Instantly return to the frontend and the ALB
    return {
        "status": "Accepted", 
        "message": f"Teardown process for '{container_name}' initiated in the background."
    }