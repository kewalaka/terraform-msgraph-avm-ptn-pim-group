terraform {
  required_version = "~> 1.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azuread" {}

provider "azurerm" {
  features {}
}

resource "random_string" "group_suffix" {
  length  = 4
  numeric = true
  special = false
  upper   = false
}

module "privileged_group" {
  source = "../.."

  name = "pag-module-testing-minimal-${random_string.group_suffix.result}"
  # TESTING ONLY: Bypass owner precondition for minimal example
  # NEVER use this setting in production - role-assignable groups require owners
  # See examples/typical or examples/full for production-ready patterns with owners configured
  allow_role_assignable_group_without_owner = true
  group_description                         = "Privileged group with default PIM settings."
  # Switch to role-assignable to align with prior azuread behavior
  group_settings = {
    assignable_to_role = true
    security_enabled   = true
    mail_enabled       = false
  }
}
