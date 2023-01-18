terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 3.0.0"
      }
    }
}

provider "aws" {
    profile = "ripple_sandbox"
    region = "eu-west-1"
}

# Let's create a VPC
# define resource and give it a name
resource "aws_vpc" "dev-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "dev"
    }
}

# Let's create an Internet Gateway to allow access to the internet from the VPC
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.dev-vpc.id
}

# Let's create a Custom Route table
resource "aws_route_table" "dev-route-table" {
    vpc_id = aws_vpc.dev-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }
    
    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "dev"
    }
}

# Let's create a Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.dev-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "dev-subnet"
  }
}

# Let's associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.dev-route-table.id
}

# Let's create a security group to allow port 22, 80, 443
resource "aws_security_group" "allow_web" {
    name = "allow_web_traffic"
    description = "Allow Web inbound traffic"
    vpc_id = aws_vpc.dev-vpc.id

    ingress {
        description = "HTTPS"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTP"
        from_port = 3001
        to_port = 3001
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "allow_web"
    }
}

# Let's create a Network interface with an ip in the subnet that was created earlier
resource "aws_network_interface" "web-server-nic" {
    subnet_id = aws_subnet.subnet-1.id
    private_ips = ["10.0.1.50"]
    security_groups = [aws_security_group.allow_web.id]
}

# Let's assign an elastic ip to the network interface
resource "aws_eip" "one" {
  vpc = true
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

output "server_public_ip" {
    value = aws_eip.one.public_ip
}

# Let's create an Ubuntu server
resource "aws_instance" "web-server-instance" {
    ami = "ami-0fe0b2cf0e1f25c8a"
    instance_type = "t2.micro"
    availability_zone = "eu-west-1a"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.web-server-nic.id
    }

    tags = {
        Name = "web-server"
    }
}

output "server_private_ip" {
    value = aws_instance.web-server-instance.private_ip
}

output "server_id" {
    value = aws_instance.web-server-instance.id
}