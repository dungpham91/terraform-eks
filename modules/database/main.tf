resource "aws_db_subnet_group" "Groups" {
  name       = "db groups"
  subnet_ids = var.private_subnets

  tags = {
    Name = "DB subnet group"  
  }
}

resource "aws_security_group" "data" {
  name        = "data-SG"
  description = "Allow mysql inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SQL DB Access only for port 3306"
    from_port   = 3306
    to_port     = 3306
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "data_server-SG"
  }

}

resource "random_password" "master"{
  length           = 16
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "credentials" {
  name = "${var.secret_id}"
}

resource "aws_secretsmanager_secret_version" "credentials" {
  secret_id     = aws_secretsmanager_secret.credentials.id
  secret_string = random_password.master.result
}

resource "aws_db_instance" "db" {
  identifier             = "${var.identifier}-${var.environment}"
  allocated_storage      = "${var.allocated_storage}"
  storage_type           = "${var.storage_type}"
  engine                 = "${var.engine}"
  engine_version         = "${var.engine_version}"
  instance_class         = "${var.instance_class}"
  db_name                = "${var.database_name}"
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.Groups.name
  vpc_security_group_ids = [aws_security_group.data.id]
  username               = "dbadmin"
  password               = random_password.master.result

  depends_on = [
    aws_db_subnet_group.Groups,
    aws_security_group.data
  ]
}