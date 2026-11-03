terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">=1.6.1"
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    #endpoint = "storage.yandexcloud.net"
    bucket = "tf-backend-igor"
    region = "ru-central1"
    key    = "terraform/state.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true

    skip_metadata_api_check    = true
    skip_requesting_account_id = true

    use_path_style = true
  }
}

provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}
