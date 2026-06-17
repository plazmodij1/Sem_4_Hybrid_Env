## Relational Database Service (RDS) Resources
resource "aws_db_parameter_group" "postgre_parameters" {
    name = "postgre-replication"
    family = "postgres18"

    parameter {
        name = "rds.logical_replication"
        value = "1"
        apply_method = "pending-reboot"
    }

    description = "Database parameters allowing replication between two Postgre databases."
}

module "rds" {
    source = "terraform-aws-modules/rds/aws"

    identifier = "rds-database"

    engine = "postgres"
    family = "postgres18"
    engine_version = "18"
    major_engine_version = "18"

    instance_class = "t3.medium"
    allocated_storage = 5
    skip_final_snapshot = true

    db_name = "rdsdatabase"
    username = "admindatabase"
    password_wo = "Password1!"

    create_db_subnet_group = true
    subnet_ids = [aws_subnet.private.id[0], aws_subnet.private.id[1]]

    vpc_security_group_ids = [aws_security_group.rds_sg.id]

    parameter_group_name = "postgre-replication"
}