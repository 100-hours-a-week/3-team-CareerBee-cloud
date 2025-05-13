variable "buckets" {
  description = "List of GCS bucket definitions"
  type = list(object({
    name                       = string
    location                   = string
    storage_class              = string
    force_destroy              = bool
    uniform_bucket_level_access = bool
    versioning                 = bool
    lifecycle_age                = optional(number)
    labels                       = optional(map(string))
  }))
}