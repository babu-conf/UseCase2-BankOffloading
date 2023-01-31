# Configure the Confluent Provider
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.25.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key 
  cloud_api_secret = var.confluent_cloud_api_secret
}

locals {
  env_name = "${var.owner}-gko-env"
  cluster_name ="${var.owner}-gko-cluster"
  description ="Resource created for 'Dedicated Public Cluster Terraform Pre-work'"

}

# Configure the AWS Provider
provider "aws" {
  region = var.region
  default_tags  {
    tags = local.tf_tags
  }
}


locals {
  tf_tags = {
    "tf_owner"         = "babu",
    "tf_owner_email"   = "babu@confluent.io",
    # "tf_provenance"    = "github.com/justinrlee/field-notes/misc/terraform",
    "tf_last_modified" = "${var.date_updated}",
    "Owner"            = "Babu Turlapati",
  }
}