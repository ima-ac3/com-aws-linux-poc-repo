########################################
# main.tf — Incremental "new VM each apply"
########################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

########################################
# AMI mapping by flavor
########################################
locals {
  ami_map = {
    amazon = {
      owners = ["amazon"]
      name   = "amzn2-ami-hvm-*-x86_64-gp2"
    }
    amazon2023 = {
      owners = ["137112412989"]
      name   = "al2023-ami-*-x86_64"
    }
    ubuntu = {
      owners = ["099720109477"]
      name   = "ubuntu/images/hvm-ssd/ubuntu-*22.04-amd64-server-*"
    }
    debian = {
      owners = ["136693071363"]
      name   = "debian-*-x86_64-*"
    }
    redhat = {
      owners = ["309956199498"]
      name   = "RHEL-8.*_HVM-*"
    }
    rocky = {
      owners = ["679593333241"]
      name   = "Rocky-8-EC2-8.*-x86_64-*"
    }
    almalinux = {
      owners = ["764336703387"]
      name   = "AlmaLinux-8.*-x86_64*"
    }
  }
}

########################################
# Latest AMI for the selected flavor
########################################
data "aws_ami" "image" {
  most_recent = true
  owners      = local.ami_map[var.flavor].owners

  filter {
    name   = "name"
    values = [local.ami_map[var.flavor].name]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

########################################
# Unique ID per apply → NEW VM every run
########################################
resource "random_uuid" "vm_id" {}

locals {
  run_id = random_uuid.vm_id.result
}

########################################
# EC2 instance (brand-new each apply)
########################################
resource "aws_instance" "basic_vm" {

  ami           = data.aws_ami.image.id
  instance_type = var.instancetype
  subnet_id     = "subnet-0819602f505704135"
  key_name      = var.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    iops        = (var.root_volume_type == "io1" || var.root_volume_type == "io2") ? 100 : null
  }

  tags = {
    Name          = "vm-${local.run_id}"
    Flavor        = var.flavor
    CreationRunId = local.run_id
    BackupOption  = var.backup_option
  }
}

########################################
# Flatten disks for THIS RUN
########################################
locals {
  flat_disks = [
    for idx, d in var.disks : {
      key        = "${local.run_id}-${idx}"
      vm_key     = local.run_id
      disk_index = idx
      size       = d.volume_size
      vtype      = d.volume_type
    }
  ]
}

########################################
# Extra EBS volumes (only for THIS RUN)
########################################
resource "aws_ebs_volume" "ebs_volumes" {
  for_each = { for d in local.flat_disks : d.key => d }

  availability_zone = aws_instance.basic_vm.availability_zone
  size              = each.value.size
  type              = each.value.vtype
  iops              = (each.value.vtype == "io1" || each.value.vtype == "io2") ? 100 : null

  tags = {
    Name          = "data-${each.key}"
    CreationRunId = each.value.vm_key
  }
}

########################################
# Attach extra volumes to the VM for THIS RUN
########################################
resource "aws_volume_attachment" "attachments" {
  for_each = aws_ebs_volume.ebs_volumes

  # extract the disk index "<uuid>-<idx>"
  device_name = "/dev/sd${substr("fghijklmnop",
                     tonumber(element(split("-", each.key), 1)), 1)}"

  volume_id   = each.value.id
  instance_id = aws_instance.basic_vm.id
}
