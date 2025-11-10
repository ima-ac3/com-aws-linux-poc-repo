variable "instancetype" {}
variable "ami" {}
variable "root_volume_size"{}
variable "root_volume_type"{}
variable "disks" {
  type = list(object({
    volume_size  = number
    volume_type  = string
  }))
  default=[]
}