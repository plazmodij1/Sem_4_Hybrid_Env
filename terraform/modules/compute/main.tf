## Security group module
module "security_group" {
    source = "terraform-aws-modules/security-group/aws"
    for_each = { for inst in var.sg_vars : inst.name => inst }

    name = each.value.name

    vpc_id = var.vpc_id_var
    ingress_with_cidr_blocks = each.value.ingress_with_cidr_blocks
    egress_with_cidr_blocks = each.value.egress_with_cidr_blocks

    tags = {
        Name = each.value.name
        Description = each.value.description
    }
}

## EC2 module
module "ec2" {
    source  = "terraform-aws-modules/ec2-instance/aws"
    for_each = { for inst in var.ec2_vars : inst.name => inst }

    name = each.value.name

    instance_type = each.value.instance_type
    ami = var.ami_var

    subnet_id = var.subnet_id_var
    associate_public_ip_address = each.value.associate_public_ip_address
    
    create_security_group = each.value.create_security_group
    vpc_security_group_ids = var.security_group_var

    tags = {
        Name = each.value.name
        Description = each.value.description
    }
}