variable "cidr_block_vpc_private" {
    default = "10.0.0.0/16"
}
variable "cidr_block_vpc_public" {
    default = "10.1.0.0/16"
}

# A map of variables to create private subnets
variable "private_subnet_cidrs" {
    type = map(object({
        cidr_block = string
        az = string
        tags = string
    }))
    default = {
    "data-1" = {
        cidr_block = "10.0.1.0/24"
        az = "eu-central-1a"
        tags = "data-1-subnet"
        }
    "data-2" = {
        cidr_block = "10.0.2.0/24"
        az = "eu-central-1b"
        tags = "data-2-subnet"
        }
    "app" = {
        cidr_block = "10.0.3.0/24"
        az = "eu-central-1b"
        tags = "app-subnet"
        }
    }
}

# A map of variables to create public subnets
variable "public_subnet_cidrs" {
    type = map(object({
        cidr_block = string
        az = string
        tags = string
    }))
    default = {
    "dmz-1" = {
        cidr_block = "10.1.1.0/24"
        az = "eu-central-1a"
        tags = "dmz-1-subnet"
        }
    "dmz-2" = {
        cidr_block = "10.1.2.0/24"
        az = "eu-central-1b"
        tags = "dmz-2-subnet"
        }
    }
}