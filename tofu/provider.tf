terraform {
  required_version = ">= 1.10"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.70"
    }
  }

  backend "s3" {
    bucket       = "hc-tf-states"
    key          = "cluster-config/terraform.tfstate"
    region       = "auto"
    use_lockfile = true

    endpoints = {
      s3 = "https://155a8a51958cdf746ff3389421846486.r2.cloudflarestorage.com"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  # The key provider (with the passphrase) is supplied through the TF_ENCRYPTION
  # environment variable, see .envrc.example.
  encryption {
    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }

    state {
      method   = method.aes_gcm.state
      enforced = true
    }

    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}

provider "hcloud" {}
