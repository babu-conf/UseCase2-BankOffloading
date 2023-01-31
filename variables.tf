variable "region" {
  default = "us-east-1"
}

variable "owner" {
}

variable "confluent_cloud_api_key" {
}

variable "confluent_cloud_api_secret" {
}

variable "date_updated" {

}

variable "subnet_mappings" {
  default = {
    "az2" = {
      "subnet" = 12,
      "az"     = "1a",
    },
    "az4" = {
      "subnet" = 14,
      "az"     = "1b",
    },
    "az6" = {
      "subnet" = 16,
      "az"     = "1c",
    },
  }
}

variable "oracle_admin_username" {
}

variable "oracle_admin_password" {
}

variable "oracle_username" {
}

variable "oracle_password" {
}

variable "mongodb_username" {
}

variable "mongodb_password" {
}