##########################################
# Standalone PostgreSQL RDS Instance     #
# NOT part of an Aurora Cluster          #
##########################################

resource "aws_db_instance" "postgres_rds" {
  # Unique identifier for this RDS instance
  identifier = "plural-instance"

  # Use standard PostgreSQL engine (NOT Aurora)
  engine = "postgres"

  # Specific PostgreSQL engine version — must match AWS-supported versions
  engine_version = "15.12"

  # Smallest burstable instance — great for test/dev
  instance_class = "db.t4g.micro"

  # Amount of disk space in GB — 20 is the PostgreSQL minimum
  allocated_storage = 20

  # Use general-purpose SSD (gp3 is newer and cheaper than gp2)
  storage_type = "gp3"

  # Name of the default DB to create at launch
  db_name = "postgres"

  # Master user credentials — should come from a random password generator
  username = "postgres"
  password = random_password.postgres_password.result

  # Subnet group must include at least 2 subnets in different AZs for Multi-AZ
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name

  # Associate a security group to control inbound/outbound access
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Enable Multi-AZ deployment — AWS creates a standby in a different AZ
  multi_az = true

  # Allow public access (dangerous for prod, OK for dev/test with strict rules)
  publicly_accessible = true

  # Skip creating a final snapshot on deletion (safer to set false in production)
  skip_final_snapshot = true

  # Enable automatic backups for 5 days
  backup_retention_period = 5

  # Define when backups should happen (UTC timezone)
  backup_window = "07:00-09:00"

  # Enable Performance Insights for deeper monitoring
  performance_insights_enabled = true

  tags = {
    Name = "Plural Postgres RDS Instance"
  }
}

##################################################
# RDS Subnet Group — Controls where RDS ENIs go  #
##################################################
resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "rds-subnet-group"

  # List of subnet IDs for the DB — must span multiple AZs for Multi-AZ
  subnet_ids = [
    aws_subnet.pub-subnet-1.id, 
    aws_subnet.pub-subnet-2.id  
  ]

  tags = {
    Name = "RDS Subnet Group"
  }
}

