output "sg_id" {
    value = module.security_group.ovpn_sg.security_group_id
    description = "Security group ID."
}