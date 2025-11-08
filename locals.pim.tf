// PIM policy rule construction
locals {
  pim_activation_enabled_rules = compact([
    "Justification",
    "Ticketing",
    var.pim_require_mfa_on_activation ? "MultiFactorAuthentication" : null,
  ])
  pim_approval_primary_approvers = [
    for id in var.pim_approver_object_ids : (
      var.pim_approver_object_type == "groupMembers" ? {
        "@odata.type" = "#microsoft.graph.groupMembers"
        groupId       = id
        } : {
        "@odata.type" = "#microsoft.graph.singleUser"
        userId        = id
      }
    )
  ]
  pim_current_rules_list = try(data.msgraph_resource.pim_policy[0].output.rules, [])
  pim_current_rules_map  = { for r in local.pim_current_rules_list : r.id => r if try(r.id, null) != null }
  pim_enabled_rules_current = {
    for k, v in local.pim_current_rules_map : k => sort(try(v.enabledRules, []))
  }
  pim_member_rule_bodies = merge(
    local.pim_member_rule_bodies_base,
    var.pim_require_approval_on_activation ? {
      "Approval_EndUser_Assignment" = {
        "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
        id            = "Approval_EndUser_Assignment"
        target = {
          "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
          caller              = "EndUser"
          operations          = ["All"]
          level               = "Assignment"
          inheritableSettings = []
          enforcedSettings    = []
        }
        setting = {
          "@odata.type"                    = "microsoft.graph.approvalSettings"
          isApprovalRequired               = true
          isApprovalRequiredForExtension   = false
          isRequestorJustificationRequired = true
          approvalMode                     = "SingleStage"
          approvalStages = [
            {
              approvalStageTimeOutInDays      = 1
              isApproverJustificationRequired = true
              escalationTimeInMinutes         = 0
              primaryApprovers                = local.pim_approval_primary_approvers
              isEscalationEnabled             = false
              escalationApprovers             = []
            }
          ]
        }
      }
    } : {}
  )
  pim_member_rule_bodies_base = {
    "Enablement_EndUser_Assignment" = {
      "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
      id            = "Enablement_EndUser_Assignment"
      enabledRules  = local.pim_activation_enabled_rules
      target = {
        "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
        caller              = "EndUser"
        operations          = ["All"]
        level               = "Assignment"
        inheritableSettings = []
        enforcedSettings    = []
      }
    }
    "Expiration_EndUser_Assignment" = {
      "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
      id                   = "Expiration_EndUser_Assignment"
      isExpirationRequired = true
      maximumDuration      = var.pim_activation_max_duration
      target = {
        "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
        caller              = "EndUser"
        operations          = ["All"]
        level               = "Assignment"
        inheritableSettings = []
        enforcedSettings    = []
      }
    }
    "Expiration_Admin_Eligibility" = {
      "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
      id                   = "Expiration_Admin_Eligibility"
      isExpirationRequired = true
      maximumDuration      = var.pim_eligibility_duration
      target = {
        "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
        caller              = "Admin"
        operations          = ["All"]
        level               = "Eligibility"
        inheritableSettings = []
        enforcedSettings    = []
      }
    }
    "Expiration_Admin_Assignment" = {
      "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
      id                   = "Expiration_Admin_Assignment"
      isExpirationRequired = true
      maximumDuration      = var.pim_eligibility_duration
      target = {
        "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
        caller              = "Admin"
        operations          = ["All"]
        level               = "Assignment"
        inheritableSettings = []
        enforcedSettings    = []
      }
    }
  }
  pim_policy_id = try(data.msgraph_resource.pim_policy[0].output.policy_id, null)
  pim_rule_drift = {
    for rule_id, desired in local.pim_member_rule_bodies : rule_id => desired
    if local.pim_policy_id != null && (
      !contains(keys(local.pim_current_rules_map), rule_id) || (
        desired["@odata.type"] == "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule" ? (
          join(",", sort(desired.enabledRules)) != join(",", lookup(local.pim_enabled_rules_current, rule_id, []))
          ) : (
          desired["@odata.type"] == "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule" ? (
            tostring(try(local.pim_current_rules_map[rule_id].maximumDuration, "")) != tostring(desired.maximumDuration)
            ) : (
            desired["@odata.type"] == "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule" ? (
              jsonencode(try(local.pim_current_rules_map[rule_id].setting, {})) != jsonencode(try(desired.setting, {}))
            ) : false
          )
        )
      )
    )
  }
  pim_rule_unchanged = {
    for rule_id, desired in local.pim_member_rule_bodies : rule_id => true
    if local.pim_policy_id != null && contains(keys(local.pim_current_rules_map), rule_id) && !contains(keys(local.pim_rule_drift), rule_id)
  }
}

// PIM eligibility helpers
locals {
  # Group membership eligibility schedules (PIM for Groups)
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
  # RBAC eligible role assignments (PIM for Azure RBAC)
  eligible_role_assignments = var.eligible_role_assignments
  eligible_role_assignments_role_definition_resource_ids = {
    for k, v in local.eligible_role_assignments : k => (
      local.eligible_role_assignment_is_id[k] ? v.role_definition_id_or_name : lookup(local.role_definitions_map, v.role_definition_id_or_name, v.role_definition_id_or_name)
    )
  }
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
  # PIM role id (policy)
  pim_role_id = coalesce(try(var.pim_policy_settings.role_id, null), "member")
}
