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

data "azurerm_client_config" "current" {}

data "azuread_domains" "current" {
  only_initial = false
}

locals {
  subscription_scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  tenant_domain = coalesce(
    try([
      for domain in data.azuread_domains.current.domains : domain.domain_name
      if domain.is_default
    ][0], null),
    data.azuread_domains.current.domains[0].domain_name
  )
}

resource "random_password" "owner" {
  length  = 28
  special = true
}

resource "azuread_user" "legacy_owner" {
  display_name          = "PAG Module Testing Legacy Owner ${random_string.group_suffix.result}"
  user_principal_name   = "pag-legacy-owner${random_string.group_suffix.result}@${local.tenant_domain}"
  account_enabled       = true
  force_password_change = true
  mail_nickname         = "pagmodtestlegacyowner${random_string.group_suffix.result}"
  password              = random_password.owner.result
}

module "privileged_group" {
  source = "../.."

  name                         = "legacy-pag-module-testing-${random_string.group_suffix.result}"
  role_definition_lookup_scope = local.subscription_scope
  # No eligible members are defined because membership is expected to be permanent in this pattern.
  eligible_members = []
  # Legacy pattern: the group is eligible for RBAC and owners activate on behalf of members.
  eligible_role_assignments = {
    subscription = {
      scope                      = local.subscription_scope
      role_definition_id_or_name = "Contributor"
      justification              = "Group-level activation required for legacy process."
      schedule = {
        expiration = {
          duration_hours = 4
        }
      }
      ticket = {
        system = "ServiceNow"
        number = "CHG0005678"
      }
    }
  }
  group_description = "Legacy pattern: group itself is eligible for subscription RBAC."
  group_settings = {
    assignable_to_role        = true
    owners                    = [azuread_user.legacy_owner.object_id]
    hide_from_outlook_clients = true
  }
  pim_require_mfa_on_activation = true
}
