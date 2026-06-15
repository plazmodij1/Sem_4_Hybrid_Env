import json
import boto3
import os

ecs_client = boto3.client('ecs')
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    # 1. Extract the current status of the task from the EventBridge payload
    last_status = event.get('detail', {}).get('lastStatus')
    desired_status = event.get('detail', {}).get('desiredStatus')
    
    # 2. THE FIX: Ignore the event if the task is stopping or stopped
    if last_status in ['STOPPING', 'STOPPED'] or desired_status == 'STOPPED':
        print(f"Task is shutting down (Status: {last_status}). Skipping network registration.")
        return {
            "statusCode": 200,
            "body": "Ignored shutdown event"
        }
    
    # 3. Extract bucket and key from the EventBridge payload
    detail = event.get('detail', {})
    bucket_name = detail.get('bucket', {}).get('name')
    object_key = detail.get('object', {}).get('key')

    if not bucket_name or not object_key:
        print("Error: Invalid event format")
        return {"status": "Error"}

    s3_url = f"s3://{bucket_name}/{object_key}"
    print(f"Triggering AWS deployment for config: {s3_url}")

    # 4. Extract configuration and metadata from the JSON payload
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        config_data = json.loads(response['Body'].read().decode('utf-8'))
        
        container_name = config_data.get('container_name', 'unknown-container')
        owner_id = config_data.get('user_id', 'unknown-user') 
        template_id = config_data.get('template_id', 'website-template-1')
    except Exception as e:
        print(f"Error reading S3 object for metadata: {e}")
        raise e

    # 5. Fetch Core Infrastructure IDs from Lambda Environment Variables
    cluster_name = os.environ['ECS_CLUSTER_NAME']
    subnet_id = os.environ['APP_SUBNET_ID']
    security_group_id = os.environ['ECS_SECURITY_GROUP_ID']

    # --- AWS TEMPLATE REGISTRY MAPPING ---
    # Map the template IDs directly to their corresponding AWS ECS Task Definitions
    TEMPLATE_REGISTRY = {
        "website-template-1": {
            "task_definition": os.environ.get('ECS_TASK_DEFINITION', 'fallback-task-def'), 
            "container_name": "website-template-1"
        },
        "website-template-2": {
            "task_definition": os.environ.get('ECS_TASK_DEFINITION_2', 'fallback-task-def'),
            "container_name": "website-template-2" 
        }
    }

    # Grab the exact configuration for the chosen template, fallback to template-1 if missing
    target_config = TEMPLATE_REGISTRY.get(template_id, TEMPLATE_REGISTRY["website-template-1"])

    # 6. Execute the Fargate Container Task
    try:
        run_task_response = ecs_client.run_task(
            cluster=cluster_name,
            taskDefinition=target_config["task_definition"],
            launchType='FARGATE',
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': [subnet_id],          
                    'securityGroups': [security_group_id],
                    'assignPublicIp': 'DISABLED'     
                }
            },
            overrides={
                'containerOverrides': [
                    {
                        # Dynamically inject the correct container name for the override path
                        'name': target_config["container_name"], 
                        'environment': [
                            {
                                "name": "CONFIG_URL",
                                "value": s3_url
                            }
                        ]
                    }
                ]
            },
            tags=[
                {
                    'key': 'ContainerName',
                    'value': container_name
                },
                {
                    'key': 'Owner',
                    'value': owner_id
                },
                {
                    'key': 'ManagedBy',
                    'value': 'GitOps-Pipeline'
                }
            ],
            enableECSManagedTags=True
        )
        print(f"Successfully launched and tagged task: {container_name}")
        return {"status": "Success", "task_arn": run_task_response['tasks'][0]['taskArn']}
        
    except Exception as e:
        print(f"Failed to launch ECS task: {str(e)}")
        raise e