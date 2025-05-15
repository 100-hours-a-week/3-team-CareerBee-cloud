variable "name" {
  description = "VPC network name"
  type        = string
}

variable "routing_mode" {
  description = "Routing mode, default is REGIONAL"
  type        = string
  default     = "REGIONAL"
}

variable "subnetworks" {
  description = "List of subnets"
  type = list(object({
    name                     = string
    region                   = string
    ip_cidr_range            = string
    private_ip_google_access = bool
  }))
}

variable "firewall_rules" {
  description = "List of firewall rules"
  type = list(object({
    name               = string
    protocol           = string
    ports              = list(string)
    source_ranges      = optional(list(string))
    destination_ranges = optional(list(string))
    target_tags        = optional(list(string))
    direction          = optional(string)
    priority           = optional(number)
  }))
  default = []
}