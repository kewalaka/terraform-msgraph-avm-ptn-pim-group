locals {
  # Owners: use explicit list if provided; else fallback list
  group_explicit_owners = try(var.group_settings.owners, null)
  group_owners = (
    local.group_explicit_owners != null && length(local.group_explicit_owners) > 0 ?
    distinct(local.group_explicit_owners) :
    distinct(var.group_default_owner_object_ids)
  )
  # Canonical map for azapi roleAssignments
  role_assignments_azapi = {
    for k, v in var.role_assignments : k => {
      name  = coalesce(v.name, random_uuid.role_assignment_name[k].result)
      scope = v.scope
      body = {
        properties = {
          principalId                        = coalesce(try(v.principal_id, null), msgraph_resource.this.id)
          roleDefinitionId                   = local.role_assignments_role_definition_resource_ids[k]
          conditionVersion                   = lookup(v, "condition_version", null)
          condition                          = lookup(v, "condition", null)
          description                        = lookup(v, "description", null)
          principalType                      = lookup(v, "principal_type", null)
          delegatedManagedIdentityResourceId = lookup(v, "delegated_managed_identity_resource_id", null)
        }
      }
    }
  }
  role_assignments_is_id = {
    for key, cfg in var.role_assignments :
    key => (
      can(regex("^/subscriptions/", cfg.role_definition_id_or_name)) ||
      can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", lower(cfg.role_definition_id_or_name)))
    )
  }
  # Compute roleDefinitionId per assignment (use mapping for names, pass through IDs)
  role_assignments_role_definition_resource_ids = {
    for k, v in var.role_assignments : k => (
      local.role_assignments_is_id[k] ? v.role_definition_id_or_name : lookup(local.role_definitions_map, v.role_definition_id_or_name, v.role_definition_id_or_name)
    )
  }
  # Role assignments (permanent) - determine if the provided role_def is an ID
  role_assignments_type = "Microsoft.Authorization/roleAssignments@2022-04-01"
  # Fetch mapping from module if enabled, else empty map
  role_definitions_map = var.role_definition_lookup_scope == null ? {} : try(module.role_definitions[0].role_definition_rolename_to_resource_id, {})
}
