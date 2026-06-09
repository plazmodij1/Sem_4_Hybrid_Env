resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.public.id
    
    tags = {
        Name = "Internet-Gateway"
    }
}

resource "aws_ec2_transit_gateway" "main" {
    description = "Main gateway between VPCs"

    default_route_table_association = "enable"
    default_route_table_propagation = "enable"

    tags = {
        Name = "tr-gt-main"
    }
}

resource "aws_ec2_transit_gateway_route" "internet_outbound" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_route_table_id = aws_ec2_transit_gateway.main.association_default_route_table_id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.public.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "public" {
    transit_gateway_id  = aws_ec2_transit_gateway.main.id
    vpc_id              = aws_vpc.public.id
    subnet_ids          = [aws_subnet.public["tgw-1"].id, aws_subnet.public["tgw-2"].id]

    tags = {
        Name = "tr-gt-public-attachment"
    }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "private" {
    transit_gateway_id  = aws_ec2_transit_gateway.main.id
    vpc_id              = aws_vpc.private.id
    subnet_ids          = [aws_subnet.private["data-1"].id, aws_subnet.private["data-2"].id]

    tags = {
        Name = "tr-gt-private-attachment"
    }
}

