# PIM policy rule patching (Microsoft Graph beta)
#
# NOTE: According to Microsoft documentation (https://learn.microsoft.com/en-us/graph/api/resources/privilegedidentitymanagement-for-groups-api-overview#onboarding-groups-to-pim-for-groups):
# "You can't explicitly onboard a group to PIM for Groups. When you... update the PIM policy (role settings) for a group...
# PIM automatically onboards the group if it wasn't onboarded before."
#
# Groups are automatically onboarded to PIM when you create eligibility/assignment requests or update policy rules.
# If no pim_* variables are configured, no policy updates are attempted and the group remains un-onboarded (which is fine).

data "msgraph_resource" "pim_policy" {
  count       = length(local.pim_member_rule_bodies) > 0 ? 1 : 0
  url         = "policies/roleManagementPolicies"
  api_version = "beta"

  query_parameters = {
    "$filter" = [
      "scopeId eq '${msgraph_resource.this.id}' and scopeType eq 'Group'"
    ]
    "$expand" = [
      "rules"
    ]
  }

  response_export_values = {
    policy_id = "value[0].id"
    rules     = "value[0].rules"
  }

  depends_on = [msgraph_resource.this, msgraph_resource.eligibility_schedule_requests]
}

resource "msgraph_update_resource" "pim_rule" {
  for_each    = local.pim_member_rule_bodies
  url         = "policies/roleManagementPolicies/${local.pim_policy_id}/rules/${each.key}"
  api_version = "beta"
  body        = each.value

  depends_on = [msgraph_resource.this, data.msgraph_resource.pim_policy]

  lifecycle {
    precondition {
      condition     = local.pim_policy_id != null
      error_message = <<ERROR
PIM policy not found for group. This likely means the group hasn't been onboarded to PIM yet.

To onboard this group to PIM, you have two options:
1. Create at least one eligible assignment using the eligible_member_schedules variable
2. Wait for first apply to complete (group creation), then run apply again - PIM will auto-onboard when updating policy rules

According to Microsoft: "When you update the PIM policy (role settings) for a group, PIM automatically onboards the group if it wasn't onboarded before."
Reference: https://learn.microsoft.com/en-us/graph/api/resources/privilegedidentitymanagement-for-groups-api-overview#onboarding-groups-to-pim-for-groups

However, the initial policy query may fail before onboarding. If you see this error:
- First apply: Create group without PIM customizations (remove pim_* variables temporarily)
- Second apply: Add back pim_* variables - this will trigger auto-onboarding and apply custom rules
ERROR
    }
  }
}

resource "random_uuid" "pim_eligible" {
  for_each = local.eligible_role_assignments
}

resource "azapi_resource" "pim_eligible" {
  for_each = local.eligible_role_assignments

  name      = random_uuid.pim_eligible[each.key].result
  parent_id = each.value.scope
  type      = "Microsoft.Authorization/roleEligibilityScheduleRequests@2022-04-01-preview"
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
  create_headers       = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  delete_headers       = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  ignore_null_property = true
  read_headers         = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
  replace_triggers_refs = var.role_assignment_replace_on_immutable_value_changes ? [
    "properties.principalId",
    "properties.roleDefinitionId",
  ] : null
  update_headers = var.enable_telemetry ? { "User-Agent" = local.avm_azapi_header } : null
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
