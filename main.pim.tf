// Privileged Identity Management (PIM) policy resources (beta Graph)
// Replicates previous azuread role management policy behavior: optional policy
// assignment creation (tenant-dependent) and rule drift patching.

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

  depends_on = [time_sleep.wait_for_group_replication]
}

// Discover policy + rules for this group scope (beta)
data "msgraph_resource" "pim_policy" {
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

  depends_on = [time_sleep.wait_for_group_replication]
}

// Patch only drifted rules (enablement / expiration / optional approval).
resource "msgraph_update_resource" "pim_rule" {
  for_each    = { for k, v in local.pim_member_rule_bodies : k => v if var.manage_pim_policy_rules }
  url         = "policies/roleManagementPolicies/${local.pim_policy_id}/rules/${each.key}"
  api_version = "beta"
  body        = each.value

  ignore_missing_property = true
  depends_on              = [data.msgraph_resource.pim_policy]

  lifecycle {
    precondition {
      condition     = local.pim_policy_id != null
      error_message = "PIM policy not found for group scope. Enable PIM for Groups before setting manage_pim_policy_rules=true."
    }
  }
}
