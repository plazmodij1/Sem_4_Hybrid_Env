import json
import boto3
import os

ecs_client = boto3.client('ecs')
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    # 1. Extract bucket and key from the EventBridge payload
    detail = event.get('detail', {})
    bucket_name = detail.get('bucket', {}).get('name')
    object_key = detail.get('object', {}).get('key')

    if not bucket_name or not object_key:
        print("Error: Invalid event format")
        return {"status": "Error"}

    s3_url = f"s3://{bucket_name}/{object_key}"
    print(f"Triggering deployment for config: {s3_url}")

    # 2. Peek into the S3 JSON purely to extract metadata for Tagging
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        config_data = json.loads(response['Body'].read().decode('utf-8'))
        
        container_name = config_data.get('container_name', 'unknown-container')
        # If user_id is not yet in your compiled S3 JSON, it will default to 'unknown-user'
        owner_id = config_data.get('user_id', 'unknown-user') 
    except Exception as e:
        print(f"Error reading S3 object for metadata: {e}")
        raise e

    # 3. Fetch Infrastructure IDs from Lambda Environment Variables
    cluster_name = os.environ['ECS_CLUSTER_NAME']
    task_definition = os.environ['ECS_TASK_DEFINITION']
    subnet_id = os.environ['APP_SUBNET_ID']
    security_group_id = os.environ['ECS_SECURITY_GROUP_ID']

    # 4. Execute the Container with strict AWS Resource Tags
    try:
        run_task_response = ecs_client.run_task(
            cluster=cluster_name,
            taskDefinition=task_definition,
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
                        'name': 'apache_container', 
                        'environment': [
                            {
                                "name": "CONFIG_URL",
                                "value": s3_url
                            }
                        ]
                    }
                ]
            },
            # --- NEW TAGGING IMPLEMENTATION ---
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