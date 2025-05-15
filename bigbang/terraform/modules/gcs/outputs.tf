output "bucket_names" {
  value = [for b in google_storage_bucket.buckets : b.name]
}

output "bucket_urls" {
  value = [for b in google_storage_bucket.buckets : "gs://${b.name}"]
}