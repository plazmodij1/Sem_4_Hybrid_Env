import os
import boto3

ecs_client = boto3.client('ecs')
elbv2_client = boto3.client('elbv2')

# Environment Variables to configure on the Lambda
ALB_LISTENER_ARN = os.environ['ALB_LISTENER_ARN']
VPC_ID = os.environ['VPC_ID']

def lambda_handler(event, context):
    try:
        # 1. Parse details from the EventBridge ECS State Change event
        detail = event['detail']
        cluster_arn = detail['clusterArn']
        task_arn = detail['taskArn']
        
        # Extract tags to find the custom container name and owner
        tags = {t['key']: t['value'] for t in detail.get('tags', [])}
        container_name = tags.get('ContainerName')
        owner = tags.get('Owner')
        
        # If this task wasn't launched by our self-service engine, skip it
        if not container_name or not owner:
            print("Task lacks ContainerName or Owner tags. Skipping registration.")
            return

        print(f"Processing running task {container_name} ({task_arn})...")

        # 2. Extract the Private IP from the task's Network Interface (ENI)
        attachments = detail.get('attachments', [])
        private_ip = None
        for attachment in attachments:
            if attachment['type'] == 'ElasticNetworkInterface':
                for detail_data in attachment['details']:
                    if detail_data['name'] == 'privateIPv4Address':
                        private_ip = detail_data['value']
                        break
        
        if not private_ip:
            print(f"Error: Could not locate private IP for task {task_arn}")
            return

        # 3. Create a unique Target Group for this standalone task (IP target type)
        tg_name = f"tg-{container_name}"
        # Target Group names have a strict 32 character limit
        if len(tg_name) > 32:
            tg_name = tg_name[:32]

        print(f"Creating Target Group: {tg_name} for IP: {private_ip}")
        tg_response = elbv2_client.create_target_group(
            Name=tg_name,
            Protocol='HTTP',
            Port=80,
            VpcId=VPC_ID,
            TargetType='ip',
            HealthCheckProtocol='HTTP',
            HealthCheckPath='/',
            HealthCheckIntervalSeconds=15,
            HealthCheckTimeoutSeconds=5,
            HealthyThresholdCount=2,
            UnhealthyThresholdCount=2
        )
        target_group_arn = tg_response['TargetGroups'][0]['TargetGroupArn']

        # 4. Register the Fargate container IP to the Target Group
        elbv2_client.register_targets(
            TargetGroupArn=target_group_arn,
            Targets=[{'Id': private_ip, 'Port': 80}]
        )

        # 5. Find the next available priority order strictly within the sandbox window (10-99)
        rules_response = elbv2_client.describe_rules(ListenerArn=ALB_LISTENER_ARN)
        
        # Only look at existing dynamic rules below priority 100
        priorities = [
            int(r['Priority']) for r in rules_response['Rules'] 
            if r['Priority'].isdigit() and int(r['Priority']) < 100
        ]

        # Start at priority 10 for containers, or increment if rules already exist
        next_priority = max(priorities) + 1 if priorities else 10
        if next_priority >= 100:
            print("Warning: Dynamic routing window (10-99) is full!")
            return
        
        # 6. Create the ALB Listener Rule matching the custom hostname
        custom_host = f"{container_name}.aws-sandbox.nip.io"
        print(f"Creating ALB rule matching host: {custom_host} with priority {next_priority}")
        
        elbv2_client.create_rule(
            ListenerArn=ALB_LISTENER_ARN,
            Priority=next_priority,
            Conditions=[
                {
                    'Field': 'host-header',
                    'HostHeaderConfig': {'Values': [custom_host]}
                }
            ],
            Actions=[
                {
                    'Type': 'forward',
                    'TargetGroupArn': target_group_arn
                }
            ]
        )
        print("Successfully wired ingress pipeline.")

    except Exception as e:
        print(f"Ingress Lambda Error: {str(e)}")
        raise e