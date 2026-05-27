## VPC variables
variable "vpc_vars" {
    type = list(object({
        name = string

        cidr = string
        azs = list(string)
        public_subnets = list(string)
        private_subnets = list(string)

        enable_nat_gateway = bool
        single_nat_gateway = bool

        description = string
    }))
}