resource "aws_route_table" "public" {
    vpc_id = aws_vpc.public.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    route {
        cidr_block          = var.cidr_block_vpc_private
        transit_gateway_id  = aws_ec2_transit_gateway.main.id
    }
    depends_on = [aws_ec2_transit_gateway.main, aws_ec2_transit_gateway_vpc_attachment.public]
}

resource "aws_route_table" "tgw_arrival" {
    vpc_id = aws_vpc.public.id
    route {
        cidr_block           = "0.0.0.0/0"
        network_interface_id = module.fck_nat.eni_id
    }
    route {
        cidr_block          = var.cidr_block_vpc_private
        transit_gateway_id  = aws_ec2_transit_gateway.main.id
    }
    depends_on = [aws_ec2_transit_gateway.main, aws_ec2_transit_gateway_vpc_attachment.public]
}

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.private.id

    route {
        cidr_block          = "0.0.0.0/0"
        transit_gateway_id  = aws_ec2_transit_gateway.main.id
    }

    route {
        cidr_block         = "10.1.0.0/16"
        transit_gateway_id = aws_ec2_transit_gateway.main.id
    }
    depends_on = [aws_ec2_transit_gateway.main, aws_ec2_transit_gateway_vpc_attachment.private]
}

resource "aws_route_table_association" "public" {
    for_each        = { for k, v in aws_subnet.public : k => v if length(regexall("^tgw", k)) == 0 }
    subnet_id       = each.value.id
    route_table_id  = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
    for_each        = aws_subnet.private
    subnet_id       = each.value.id
    route_table_id  = aws_route_table.private.id 
}

resource "aws_route_table_association" "tgw_arrival" {
    for_each        = { for k, v in aws_subnet.public : k => v if length(regexall("^tgw", k)) > 0 }
    subnet_id       = each.value.id
    route_table_id  = aws_route_table.tgw_arrival.id
}

# FckNAT module for the backend ecs instance\
module "fck_nat" {
    name    = "fucknat-instance"
    source  = "RaJiska/fck-nat/aws"
    version = "1.6.0"

    vpc_id                          = aws_vpc.public.id
    subnet_id                       = aws_subnet.public["nat-dmz"].id
    instance_type                   = "t3.micro"

    additional_security_group_ids = [aws_security_group.fck_nat_custom_ingress.id]
    }

