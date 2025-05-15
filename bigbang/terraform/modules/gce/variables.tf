variable "instances" {
  description = "List of VM instance definitions"
  type = list(object({
    name                 = string
    machine_type         = string
    zone                 = string
    boot_image           = string
    boot_disk_size_gb    = number
    boot_disk_type       = string
    network              = string
    subnetwork           = string
    tags                 = list(string)
    metadata             = map(string)
    service_account_email = string
    scopes               = list(string)
    nat_ip                = optional(string)
    attached_disks         = optional(list(object({
      source       = string
      device_name  = optional(string)
      mode         = optional(string)
      auto_delete  = optional(bool)
    })))
  }))
}