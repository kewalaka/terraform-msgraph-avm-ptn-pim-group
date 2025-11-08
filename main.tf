# Group and role assignment resources

# tflint-ignore: terraform_module_version
# Using version constraint to allow updates while maintaining compatibility
# Group and role assignment resources
module "role_definitions" {
  source  = "Azure/avm-res-authorization-roledefinition/azurerm"
  version = "0.2.2"
  count   = var.role_definition_lookup_scope == null ? 0 : 1

  enable_telemetry      = var.enable_telemetry
  role_definition_scope = var.role_definition_lookup_scope
  use_cached_data       = !var.role_assignment_definition_lookup_use_live_data
}

resource "msgraph_resource" "this" {
  url         = "groups"
  api_version = "v1.0"

  body = merge(
    {
      displayName = var.name
      description = (
        var.group_settings.description != null ? var.group_settings.description :
        (trimspace(var.group_description) != "" ? var.group_description : null)
      )

      # Security/M365 group flags
      securityEnabled = coalesce(var.group_settings.security_enabled, true)
      mailEnabled     = coalesce(var.group_settings.mail_enabled, false)

      # Mail nickname is required by Graph; derive if not provided
      mailNickname = coalesce(
        try(var.group_settings.mail_nickname, null),
        lower(substr(join("", regexall("[A-Za-z0-9]", var.name)), 0, 64))
      )

      # Explicitly set visibility to avoid drift; default to Private to match Graph's default
      visibility         = coalesce(var.group_settings.visibility, "Private")
      isAssignableToRole = coalesce(var.group_settings.assignable_to_role, true)

      # Group types incl. dynamic membership marker
      groupTypes = distinct(concat(
        coalesce(try(var.group_settings.types, null), []),
        var.group_settings.dynamic_membership != null && try(var.group_settings.dynamic_membership.enabled, false) ? ["DynamicMembership"] : []
      ))

      # Dynamic membership rule
      membershipRule                = var.group_settings.dynamic_membership != null ? var.group_settings.dynamic_membership.rule : null
      membershipRuleProcessingState = var.group_settings.dynamic_membership != null ? var.group_settings.dynamic_membership.processing_state : null
    },
    # Only include owners@odata.bind if there are owners (Graph rejects empty array)
    length(local.group_owners) > 0 ? {
      "owners@odata.bind" = [
        for id in local.group_owners : "https://graph.microsoft.com/v1.0/directoryObjects/${id}"
      ]
    } : {}
  )

  lifecycle {
    precondition {
      condition = (
        !(coalesce(var.group_settings.assignable_to_role, true)) ||
        length(local.group_owners) > 0 ||
        var.allow_role_assignable_group_without_owner
      )
      error_message = "Role-assignable groups should have at least one owner (delegation and recovery best practice). See: Graph isAssignableToRole (https://learn.microsoft.com/graph/api/resources/group?view=graph-rest-1.0) and Assign roles using groups (https://learn.microsoft.com/azure/role-based-access-control/role-assignments-group). To bypass (not recommended), set allow_role_assignable_group_without_owner = true."
    }
  }
}

resource "random_uuid" "role_assignment_name" {
  for_each = var.role_assignments
}

resource "azapi_resource" "role_assignments" {
  for_each = local.role_assignments_azapi

  name                 = each.value.name
  parent_id            = var.role_assignments[each.key].scope
  type                 = local.role_assignments_type
  body                 = each.value.body
  create_headers       = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  delete_headers       = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  ignore_null_property = true
  read_headers         = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  replace_triggers_refs = var.role_assignment_replace_on_immutable_value_changes ? [
    "properties.principalId",
    "properties.roleDefinitionId",
    "properties.scheduleInfo",
  ] : null
  # Retry logic to handle Azure AD replication delays
  retry = {
    error_message_regex = [
      "PrincipalNotFound",
      "does not exist in the directory"
    ]
    interval_seconds     = 10
    max_interval_seconds = 60
  }
  update_headers = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
}



