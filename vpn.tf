module "ovpn_ec2" {
    source  = "terraform-aws-modules/ec2-instance/aws"

    name = "ovpn_ec2"

    instance_type = "t3.medium"
    ami = data.aws_ami.ovpn_ami.id

    subnet_id = aws_subnet.public["data-1"].id
    associate_public_ip_address = true

    create_security_group = false
    vpc_security_group_ids = [aws_security_group.ovpn_sg.id]
}