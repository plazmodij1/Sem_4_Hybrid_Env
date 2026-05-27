## VPC datablocks
data "aws_vpc" "test" {
    id = module.network.vpc_id
    depends_on = [ module.network ]
}

## OpenVPN Access Server AMI datablock
data "aws_ami" "ovpn_ami" {
    most_recent = true
    owners = ["aws-marketplace"]

    filter {
        name   = "product-code"
        values = ["f2ew2wrz425a1jagnifd02u5t"]
    }

    tags = {
        Name = "ovpn_ami"
        Description = "Most recent OpenVPN Access Server ami."
    }
}