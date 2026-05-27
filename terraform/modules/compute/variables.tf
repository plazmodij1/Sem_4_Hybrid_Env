## Security group variables
variable "sg_vars" {
    type = list(object({
        name = string

        ingress_with_cidr_blocks = list(map(string))
        egress_with_cidr_blocks = list(map(string))

        description = string
    }))
}

variable "vpc_id_var" {
    type = string
}

## EC2 variables
variable "ec2_vars" {
    type = list(object({
        name = string
        instance_type = string
        associate_public_ip_address = bool        
        create_security_group = bool
        description = string
    }))
}

variable "ami_var" {
    type = string
}

variable "subnet_id_var" {
    type = string
}

variable "security_group_var" {
    type = list(string)
}