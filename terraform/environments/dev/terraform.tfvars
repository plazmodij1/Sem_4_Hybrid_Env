## Compute variable values
sg_vars = [
    {
        name = "ovpn_sg"

        ingress_with_cidr_blocks = [
            {
                from_port = 22
                to_port = 22
                protocol = "tcp"
                cidr_blocks = "0.0.0.0/0"
                description = "SSH."
            },
            {
                from_port = 443
                to_port = 443
                protocol = "tcp"
                cidr_blocks = "0.0.0.0/0"
                description = "HTTPS."
            },
            {
                from_port = 943
                to_port = 943
                protocol = "tcp"
                cidr_blocks = "0.0.0.0/0"
                description = "OpenVPN web UI."
            },
            {
                from_port = 1194
                to_port = 1194
                protocol = "udp"
                cidr_blocks = "0.0.0.0/0"
                description = "OpenVPN default port."
            }
        ]
        egress_with_cidr_blocks = [
            {
                from_port = 0
                to_port = 0
                protocol = "-1"
                cidr_blocks = "0.0.0.0/0"
                description = "Allows all egress."
            }
        ]

        description = "Security group attached to the Open VPN resource."
    }
]

ec2_vars = [
    {
        name = "ovpn_ec2"
        instance_type = "t3.micro"
        associate_public_ip_address = true
        create_security_group = false
        description = "EC2 instance hosting the OpenVPN access server."
    }
]

## Network variable values
vpc_vars = [
    {
        name = "test"

        cidr = "10.0.0.0/16"
        azs = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
        public_subnets = ["10.0.1.0/24"]
        private_subnets = ["10.0.2.0/24"]

        enable_nat_gateway = true
        single_nat_gateway = true

        description = "test vpc"
    }
]