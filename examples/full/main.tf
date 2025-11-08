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

resource "random_string" "group_suffix" {
  length  = 4
  numeric = true
  special = false
  upper   = false
}

resource "random_password" "admin_primary" {
  length  = 32
  special = true
}

resource "random_password" "admin_secondary" {
  length  = 32
  special = true
}

resource "random_password" "duty_manager" {
  length  = 28
  special = true
}

resource "azuread_user" "admin_primary" {
  display_name          = "PAG Module Testing Admin Primary ${random_string.group_suffix.result}"
  user_principal_name   = "pag-admin-primary${random_string.group_suffix.result}@${local.tenant_domain}"
  account_enabled       = true
  force_password_change = true
  mail_nickname         = "pagmodtestadminprimary${random_string.group_suffix.result}"
  password              = random_password.admin_primary.result
}

resource "azuread_user" "admin_secondary" {
  display_name          = "PAG Module Testing Admin Secondary ${random_string.group_suffix.result}"
  user_principal_name   = "pag-admin-secondary${random_string.group_suffix.result}@${local.tenant_domain}"
  account_enabled       = true
  force_password_change = true
  mail_nickname         = "pagmodtestadminsecondary${random_string.group_suffix.result}"
  password              = random_password.admin_secondary.result
}

resource "azuread_user" "duty_manager" {
  display_name          = "PAG Module Testing Duty Manager ${random_string.group_suffix.result}"
  user_principal_name   = "pag-duty-manager${random_string.group_suffix.result}@${local.tenant_domain}"
  account_enabled       = true
  force_password_change = true
  mail_nickname         = "pagmodtestdutymgr${random_string.group_suffix.result}"
  password              = random_password.duty_manager.result
}

module "privileged_group" {
  source = "../.."

  name = "pag-module-testing-admins-${random_string.group_suffix.result}"
  eligible_member_schedules = {
    front_line = {
      justification = "Operations on-call rotation."
      principal_id  = azuread_user.admin_primary.object_id
      duration      = "P180D"
    }
    back_up = {
      justification   = "Secondary admin supports critical incidents."
      principal_id    = azuread_user.admin_secondary.object_id
      start_date_time = "2024-01-01T00:00:00Z"
      duration        = "P120D"
    }
  }
  group_description = "Operations admin group that requests elevated permissions through PIM."
  group_settings = {
    assignable_to_role = true
    security_enabled   = true
    mail_enabled       = false
    owners = [
      azuread_user.admin_primary.object_id,
      azuread_user.admin_secondary.object_id,
      azuread_user.duty_manager.object_id
    ]
  }
  pim_activation_max_duration = "PT2H"
  pim_approver_object_ids = [
    azuread_user.duty_manager.object_id
  ]
  pim_approver_object_type = "singleUser"
  pim_eligibility_duration = "P180D"
  pim_policy_settings = {
    eligible_assignment_rules = [
      {
        expiration_required = true
        expire_after        = "P180D"
      }
    ]
    activation_rules = [
      {
        require_multifactor_authentication = true
        require_ticket_info                = true
        approval_stage = [
          {
            primary_approver = [
              {
                object_id = azuread_user.admin_primary.object_id
                type      = "singleUser"
              }
            ]
          }
        ]
      }
    ]
    notification_rules = [
      {
        eligible_assignments = [
          {
            admin_notifications = [
              {
                default_recipients    = true
                notification_level    = "Critical"
                additional_recipients = ["null@datacom.com"]
              }
            ]
            assignee_notifications = [
              {
                default_recipients = true
                notification_level = "All"
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
      role_definition_id_or_name = "Owner"
    }
  }
  role_definition_lookup_scope = local.subscription_scope
}
