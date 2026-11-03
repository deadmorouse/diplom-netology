resource "yandex_iam_service_account" "tf_backend_sa" {
  name = "tf-backend-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "tf_backend_sa_storage" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.tf_backend_sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "tf_backend_key" {
  service_account_id = yandex_iam_service_account.tf_backend_sa.id
}

resource "yandex_storage_bucket" "tf_state_bucket" {
  bucket = var.bucket_name

  access_key = yandex_iam_service_account_static_access_key.tf_backend_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.tf_backend_key.secret_key
}
