locals {
  eligibility_base = {
    principal_id         = null
    group_id             = null
    assignment_type      = "member"
    duration             = var.pim_eligibility_duration
    expiration_date      = null
    start_date           = null
    justification        = "Eligible for group membership"
    permanent_assignment = null
    ticket_number        = null
    ticket_system        = null
    enabled              = true
    timeouts             = null
  }
  eligibility_entries = concat(local.eligibility_from_list, local.eligibility_from_map)
  eligibility_from_list = [
    for idx, principal_id in var.eligible_members : merge(local.eligibility_base, {
      key          = format("default_%03d", idx)
      principal_id = principal_id
    })
  ]
  eligibility_from_map = [
    for key, cfg in var.eligible_member_schedules : merge(
      local.eligibility_base,
      cfg,
      {
        key = key
      }
    )
  ]
  eligibility_schedules = {
    for schedule in local.eligibility_entries :
    schedule.key => schedule
    if coalesce(schedule.enabled, true)
  }
  eligible_role_assignment_is_id = {
    for key, cfg in local.eligible_role_assignments :
    key => (
      can(regex("^/subscriptions/", cfg.role_definition_id_or_name)) ||
      can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", lower(cfg.role_definition_id_or_name)))
    )
  }
  eligible_role_assignment_lookup = {
    for key, cfg in local.eligible_role_assignments :
    key => cfg
    if !local.eligible_role_assignment_is_id[key]
  }
  eligible_role_assignments = var.eligible_role_assignments
  # Determine if provided role definitions for permanent role assignments are IDs or names
  role_assignment_is_id = {
    for key, cfg in var.role_assignments :
    key => (
      can(regex("^/subscriptions/", cfg.role_definition_id_or_name)) ||
      can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", lower(cfg.role_definition_id_or_name)))
    )
  }
  role_assignment_lookup = {
    for key, cfg in var.role_assignments :
    key => cfg
    if !local.role_assignment_is_id[key]
  }
  group_explicit_owners = try(var.group_settings.owners, null)
  group_owners = (
    local.group_explicit_owners != null && length(local.group_explicit_owners) > 0 ?
    distinct(local.group_explicit_owners) :
    distinct(var.group_default_owner_object_ids)
  )
  pim_activation_defaults = {
    maximum_duration                                   = var.pim_activation_max_duration
    require_multifactor_authentication                 = var.pim_require_mfa_on_activation
    require_approval                                   = var.pim_require_approval_on_activation
    require_justification                              = true
    require_ticket_info                                = true
    required_conditional_access_authentication_context = null
    approval_stage = var.pim_require_approval_on_activation ? [
      {
        primary_approver = [
          for id in var.pim_approver_object_ids : {
            object_id = id
            type      = var.pim_approver_object_type
          }
        ]
      }
    ] : []
  }
  pim_activation_input = try(var.pim_policy_settings.activation_rules, null)
  pim_activation_rules = local.pim_activation_input == null ? [local.pim_activation_defaults] : [for rule in local.pim_activation_input : merge(local.pim_activation_defaults, rule)]
  pim_active_assignment_defaults = {
    expiration_required                = true
    expire_after                       = var.pim_eligibility_duration
    require_multifactor_authentication = var.pim_require_mfa_on_activation
    require_justification              = true
    require_ticket_info                = true
  }
  pim_active_assignment_input = try(var.pim_policy_settings.active_assignment_rules, null)
  pim_active_assignment_rules = local.pim_active_assignment_input == null ? [local.pim_active_assignment_defaults] : [for rule in local.pim_active_assignment_input : merge(local.pim_active_assignment_defaults, rule)]
  pim_eligible_assignment_defaults = {
    expiration_required = true
    expire_after        = var.pim_eligibility_duration
  }
  pim_eligible_assignment_input = try(var.pim_policy_settings.eligible_assignment_rules, null)
  pim_eligible_assignment_rules = local.pim_eligible_assignment_input == null ? [local.pim_eligible_assignment_defaults] : [for rule in local.pim_eligible_assignment_input : merge(local.pim_eligible_assignment_defaults, rule)]
  pim_notification_defaults = tolist([
    {
      eligible_assignments = tolist([
        {
          admin_notifications = tolist([
            {
              additional_recipients = tolist([])
              default_recipients    = true
              notification_level    = "Critical"
            }
          ])
          assignee_notifications = tolist([
            {
              additional_recipients = tolist([])
              default_recipients    = true
              notification_level    = "Critical"
            }
          ])
        }
      ])
    }
  ])
  pim_notification_input             = try(var.pim_policy_settings.notification_rules, null)
  pim_notification_rules             = local.pim_notification_input == null ? local.pim_notification_defaults : local.pim_notification_input
  pim_role_id                        = coalesce(try(var.pim_policy_settings.role_id, null), "member")
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"

  # Role assignments (permanent) - determine if the provided role_def is an ID
  role_assignments_type = "Microsoft.Authorization/roleAssignments@2022-04-01"
  role_assignments_is_id = {
    for key, cfg in var.role_assignments :
    key => (
      can(regex("^/subscriptions/", cfg.role_definition_id_or_name)) ||
      can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", lower(cfg.role_definition_id_or_name)))
    )
  }

  # Fetch mapping from module if enabled, else empty map
  role_definitions_map = var.role_definition_lookup_scope == null ? {} : try(module.role_definitions[0].role_definition_rolename_to_resource_id, {})

  # Compute roleDefinitionId per assignment (use mapping for names, pass through IDs)
  role_assignments_role_definition_resource_ids = {
    for k, v in var.role_assignments : k => (
      local.role_assignments_is_id[k] ? v.role_definition_id_or_name : lookup(local.role_definitions_map, v.role_definition_id_or_name, v.role_definition_id_or_name)
    )
  }

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

  # Eligible role assignments - reuse helper mapping
  eligible_role_assignments_role_definition_resource_ids = {
    for k, v in local.eligible_role_assignments : k => (
      local.eligible_role_assignment_is_id[k] ? v.role_definition_id_or_name : lookup(local.role_definitions_map, v.role_definition_id_or_name, v.role_definition_id_or_name)
    )
  }

  # Pre-compute scheduleInfo body for eligible role assignments (used by azapi_resource.pim_eligible)
  pim_eligible_schedule_info = {
    for k, v in local.eligible_role_assignments :
    k => (
      v.schedule == null ? null : merge(
        {
          startDateTime = try(v.schedule.start_date_time, null)
        },
        try(v.schedule.expiration, null) == null ? {} : {
          expiration = merge(
            {
              type = (
                try(v.schedule.expiration.end_date_time, null) != null ? "AfterDateTime" : (
                  (
                    try(v.schedule.expiration.duration_days, null) != null ||
                    try(v.schedule.expiration.duration_hours, null) != null
                  ) ? "AfterDuration" : "NoExpiration"
                )
              )
            },
            try(v.schedule.expiration.end_date_time, null) != null ? {
              endDateTime = v.schedule.expiration.end_date_time
            } : {},
            (
              try(v.schedule.expiration.duration_days, null) != null ||
              try(v.schedule.expiration.duration_hours, null) != null
            ) ? {
              duration = format(
                "P%sD%sH",
                coalesce(try(v.schedule.expiration.duration_days, null), 0),
                coalesce(try(v.schedule.expiration.duration_hours, null), 0)
              )
            } : {}
          )
        }
      )
    )
  }

  // (PIM rule locals moved to locals.pim.tf)
}
