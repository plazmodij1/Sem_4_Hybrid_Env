## Compute module
module "compute" {
    source = "../../modules/compute"

    ## Security group variables
    sg_vars = var.sg_vars
    vpc_id_var = data.aws_vpc.test.id

    ## EC2 variables
    ec2_vars = var.ec2_vars
    ami_var = data.aws_ami.ovpn_ami.id
    subnet_id_var = module.network.public_subnet_id
    security_group_var = [module.compute.sg_id]
}

## Network module
module "network" {
    source = "../../modules/network"

    # VPC variables
    vpc_vars = var.vpc_vars
}