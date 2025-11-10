########################################
# Variables
########################################

variable "flavor" {
  description = "Linux flavor to deploy: amazon | amazon2023 | ubuntu | debian | redhat | rocky | almalinux"
  type        = string
}

variable "instancetype" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name (not the .pem file path). Set null to skip."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root volume size (GiB)"
  type        = number
}

variable "root_volume_type" {
  description = "Root volume type (gp3, gp2, io1, io2, etc.)"
  type        = string
}

variable "disks" {
  description = "Extra EBS disks for THIS RUN only"
  type = list(object({
    volume_size = number
    volume_type = string
  }))
  default = []
}

variable "backup_option" {
  description = "Backup behavior tag for the EC2 instance (e.g., daily, weekly, none)"
  type        = string
}