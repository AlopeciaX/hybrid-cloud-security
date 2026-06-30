variable "subid" {
  type      = string
  sensitive = true
}

variable "rgname" {
  type = string
}

variable "infra_rgname" {
  type        = string
  description = "bootstrap으로 생성된 리소스그룹A (Key Vault, Storage Account)"
}

variable "loca1" {
  type = string
}

variable "loca2" {
  type = string
}

variable "size" {
  type = string
}

variable "publisher" {
  type = string
}

variable "offer" {
  type = string
}

variable "sku" {
  type = string
}

variable "ver" {
  type = string
}

variable "admin_user" {
  type = string
}

variable "vmss_instances" {
  type = number
}

variable "vmss_min" {
  type = number
}

variable "vmss_max" {
  type = number
}

# Key Vault
variable "key_vault_name" {
  type        = string
  description = "bootstrap으로 생성된 Key Vault 이름"
}

variable "db_name_secret_name" {
  type    = string
  default = "db-name"
}

variable "db_user_secret_name" {
  type    = string
  default = "db-user"
}

variable "db_password_secret_name" {
  type    = string
  default = "db-password"
}

# ELK Stack
variable "elk_private_ip" {
  type        = string
  description = "ELK VM private IP in vnet1_elk subnet"
  default     = "10.101.5.4"
}

variable "elk_vm_size" {
  type        = string
  description = "ELK VM size"
  default     = "Standard_B2ms"
}

variable "filebeat_version" {
  type        = string
  description = "Filebeat version installed on VMSS instances"
  default     = "8.15.3"
}
