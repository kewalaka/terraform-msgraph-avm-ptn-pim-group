output "group_id" {
  description = "The ID of the created Entra ID group (Microsoft Graph group id)."
  value       = msgraph_resource.this.id
}

output "group_object_id" {
  description = "The Object ID of the created Entra ID group (same as group_id)."
  value       = msgraph_resource.this.id
}

output "role_assignments_azapi" {
  description = "Canonical map of permanent role assignments ready for azapi_resource consumption (name + body + scope derived)."
  value       = local.role_assignments_azapi
}

output "pim_policy_rule_status" {
  description = "Map of PIM policy rule IDs to status (applied|unchanged|policy_missing)."
  value = local.pim_policy_id == null ? {
    for rule_id in keys(local.pim_member_rule_bodies) : rule_id => "policy_missing"
  } : merge(
    { for rule_id in keys(local.pim_rule_drift) : rule_id => "applied" },
    { for rule_id in keys(local.pim_rule_unchanged) : rule_id => "unchanged" }
  )
}
