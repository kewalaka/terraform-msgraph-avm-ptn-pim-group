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
