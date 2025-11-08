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

  name              = "pag-module-testing-minimal-${random_string.group_suffix.result}"
  group_description = "Privileged group with default PIM settings."
  # Switch to role-assignable to align with prior azuread behavior
  group_settings = {
    assignable_to_role = true
    security_enabled   = true
    mail_enabled       = false
  }

  # Bypass owner precondition just for this test (don't do this in production)
  allow_role_assignable_group_without_owner = true

  # Keep PIM policy assignment and rule management disabled by default to ensure
  # first apply cannot fail in tenants without PIM for Groups.
  create_pim_policy_assignment_if_missing = false
  manage_pim_policy_rules                 = false
}
