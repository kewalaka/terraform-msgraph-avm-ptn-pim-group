// azuread_client_config removed; owners are provided via variables

// Role Definition Helper Module (conditional)
module "role_definitions" {
  source  = "Azure/avm-utl-roledefinitions/azure"
  version = ">= 0.1.0"

  enable_telemetry      = var.enable_telemetry
  role_definition_scope = var.role_definition_lookup_scope
  use_cached_data       = !var.role_assignment_definition_lookup_use_live_data

  count = var.role_definition_lookup_scope == null ? 0 : 1
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

      // Security/M365 group flags
      securityEnabled = coalesce(var.group_settings.security_enabled, true)
      mailEnabled     = coalesce(var.group_settings.mail_enabled, false)

      // Mail nickname is required by Graph; derive if not provided
      mailNickname = coalesce(
        try(var.group_settings.mail_nickname, null),
        lower(substr(join("", regexall("[A-Za-z0-9]", var.name)), 0, 64))
      )

      // Explicitly set visibility to avoid drift; default to Private to match Graph's default
      visibility         = coalesce(var.group_settings.visibility, "Private")
      isAssignableToRole = coalesce(var.group_settings.assignable_to_role, true)

      // Group types incl. dynamic membership marker
      groupTypes = distinct(concat(
        coalesce(try(var.group_settings.types, null), []),
        var.group_settings.dynamic_membership != null && try(var.group_settings.dynamic_membership.enabled, false) ? ["DynamicMembership"] : []
      ))

      // Dynamic membership rule
      membershipRule                = var.group_settings.dynamic_membership != null ? var.group_settings.dynamic_membership.rule : null
      membershipRuleProcessingState = var.group_settings.dynamic_membership != null && try(var.group_settings.dynamic_membership.enabled, false) ? "On" : null
    },
    // Only include owners@odata.bind if there are owners (Graph rejects empty array)
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

  type      = local.role_assignments_type
  name      = each.value.name
  parent_id = var.role_assignments[each.key].scope
  body      = each.value.body

  ignore_null_property = true
  replace_triggers_refs = var.role_assignment_replace_on_immutable_value_changes ? [
    "properties.principalId",
    "properties.roleDefinitionId",
    "properties.scheduleInfo",
  ] : null
  create_headers = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  update_headers = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null

  # Retry logic to handle Azure AD replication delays
  retry = {
    error_message_regex = [
      "PrincipalNotFound",
      "does not exist in the directory"
    ]
    interval_seconds     = 10
    max_interval_seconds = 60
  }
}

resource "random_uuid" "pim_eligible" {
  for_each = local.eligible_role_assignments
}

resource "azapi_resource" "pim_eligible" {
  for_each = local.eligible_role_assignments

  type      = "Microsoft.Authorization/roleEligibilityScheduleRequests@2022-04-01-preview"
  name      = random_uuid.pim_eligible[each.key].result
  parent_id = each.value.scope

  body = {
    properties = {
      requestType      = "AdminAssign"
      justification    = try(each.value.justification, null)
      principalId      = coalesce(try(each.value.principal_id, null), msgraph_resource.this.id)
      roleDefinitionId = local.eligible_role_assignments_role_definition_resource_ids[each.key]
      condition        = try(each.value.condition, null)
      conditionVersion = try(each.value.condition_version, null)
      ticketInfo = try(each.value.ticket, null) == null ? null : {
        ticketSystem = try(each.value.ticket.system, null)
        ticketNumber = try(each.value.ticket.number, null)
      }
      scheduleInfo = lookup(local.pim_eligible_schedule_info, each.key, null)
    }
  }

  ignore_null_property = true
  replace_triggers_refs = var.role_assignment_replace_on_immutable_value_changes ? [
    "properties.principalId",
    "properties.roleDefinitionId",
  ] : null
  create_headers = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  update_headers = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
}

resource "msgraph_resource" "eligibility_schedule_requests" {
  for_each = local.eligibility_schedules

  url         = "identityGovernance/privilegedAccess/group/eligibilityScheduleRequests"
  api_version = "v1.0"

  # Ensure group exists before creating eligibility schedules
  depends_on = [msgraph_resource.this]

  body = merge(
    {
      groupId     = coalesce(each.value.group_id, msgraph_resource.this.id)
      principalId = each.value.principal_id
      # Graph returns lowercase values; use lowercase to keep idempotent
      action = "adminAssign"
      # Note: Property is 'accessId', not 'memberType'. Values are "member" or "owner" (lowercase)
      accessId      = lower(coalesce(each.value.assignment_type, "member"))
      justification = each.value.justification
      scheduleInfo = merge(
        {
          expiration = (
            each.value.permanent_assignment == true ? { type = "noExpiration" } : (
              each.value.expiration_date != null ? {
                type        = "afterDateTime"
                endDateTime = each.value.expiration_date
                } : (
                each.value.duration != null ? {
                  type     = "afterDuration"
                  duration = each.value.duration
                } : { type = "noExpiration" }
              )
            )
          )
        },
        # Only include startDateTime if it's not null
        each.value.start_date != null ? { startDateTime = each.value.start_date } : {}
      )
    },
    # Only include ticketInfo if ticket_number or ticket_system is provided
    (each.value.ticket_number != null || each.value.ticket_system != null) ? {
      ticketInfo = {
        ticketNumber = each.value.ticket_number
        ticketSystem = each.value.ticket_system
      }
    } : {}
  )
}

# Allow time for group replication before applying PIM policy
resource "time_sleep" "wait_for_group_replication" {
  depends_on      = [msgraph_resource.this]
  create_duration = "30s"
}

// (PIM resources moved to main.pim.tf)


