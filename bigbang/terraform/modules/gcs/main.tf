resource "google_storage_bucket" "buckets" {
  for_each = { for bucket in var.buckets : bucket.name => bucket }

  name     = each.value.name
  location = each.value.location
  storage_class = each.value.storage_class
  force_destroy = each.value.force_destroy

  uniform_bucket_level_access = each.value.uniform_bucket_level_access

  versioning {
    enabled = each.value.versioning
  }

  # lifecycle_rule {
  #   condition {
  #     age = each.value.lifecycle_age
  #   }
  #   action {
  #     type = "Delete"
  #   }
  # }

  # labels = each.value.labels
}