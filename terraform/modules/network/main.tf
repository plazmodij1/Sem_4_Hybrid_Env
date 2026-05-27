## VPC module
module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    for_each = { for inst in var.vpc_vars : inst.name => inst }

    name = each.value.name

    cidr = each.value.cidr
    azs = each.value.azs
    public_subnets = each.value.public_subnets
    private_subnets = each.value.private_subnets

    enable_nat_gateway = each.value.enable_nat_gateway
    single_nat_gateway = each.value.single_nat_gateway

    tags = {
        Description = each.value.description
    }
}