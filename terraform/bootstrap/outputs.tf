output "bucket_name" {
  value = yandex_storage_bucket.tf_state_bucket.bucket
}

output "access_key" {
  value     = yandex_iam_service_account_static_access_key.tf_backend_key.access_key
  sensitive = true
}

output "secret_key" {
  value     = yandex_iam_service_account_static_access_key.tf_backend_key.secret_key
  sensitive = true
}