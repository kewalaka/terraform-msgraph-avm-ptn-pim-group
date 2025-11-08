# PIM policy assignment & rule patching (Microsoft Graph beta)

resource "msgraph_resource" "pim_policy_assignment" {
  for_each    = var.create_pim_policy_assignment_if_missing ? { default = true } : {}
  url         = "policies/roleManagementPolicyAssignments"
  api_version = "beta"

  body = {
    scopeId          = msgraph_resource.this.id
    scopeType        = "Group"
    roleDefinitionId = local.pim_role_id
    policyId         = "Group_${msgraph_resource.this.id}_${local.pim_role_id}"
  }

  depends_on = [msgraph_resource.this]
}

data "msgraph_resource" "pim_policy" {
  count       = var.manage_pim_policy_rules ? 1 : 0
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

  depends_on = [msgraph_resource.this]
}

resource "msgraph_update_resource" "pim_rule" {
  for_each    = { for k, v in local.pim_member_rule_bodies : k => v if var.manage_pim_policy_rules }
  url         = "policies/roleManagementPolicies/${local.pim_policy_id}/rules/${each.key}"
  api_version = "beta"
  body        = each.value

  ignore_missing_property = true
  depends_on              = [msgraph_resource.this, data.msgraph_resource.pim_policy]

  lifecycle {
    precondition {
      condition     = local.pim_policy_id != null
      error_message = "PIM policy not found for group scope. Enable PIM for Groups before setting manage_pim_policy_rules=true."
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
