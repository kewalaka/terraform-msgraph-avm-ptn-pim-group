terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    msgraph = {
      source  = "microsoft/msgraph"
      version = "~> 0.2"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.7"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}
