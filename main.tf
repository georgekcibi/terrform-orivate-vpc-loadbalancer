terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 4.0"
      }
    }
}
  
  
  provider "aws" {
    profile = "default"
    region  = "us-east-1"
}
  
  // VPC
  
  resource "aws_vpc" "my_vpc" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
  
    tags = {
      Name = "main-vpc"
    }
}
  
  // Public Subnet
  
  resource "aws_subnet" "public_subnet1" {
    vpc_id                  = aws_vpc.my_vpc.id
    cidr_block              = "10.0.0.0/18"
    map_public_ip_on_launch = true
    availability_zone       = "us-east-1a"
  
    tags = {
      Name = "pubic-subnet1"
    }
}
  
  resource "aws_subnet" "public_subnet2" {
    vpc_id                  = aws_vpc.my_vpc.id
    cidr_block              = "10.0.64.0/18"
    map_public_ip_on_launch = true
    availability_zone       = "us-east-1b"
  
    tags = {
      Name = "pubic-subnet2"
    }
}
  
  // Private Subnet
  
  resource "aws_subnet" "private_subnet1" {
    vpc_id                  = aws_vpc.my_vpc.id
    cidr_block              = "10.0.128.0/18"
    map_public_ip_on_launch = true
    availability_zone       = "us-east-1a"
  
    tags = {
      Name = "private-subnet1"
    }
}
  
  resource "aws_subnet" "private_subnet2" {
    vpc_id                  = aws_vpc.my_vpc.id
    cidr_block              = "10.0.192.0/18"
    map_public_ip_on_launch = true
    availability_zone       = "us-east-1b"
  
    tags = {
      Name = "private-subnet2"
    }
}
  
  // Internet gateway
  
  resource "aws_internet_gateway" "my_gateway" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
      Name = "my-gateway"
    }
}
  
  // Elastic IP
  
  resource "aws_eip" "nat_eip" {
    vpc        = true
    depends_on = [aws_internet_gateway.my_gateway]
    tags = {
      Name = "my-eip"
    }
}
  
  // NAT gateway
  
  resource "aws_nat_gateway" "my_gateway" {
    allocation_id = aws_eip.nat_eip.id
    subnet_id     = aws_subnet.public_subnet1.id
    depends_on    = [aws_internet_gateway.my_gateway]
    tags = {
      Name = "my-nat"
    }
}
  
  // PUBLIC Route
  resource "aws_route_table" "my_public_route_table" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
      Name = "public-route"
    }
  
}
  
  resource "aws_route" "public_route" {
    route_table_id         = aws_route_table.my_public_route_table.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.my_gateway.id
}
  
  // PRIVATE Route 
  resource "aws_route_table" "my_private_route_table" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
      Name = "private-route"
    }
}
  
  resource "aws_route" "private_route" {
    route_table_id         = aws_route_table.my_private_route_table.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id         = aws_nat_gateway.my_gateway.id
}
  
  // Public Route table Assocation
  
  resource "aws_route_table_association" "public_subnet_1" {
    subnet_id      = aws_subnet.public_subnet1.id
    route_table_id = aws_route_table.my_public_route_table.id
}
  
  resource "aws_route_table_association" "public_subnet_2" {
    subnet_id      = aws_subnet.public_subnet2.id
    route_table_id = aws_route_table.my_public_route_table.id
}
  
  
  // Private Route table Assocation
  
  resource "aws_route_table_association" "private_subnet_1" {
    subnet_id      = aws_subnet.private_subnet1.id
    route_table_id = aws_route_table.my_private_route_table.id
}
  
  resource "aws_route_table_association" "private_subnet_2" {
    subnet_id      = aws_subnet.private_subnet2.id
    route_table_id = aws_route_table.my_private_route_table.id
}
  
  // AMI
  data "aws_ami" "amazon-linux-2" {
    most_recent = true
  
    filter {
      name   = "owner-alias"
      values = ["amazon"]
    }
  
    filter {
      name   = "name"
      values = ["amzn2-ami-hvm-*-x86_64-ebs"]
    }
}
  
  // SSH-KEY
  resource "aws_key_pair" "deployer" {
    key_name   = "deployer-key"
    public_key = file("/root/.ssh/id_rsa.pub")
}
  
  resource "aws_security_group" "security" {
    vpc_id = aws_vpc.my_vpc.id
    ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  
    ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  
    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  
    tags = {
      Name = "allow_tls"
    }
}
  
  // EC2 instance
  
  resource "aws_instance" "web" {
    ami                    = data.aws_ami.amazon-linux-2.id
    instance_type          = "t2.micro"
    key_name               = aws_key_pair.deployer.key_name
    vpc_security_group_ids = [aws_security_group.security.id]
    subnet_id              = aws_subnet.private_subnet1.id
    user_data              = file("install_apache.sh")
  
    tags = {
      Name = "Test-Instance"
    }
}

resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "my_lb"
  }

}

resource "aws_lb" "my_lb" {
  name               = "mylb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnet1.id,aws_subnet.public_subnet2.id]

  tags = {
    Environment = "my_lb"
  }

}

resource "aws_lb_target_group" "lb_tg" {
  name        = "albtg"
  port        = 80
  protocol    = "HTTP"
  deregistration_delay  =  30
  target_type = "instance"
  vpc_id      = aws_vpc.my_vpc.id

  health_check {
    healthy_threshold  =  "5"
    interval           =  "30"
    matcher            =  "200"
    timeout            =  "20"
    protocol           =  "HTTP"
    path               =  "/"
    unhealthy_threshold =  "3"
  }

tags = {
  Environment = "my_target-group"
}

}


resource "aws_lb_target_group_attachment" "my_lb_tg_attachment" {
  target_group_arn = aws_lb_target_group.lb_tg.arn
  target_id        = aws_instance.web.id
  port             = 80
}


resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg.arn
  }
}
