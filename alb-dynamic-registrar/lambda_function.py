import os
import boto3

ecs_client = boto3.client('ecs')
elbv2_client = boto3.client('elbv2')

# Environment Variables configured on the Lambda function
ALB_LISTENER_ARN = os.environ['ALB_LISTENER_ARN']
VPC_ID = os.environ['VPC_ID']

def lambda_handler(event, context):
    try:
        # 1. Parse details from the EventBridge ECS State Change event
        detail = event['detail']
        cluster_arn = detail['clusterArn']
        task_arn = detail['taskArn']
        
        # 2. Query ECS directly to fetch the tags (EventBridge strips them!)
        task_info = ecs_client.describe_tasks(
            cluster=cluster_arn,
            tasks=[task_arn],
            include=['TAGS']
        )
        
        # Ensure ECS actually returned task data
        task_list = task_info.get('tasks', [])
        if not task_list:
            print(f"Warning: ECS returned no data for task {task_arn}")
            return
            
        # 3. Extract tags to find the custom container name and owner
        raw_tags = task_list[0].get('tags', [])
        tags = {t['key']: t['value'] for t in raw_tags}
        
        container_name = tags.get('ContainerName')
        owner = tags.get('Owner')
        
        # If this task wasn't launched by our self-service engine, skip it
        if not container_name or not owner:
            print("Task lacks ContainerName or Owner tags. Skipping registration.")
            return

        print(f"Processing running task: {container_name} ({task_arn})")

        # 4. Extract the Private IP directly from the live task configuration
        private_ip = None
        task_details = task_list[0]
        
        # Check containers for network interface configurations
        containers = task_details.get('containers', [])
        if containers:
            network_interfaces = containers[0].get('networkInterfaces', [])
            if network_interfaces:
                private_ip = network_interfaces[0].get('privateIpv4Address')
        
        # Fallback to attachments block if container interfaces aren't populated yet
        if not private_ip:
            attachments = task_details.get('attachments', [])
            for attachment in attachments:
                if attachment.get('type') == 'ElasticNetworkInterface':
                    for detail_data in attachment.get('details', []):
                        if detail_data.get('name') == 'privateIPv4Address':
                            private_ip = detail_data.get('value')
                            break

        if not private_ip:
            print(f"Error: Could not locate private IP for task {task_arn}")
            return
            
        print(f"Found Private IP: {private_ip}")

        # 5. Create a unique Target Group (or use it if it already exists)
        tg_name = f"tg-{container_name}"
        if len(tg_name) > 32:
            tg_name = tg_name[:32]

        print(f"Creating/Locating Target Group: {tg_name} for IP: {private_ip}")
        try:
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
            
        except elbv2_client.exceptions.DuplicateTargetGroupNameException:
            print(f"Target Group {tg_name} already exists. Fetching existing ARN...")
            tg_desc = elbv2_client.describe_target_groups(Names=[tg_name])
            target_group_arn = tg_desc['TargetGroups'][0]['TargetGroupArn']

        # 6. Register the Fargate container IP to the Target Group
        elbv2_client.register_targets(
            TargetGroupArn=target_group_arn,
            Targets=[{
                'Id': private_ip, 
                'Port': 80,
                'AvailabilityZone': 'all'
            }]
        )

        # 7. Find the next available priority order strictly within the 10-99 window
        rules_response = elbv2_client.describe_rules(ListenerArn=ALB_LISTENER_ARN)
        priorities = [
            int(r['Priority']) for r in rules_response['Rules'] 
            if r['Priority'].isdigit() and int(r['Priority']) < 100
        ]
        next_priority = max(priorities) + 1 if priorities else 10

        if next_priority >= 100:
            print("Warning: Dynamic routing window (10-99) is full!")
            return

        # 8. Create the ALB Listener Rule matching the custom hostname
        domain_suffix = os.environ.get('DOMAIN_SUFFIX', 'sandbox.yourdomain.com')
        custom_host = f"{container_name}.{domain_suffix}"
        
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