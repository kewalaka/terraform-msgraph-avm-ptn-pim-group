// Locals derived from discovered PIM policy (isolated from main.tf)
locals {
  // PIM rule bodies (moved from locals.tf)
  pim_activation_enabled_rules = compact([
    "Justification",
    "Ticketing",
    var.pim_require_mfa_on_activation ? "MultiFactorAuthentication" : null,
  ])

  pim_approval_primary_approvers = [
    for id in var.pim_approver_object_ids : (
      var.pim_approver_object_type == "groupMembers" ? {
        "@odata.type" = "#microsoft.graph.groupMembers"
        groupId        = id
      } : {
        "@odata.type" = "#microsoft.graph.singleUser"
        userId         = id
      }
    )
  ]

  pim_member_rule_bodies_base = {
    "Enablement_EndUser_Assignment" = {
      "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
      id            = "Enablement_EndUser_Assignment"
      enabledRules  = local.pim_activation_enabled_rules
      target = {
        "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
        caller               = "EndUser"
        operations           = ["All"]
        level                = "Assignment"
        inheritableSettings  = []
        enforcedSettings     = []
      }
    }
    "Expiration_EndUser_Assignment" = {
      "@odata.type"       = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
      id                  = "Expiration_EndUser_Assignment"
      isExpirationRequired = true
      maximumDuration     = var.pim_activation_max_duration
      target = {
        "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
        caller               = "EndUser"
        operations           = ["All"]
        level                = "Assignment"
        inheritableSettings  = []
        enforcedSettings     = []
      }
    }
    "Expiration_Admin_Eligibility" = {
      "@odata.type"       = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
      id                  = "Expiration_Admin_Eligibility"
      isExpirationRequired = true
      maximumDuration     = var.pim_eligibility_duration
      target = {
        "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
        caller               = "Admin"
        operations           = ["All"]
        level                = "Eligibility"
        inheritableSettings  = []
        enforcedSettings     = []
      }
    }
    "Expiration_Admin_Assignment" = {
      "@odata.type"       = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
      id                  = "Expiration_Admin_Assignment"
      isExpirationRequired = true
      maximumDuration     = var.pim_eligibility_duration
      target = {
        "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
        caller               = "Admin"
        operations           = ["All"]
        level                = "Assignment"
        inheritableSettings  = []
        enforcedSettings     = []
      }
    }
  }

  pim_member_rule_bodies = merge(
    local.pim_member_rule_bodies_base,
    var.pim_require_approval_on_activation ? {
      "Approval_EndUser_Assignment" = {
        "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
        id            = "Approval_EndUser_Assignment"
        target = {
          "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
          caller               = "EndUser"
          operations           = ["All"]
          level                = "Assignment"
          inheritableSettings  = []
          enforcedSettings     = []
        }
        setting = {
          "@odata.type"                   = "microsoft.graph.approvalSettings"
          isApprovalRequired              = true
          isApprovalRequiredForExtension  = false
          isRequestorJustificationRequired = true
          approvalMode                    = "SingleStage"
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
  pim_policy_id          = try(data.msgraph_resource.pim_policy.output.policy_id, null)
  pim_current_rules_list = try(data.msgraph_resource.pim_policy.output.rules, [])
  pim_current_rules_map  = { for r in local.pim_current_rules_list : r.id => r if try(r.id, null) != null }

  pim_enabled_rules_current = {
    for k, v in local.pim_current_rules_map : k => sort(try(v.enabledRules, []))
  }

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
