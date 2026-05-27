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

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.private.id

    route {
        cidr_block          = "0.0.0.0/0"
        transit_gateway_id  = aws_ec2_transit_gateway.main.id
    }
    depends_on = [aws_ec2_transit_gateway.main, aws_ec2_transit_gateway_vpc_attachment.private]
}

resource "aws_route_table_association" "public" {
    for_each        = aws_subnet.public
    subnet_id       = each.value.id
    route_table_id  = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
    for_each        = aws_subnet.private
    subnet_id       = each.value.id
    route_table_id  = aws_route_table.private.id 
}