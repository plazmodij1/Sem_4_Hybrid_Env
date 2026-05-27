# Create private subnets using the map from variables.tf
resource "aws_subnet" "private" {
    for_each = var.private_subnet_cidrs

    vpc_id = aws_vpc.private.id
    cidr_block = each.value.cidr_block
    availability_zone = each.value.az
}

# Create public subnets using the map from variables.tf
resource "aws_subnet" "public" {
    for_each = var.public_subnet_cidrs

    vpc_id = aws_vpc.public.id
    cidr_block = each.value.cidr_block
    availability_zone = each.value.az
}
