// Removed unused variable: group_advanced

# NOTE: Terraform does not support top-level custom validation blocks; keeping ownership check implicit.

variable "name" {
  type        = string
  description = "The display name for the Entra ID group."

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 256
    error_message = "The group display name must be between 1 and 256 characters (Microsoft Graph API limit)."
  }
}

variable "allow_role_assignable_group_without_owner" {
  type        = bool
  default     = false
  description = <<DESC
Allows creation of a role-assignable group without any owners. Not recommended.

Why: Owners provide delegated recovery and governance for privileged groups.
Leaving a role-assignable group ownerless can impede lifecycle management and
reduce accountability.

References:
- Microsoft Graph group (isAssignableToRole): https://learn.microsoft.com/graph/api/resources/group?view=graph-rest-1.0
- Assign Azure roles using groups: https://learn.microsoft.com/azure/role-based-access-control/role-assignments-group
- Privileged access groups (PIM): https://learn.microsoft.com/entra/id-governance/privileged-identity-management/groups-features

Set to true only if you fully understand and accept the risk.
DESC
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "group_default_owner_object_ids" {
  type        = list(string)
  default     = []
  description = "Fallback list of owner object IDs when group_settings.owners is not specified. Provide at least one for role-assignable groups."
}

variable "group_description" {
  type        = string
  default     = ""
  description = "A description for the Entra ID group."
}

variable "group_settings" {
  type = object({
    administrative_unit_ids    = optional(list(string))
    assignable_to_role         = optional(bool)
    auto_subscribe_new_members = optional(bool)
    behaviors                  = optional(list(string))
    description                = optional(string)
    external_senders_allowed   = optional(bool)
    hide_from_address_lists    = optional(bool)
    hide_from_outlook_clients  = optional(bool)
    mail_enabled               = optional(bool)
    mail_nickname              = optional(string)
    owners                     = optional(list(string))
    prevent_duplicate_names    = optional(bool)
    provisioning_options       = optional(list(string))
    security_enabled           = optional(bool)
    theme                      = optional(string)
    types                      = optional(list(string))
    visibility                 = optional(string)
    dynamic_membership = optional(object({
      enabled = bool
      rule    = string
    }))
    timeouts = optional(object({
      create = optional(string)
      read   = optional(string)
      update = optional(string)
      delete = optional(string)
    }))
  })
  default     = {}
  description = "Optional settings applied to the Entra ID group beyond the baseline configuration."
}

variable "role_assignment_definition_lookup_use_live_data" {
  type        = bool
  default     = false
  description = "Whether to use live (API) data for role definition name lookups. If false, cached data from the helper module is used for stability."
}

variable "role_assignment_replace_on_immutable_value_changes" {
  type        = bool
  default     = false
  description = "If true, role assignments will be replaced automatically when principalId or roleDefinitionId changes. Leave false to avoid replacement loops with unknown values."
}

variable "role_assignments" {
  type = map(object({
    scope                                  = string
    role_definition_id_or_name             = string
    name                                   = optional(string, null)
    principal_id                           = optional(string, null)
    principal_type                         = optional(string, null)
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    timeouts = optional(object({
      create = optional(string, null)
      read   = optional(string, null)
      delete = optional(string, null)
    }), null)
  }))
  default     = {}
  description = "Map of permanent role assignments keyed by an arbitrary identifier."

  validation {
    condition = alltrue([
      for _, cfg in var.role_assignments :
      length(trimspace(cfg.scope)) > 0 && length(trimspace(cfg.role_definition_id_or_name)) > 0
    ])
    error_message = "Each role assignment must include both scope and role_definition_id_or_name."
  }
  # principal_id must be a UUID when provided
  validation {
    condition = alltrue([
      for _, cfg in var.role_assignments : (
        cfg.principal_id == null || can(regex("^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$", cfg.principal_id))
      )
    ])
    error_message = "principal_id must be a UUID when set."
  }
  # principal_type must be one of the allowed values when provided
  validation {
    condition = alltrue([
      for _, cfg in var.role_assignments : (
        cfg.principal_type == null || contains(["User", "Group", "ServicePrincipal", "MSI"], cfg.principal_type)
      )
    ])
    error_message = "principal_type must be one of 'User', 'Group', 'ServicePrincipal', or 'MSI' when set."
  }
  # condition_version must be '2.0' if condition is set
  validation {
    condition = alltrue([
      for _, cfg in var.role_assignments : (
        cfg.condition == null || cfg.condition_version == "2.0"
      )
    ])
    error_message = "condition_version must be '2.0' when condition is provided."
  }
}

variable "role_definition_lookup_scope" {
  type        = string
  default     = null
  description = "Scope (resource ID) used to list role definitions for name→ID resolution (e.g. subscription or management group). If null, name lookups rely on direct IDs or may fail if a name was supplied."
}
