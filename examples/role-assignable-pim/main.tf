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

data "azuread_domains" "current" {
  only_initial = false
}

locals {
  tenant_domain = coalesce(
    try([
      for domain in data.azuread_domains.current.domains : domain.domain_name
      if domain.is_default
    ][0], null),
    data.azuread_domains.current.domains[0].domain_name
  )
}

resource "random_string" "group_suffix" {
  length  = 4
  numeric = true
  special = false
  upper   = false
}

resource "random_password" "owner" {
  length  = 30
  special = true
}

resource "azuread_user" "owner" {
  display_name          = "PAG Example Owner ${random_string.group_suffix.result}"
  user_principal_name   = "pag-example-owner${random_string.group_suffix.result}@${local.tenant_domain}"
  account_enabled       = true
  force_password_change = true
  mail_nickname         = "pagexowner${random_string.group_suffix.result}"
  password              = random_password.owner.result
}

module "privileged_group" {
  source = "../.."

  name = "pag-role-assignable-${random_string.group_suffix.result}"
  # Safe defaults: leave PIM policy assignment/rules off on the first apply.
  # After the group exists (and tenant has PIM for Groups enabled), set these
  # to true and apply again to attach policy and patch rules.
  create_pim_policy_assignment_if_missing = false
  # Add one eligible principal so that PIM UI shows an Eligible assignment.
  # Using the created owner for convenience; in real scenarios, target an operator group or user.
  eligible_members  = [azuread_user.owner.object_id]
  group_description = "Fresh role-assignable group with an owner; PIM features toggled off by default."
  group_settings = {
    assignable_to_role = true
    security_enabled   = true
    mail_enabled       = false
    owners             = [azuread_user.owner.object_id]
  }
  manage_pim_policy_rules = true
}
