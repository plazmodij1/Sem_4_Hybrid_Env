## VPC outputs
output "vpc_id" {
    value = module.vpc.test.vpc_id
    description = "VPC ID."
}

output "public_subnet_id" {
    value = module.vpc.test.public_subnets[0]
    description = "Public subnet ID"
}