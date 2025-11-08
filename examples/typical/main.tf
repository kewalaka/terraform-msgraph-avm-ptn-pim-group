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

data "azurerm_client_config" "current" {}

data "azuread_domains" "current" {
  only_initial = false
}

resource "random_string" "group_suffix" {
  length  = 4
  numeric = true
  special = false
  upper   = false
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

resource "random_password" "approver" {
  length  = 28
  special = true
}

resource "random_password" "eligible" {
  length  = 28
  special = true
}

resource "azuread_user" "approver" {
  display_name          = "PAG Module Testing Approver ${random_string.group_suffix.result}"
  user_principal_name   = "pag-approver@${local.tenant_domain}"
  account_enabled       = true
  force_password_change = true
  mail_nickname         = "pagmodtestapprover${random_string.group_suffix.result}"
  password              = random_password.approver.result
}

resource "azuread_user" "operator" {
  display_name          = "PAG Module Testing Operator ${random_string.group_suffix.result}"
  user_principal_name   = "pag-operator${random_string.group_suffix.result}@${local.tenant_domain}"
  account_enabled       = true
  force_password_change = true
  mail_nickname         = "pagmodtestoperator${random_string.group_suffix.result}"
  password              = random_password.eligible.result
}

resource "azuread_group" "operations_team" {
  display_name     = "PAG Module Testing Operations Team ${random_string.group_suffix.result}"
  mail_enabled     = false
  mail_nickname    = "pagmodtestops${random_string.group_suffix.result}"
  owners           = [azuread_user.approver.object_id]
  security_enabled = true
}

resource "azuread_group_member" "operations_team_member" {
  group_object_id  = azuread_group.operations_team.object_id
  member_object_id = azuread_user.operator.object_id
}

module "privileged_group" {
  source = "../.."

  name = "pag-module-testing-${random_string.group_suffix.result}"
  eligible_members = [
    azuread_group.operations_team.object_id,
  ]
  group_description = "Privileged access group used during PIM module testing."
  group_settings = {
    assignable_to_role = true
    owners             = [azuread_user.approver.object_id]
  }
  # PIM configuration
  # NOTE: Setting any pim_* variable automatically onboards the group to PIM.
  # Microsoft creates the PIM policy when you first update policy rules.
  #
  # IMPORTANT: pim_activation_max_duration and pim_eligibility_duration are commented out
  # due to msgraph provider bug: https://github.com/microsoft/terraform-provider-msgraph/issues/75
  # Using non-default values causes persistent drift. Uncomment when provider is fixed.
  # pim_activation_max_duration        = "PT4H"
  # pim_eligibility_duration           = "P90D"
  pim_approver_object_ids = [azuread_user.approver.object_id]
  pim_policy_settings = {
    activation_rules = [
      {
        require_ticket_info = true
        approval_stage = [
          {
            primary_approver = [
              {
                object_id = azuread_user.approver.object_id
              }
            ]
          }
        ]
      }
    ]
  }
  pim_require_approval_on_activation = true
  pim_require_mfa_on_activation      = true
  role_assignments = {
    subscription = {
      scope                      = local.subscription_scope
      role_definition_id_or_name = "Contributor"
    }
  }
  # Resolve role definition names (e.g., "Contributor") to IDs using helper module at subscription scope
  role_definition_lookup_scope = local.subscription_scope
}
