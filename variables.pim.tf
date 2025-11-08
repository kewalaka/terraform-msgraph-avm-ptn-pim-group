# PIM variables
# NOTE: Groups are automatically onboarded to PIM when you:
# 1. Create an eligibility or assignment schedule request (via eligible_member_schedules), OR
# 2. Update PIM policy rules (via pim_* variables)
# Reference: https://learn.microsoft.com/en-us/graph/api/resources/privilegedidentitymanagement-for-groups-api-overview#onboarding-groups-to-pim-for-groups

variable "eligible_member_schedules" {
  type = map(object({
    principal_id         = string
    group_id             = optional(string)
    assignment_type      = optional(string)
    duration             = optional(string)
    expiration_date      = optional(string)
    start_date           = optional(string)
    justification        = optional(string)
    permanent_assignment = optional(bool)
    ticket_number        = optional(string)
    ticket_system        = optional(string)
    enabled              = optional(bool)
    timeouts = optional(object({
      create = optional(string)
      read   = optional(string)
      update = optional(string)
      delete = optional(string)
    }))
  }))
  default     = {}
  description = "Advanced configuration for eligible member schedules. Keys should be unique identifiers for each schedule."
}

variable "eligible_members" {
  type        = list(string)
  default     = []
  description = "A list of principal IDs to be made eligible for membership in the group."
}

variable "eligible_role_assignments" {
  type = map(object({
    scope                      = string
    role_definition_id_or_name = string
    principal_id               = optional(string, null)
    condition                  = optional(string, null)
    condition_version          = optional(string, null)
    justification              = optional(string, null)
    schedule = optional(object({
      start_date_time = optional(string, null)
      expiration = optional(object({
        duration_days  = optional(number, null)
        duration_hours = optional(number, null)
        end_date_time  = optional(string, null)
      }), null)
    }), null)
    ticket = optional(object({
      system = optional(string, null)
      number = optional(string, null)
    }), null)
    timeouts = optional(object({
      create = optional(string, null)
      read   = optional(string, null)
      delete = optional(string, null)
    }), null)
  }))
  default     = {}
  description = "Map of PIM-eligible role assignments keyed by an arbitrary identifier."

  validation {
    condition = alltrue([
      for _, cfg in var.eligible_role_assignments :
      length(trimspace(cfg.scope)) > 0 && length(trimspace(cfg.role_definition_id_or_name)) > 0
    ])
    error_message = "Each eligible role assignment must include both scope and role_definition_id_or_name."
  }
}

variable "pim_activation_max_duration" {
  type        = string
  default     = "PT8H"
  description = <<-DESCRIPTION
    The maximum duration for which a PIM group membership can be activated. Should be an ISO 8601 duration string (e.g., 'PT8H' for 8 hours).

    **IMPORTANT**: Due to a bug in the msgraph Terraform provider (https://github.com/microsoft/terraform-provider-msgraph/issues/75),
    changing this value from the Microsoft default (PT8H) will cause persistent drift. The provider reports successful updates
    but the API does not persist the changes. Until the provider is fixed, use the default value to avoid drift.
  DESCRIPTION
}

variable "pim_approver_object_ids" {
  type        = list(string)
  default     = []
  description = "A list of object IDs for principals who can approve PIM activation requests. Only used if pim_require_approval_on_activation is true."

  validation {
    condition     = var.pim_require_approval_on_activation ? length(var.pim_approver_object_ids) > 0 : true
    error_message = "Provide at least one approver object ID when pim_require_approval_on_activation is true."
  }
}

variable "pim_approver_object_type" {
  type        = string
  default     = "singleUser"
  description = "The approver object type supplied to the policy. Use 'singleUser' for individual users or 'groupMembers' for Entra ID groups."

  validation {
    condition     = contains(["singleUser", "groupMembers"], var.pim_approver_object_type)
    error_message = "pim_approver_object_type must be either 'singleUser' or 'groupMembers'."
  }
}

variable "pim_eligibility_duration" {
  type        = string
  default     = "P365D"
  description = <<-DESCRIPTION
    The ISO8601 duration that an eligibility assignment remains valid (e.g., 'P365D').

    **IMPORTANT**: Due to a bug in the msgraph Terraform provider (https://github.com/microsoft/terraform-provider-msgraph/issues/75),
    changing this value from the Microsoft default (P365D) will cause persistent drift. The provider reports successful updates
    but the API does not persist the changes. Until the provider is fixed, use the default value to avoid drift.
  DESCRIPTION

  validation {
    condition     = contains(["P15D", "P30D", "P90D", "P180D", "P365D"], var.pim_eligibility_duration)
    error_message = "pim_eligibility_duration must be one of P15D, P30D, P90D, P180D, or P365D as required by Entra ID PIM."
  }
}

variable "pim_policy_settings" {
  type = object({
    role_id = optional(string)
    eligible_assignment_rules = optional(list(object({
      expiration_required = optional(bool)
      expire_after        = optional(string)
    })))
    active_assignment_rules = optional(list(object({
      expiration_required                = optional(bool)
      expire_after                       = optional(string)
      require_multifactor_authentication = optional(bool)
      require_justification              = optional(bool)
      require_ticket_info                = optional(bool)
    })))
    activation_rules = optional(list(object({
      maximum_duration                                   = optional(string)
      require_multifactor_authentication                 = optional(bool)
      require_approval                                   = optional(bool)
      require_justification                              = optional(bool)
      require_ticket_info                                = optional(bool)
      required_conditional_access_authentication_context = optional(string)
      approval_stage = optional(list(object({
        primary_approver = optional(set(object({
          object_id = string
          type      = optional(string)
        })))
      })))
    })))
    notification_rules = optional(list(object({
      eligible_assignments = optional(list(object({
        admin_notifications = optional(list(object({
          default_recipients    = bool
          notification_level    = string
          additional_recipients = optional(set(string))
        })))
        approver_notifications = optional(list(object({
          default_recipients    = bool
          notification_level    = string
          additional_recipients = optional(set(string))
        })))
        assignee_notifications = optional(list(object({
          default_recipients    = bool
          notification_level    = string
          additional_recipients = optional(set(string))
        })))
      })))
      eligible_activations = optional(list(object({
        admin_notifications = optional(list(object({
          default_recipients    = bool
          notification_level    = string
          additional_recipients = optional(set(string))
        })))
        approver_notifications = optional(list(object({
          default_recipients    = bool
          notification_level    = string
          additional_recipients = optional(set(string))
        })))
        assignee_notifications = optional(list(object({
          default_recipients    = bool
          notification_level    = string
          additional_recipients = optional(set(string))
        })))
      })))
      active_assignments = optional(list(object({
        admin_notifications = optional(list(object({
          default_recipients    = bool
          notification_level    = string
          additional_recipients = optional(set(string))
        })))
        approver_notifications = optional(list(object({
          default_recipients    = bool
          notification_level    = string
          additional_recipients = optional(set(string))
        })))
        assignee_notifications = optional(list(object({
          default_recipients    = bool
          notification_level    = string
          additional_recipients = optional(set(string))
        })))
      })))
    })))
  })
  default     = {}
  description = "Overrides for the azuread_group_role_management_policy resource. Provide blocks to fully customise policy behaviour; omit or set empty lists to fall back to sensible defaults."
}

variable "pim_require_approval_on_activation" {
  type        = bool
  default     = false
  description = "Whether approval is required to activate PIM group membership. Should be false for automation."
}

variable "pim_require_mfa_on_activation" {
  type        = bool
  default     = true
  description = "Whether MFA is required to activate PIM group membership."
}
