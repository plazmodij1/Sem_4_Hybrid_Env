## Compute variables
variable "sg_vars" {
    type = list(object({
        name = string

        ingress_with_cidr_blocks = list(map(string))
        egress_with_cidr_blocks = list(map(string))

        description = string
    }))
}

variable "ec2_vars" {
    type = list(object({
        name = string
        instance_type = string
        associate_public_ip_address = bool
        create_security_group = bool
        description = string
    }))
}

## Network variables
variable "vpc_vars" {
    type = list(object({
        name = string

        cidr = string
        azs = list(string)
        public_subnets = list(string)
        private_subnets = list(string)

        enable_nat_gateway = bool
        single_nat_gateway = bool

        description = string
    }))
}