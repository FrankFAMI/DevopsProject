terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}
provider "aws" {
  region = var.region_name
}

resource "aws_vpc" "frankVPC" {
  cidr_block = var.cidr_ip
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.frankVPC.id

  tags = {
    Name = "igw"
  }
}
resource "aws_route_table" "frank_RT" {
  vpc_id = aws_vpc.frankVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public_RT"
  }
}

resource "aws_route_table_association" "SA1" {
  subnet_id      = aws_subnet.frank_public_SN_1.id
  route_table_id = aws_route_table.frank_RT.id
}

resource "aws_route_table_association" "SA2" {
  subnet_id      = aws_subnet.frank_public_SN_2.id
  route_table_id = aws_route_table.frank_RT.id
}

resource "aws_subnet" "frank_public_SN_1" {
  vpc_id                  = aws_vpc.frankVPC.id
  cidr_block              = var.cidr_block_1
  map_public_ip_on_launch = true
  availability_zone       = var.az1

  tags = {
    Name = "frank_public_SN_1"
  }
}

resource "aws_subnet" "frank_public_SN_2" {
  vpc_id                  = aws_vpc.frankVPC.id
  cidr_block              = var.cidr_block_2
  map_public_ip_on_launch = true
  availability_zone       = var.az2

  tags = {
    Name = "frank_public_SN_2"
  }
}

resource "aws_instance" "app_server_1" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.frank_public_SN_1.id
  tags = {
    Name = "app_server_1"
  }
}

resource "aws_instance" "app_server_2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.frank_public_SN_2.id

  tags = {
    Name = "app_server_2"
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.frankVPC.id

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_http" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_ssh" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_mysql" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 3306
  to_port           = 3306
  ip_protocol       = "tcp"
}


resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_launch_configuration" "as_conf" {
  image_id      = var.ami_id
  instance_type = var.instance_type

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_placement_group" "test" {
  name     = "test"
  strategy = "cluster"
}

resource "aws_autoscaling_group" "public_ASG" {
  name                      = "foobar3-terraform-test"
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 4
  force_delete              = true
  #placement_group           = aws_placement_group.test.id
  launch_configuration      = aws_launch_configuration.as_conf.name
  vpc_zone_identifier       = [aws_subnet.frank_public_SN_1.id, aws_subnet.frank_public_SN_2.id]

  tag {
    key                 = "foo"
    value               = "bar"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "lorem"
    value               = "ipsum"
    propagate_at_launch = false
  }
}

resource "aws_lb_target_group" "lbtg" {
  name     = "lbtg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.frankVPC.id
}

resource "aws_lb" "publicalb" {
  name               = "publicalb-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_tls.id]
  subnets            = [aws_subnet.frank_public_SN_1.id, aws_subnet.frank_public_SN_2.id]

  tags = {
    Environment = "lab"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.publicalb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lbtg.arn
  }
}
resource "aws_s3_bucket" "s3_Bucket" {
  bucket = var.s3_Bucket

  tags = {
    Name        = "Frank-s3_bucketTerraform"
    Environment = "Dev"
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_role_policy" "s3_policy" {
  name = "s3_policy"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_db_subnet_group" "db_sg" {
  name       = "db_sg"
  subnet_ids = [aws_subnet.frank_public_SN_1.id, aws_subnet.frank_public_SN_2.id]

  tags = {
    Name = "db_sg"
  }

}

resource "aws_db_instance" "db_mysql" {
  allocated_storage   = 10
  db_name             = "db_mysql"
  engine              = "mysql"
  engine_version      = "5.7"
  instance_class      = "db.t3.micro"
  username            = "admin"
  password            = "MEtroc123"
  skip_final_snapshot = true
}