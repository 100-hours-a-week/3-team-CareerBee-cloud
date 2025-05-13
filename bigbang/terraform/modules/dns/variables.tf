variable "managed_zones" {
  description = "List of managed DNS zones"
  type = list(object({
    name                         = string
    dns_name                     = string
    description                  = string
    visibility                   = string  # "public" or "private"
    labels                       = map(string)
    private_visibility_networks  = optional(list(string), [])
  }))
}

variable "record_sets" {
  description = "List of DNS record sets"
  type = list(object({
    name    = string
    type    = string
    ttl     = number
    zone    = string
    rrdatas = list(string)
  }))
}