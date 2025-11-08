# Migration Plan: Replace azuread_group_role_management_policy with Microsoft Graph PIM Policy

Goal: Eliminate hashicorp/azuread dependency inside the module by reimplementing PIM for Groups policy configuration using Microsoft Graph unifiedRoleManagementPolicy + unifiedRoleManagementPolicyAssignment.

## Current State (post-removal stub)

- azuread policy resource deleted.
- Eligibility schedule requests depend only on group creation.
- PIM activation / assignment / notification rules no longer explicitly configured by module.

## Target Graph Resources

- `unifiedRoleManagementPolicyAssignment` (binds a policy to scopeId=groupId, scopeType='Group').
- `unifiedRoleManagementPolicy` (container of 17 predefined rules, accessible via `$expand=rules`).
- Derived rule types to patch:
  - `unifiedRoleManagementPolicyEnablementRule` (MFA, justification, ticket info)
  - `unifiedRoleManagementPolicyApprovalRule` (require approval, approvers)
  - `unifiedRoleManagementPolicyExpirationRule` (max durations for active & eligible)
  - `unifiedRoleManagementPolicyNotificationRule` (emails: admin/approver/assignee)

## Mapping from Module Locals to Graph Rules

| Module concept | Graph rule type | Key rule IDs (examples) | Notes |
| -------------- | --------------- | ------------------------ | ----- |
| Require MFA on activation (`pim_require_mfa_on_activation`) | EnablementRule | `MultiFactorAuthentication_EndUser_Assignment` | Boolean flags grouped with justification/ticket |
| Require approval (`pim_require_approval_on_activation`) + approver list | ApprovalRule | `Approval_EndUser_Assignment` | Approvers: list of directory object IDs |
| Activation max duration (`pim_activation_max_duration`) | ExpirationRule | `Expiration_EndUser_Assignment` | ISO8601 duration; ensure ≤ PIM limits |
| Active assignment default expiration / eligible expiration | ExpirationRule | `Expiration_Admin_Assignment`, `Expiration_Admin_Eligibility` | Distinct rule IDs |
| Justification required (always true today) | EnablementRule | `Justification_EndUser_Assignment` | Keep parity |
| Ticket info required | EnablementRule | `Ticketing_EndUser_Assignment` | System & number requirements |
| Notification recipients | NotificationRule | multiple (e.g., `Notification_Admin_Assignment`) | Each rule holds channels & recipients |

## Sequence for Apply

1. Create group (existing).
2. Read existing policy assignment (filter: scopeId eq groupId, scopeType eq 'Group').
3. If none: create assignment pointing at existing default policy (Graph usually seeds one).
4. GET policy + `$expand=rules`.
5. For each target rule: compute desired config, compare; PATCH only when drift.
6. Proceed with eligibility schedule requests (already implemented).

## Idempotency Strategy

- Lowercase enumerations coming back from Graph.
- Sort recipient lists before comparison.
- Normalize empty lists to `[]` not `null`.
- Use selective PATCH per rule ID to avoid whole policy regression.

## Permissions & Licensing Caveats

- Requires tenant P2 licensing and appropriate delegated or app permissions: `RoleManagement.ReadWrite.Directory`.
- Service principal must be allowed to manage PIM for Groups (Privileged Role Administrator / appropriate directory roles).
- Failure modes: 403 (insufficient privileges), 400 (invalid rule ID or exceeded max duration constraints).

## Error Handling

- Hard fail on policy assignment creation failure (critical path).
- Soft warn on individual rule PATCH failures; continue others; surface aggregated warnings output.
- Provide output variable `pim_policy_rule_status` summarizing applied/unchanged/failed rule IDs.

## Destroy Behavior

- Policy assignment removal occurs automatically when group is deleted; explicit deletion not required.
- No special cleanup beyond existing eligibility schedule request state guidance.

## Out-of-Scope (Initial Implementation)

- Conditional Access authentication context rule.
- Fine-grained notification channel customization beyond recipients + level.
- Beta-only rule types (stick to v1.0 stable).

## Future Enhancements

- CA context integration (AuthenticationContextRule).
- Beta expansion if stable APIs graduate.
- Automatic duration clamping if user exceeds maximum allowed.

## Risks & Mitigations

| Risk | Impact | Mitigation |
| ---- | ------ | ---------- |
| Missing permission | Policy not configured | Preflight check: attempt list; if 403 -> fail fast with actionable message |
| API drift / rule IDs change | PATCH errors | Centralize rule ID constants; document assumptions |
| Large number of PATCH calls slows apply | Performance | Batch only changed rules; reuse policy GET data |
| User sets unsupported duration | 400 error | Validate ISO8601 and max threshold before PATCH |

## Implementation Chunks

1. Add constants & locals for rule ID mapping.
2. msgraph_resource (data) to list policy assignments for scope.
3. msgraph_resource (POST) to create assignment if missing.
4. msgraph_resource (GET) to expand rules.
5. For each rule: msgraph_resource (PATCH) driven by for_each over desired rules needing change.
6. Outputs & docs update.

## Rollback Simplicity

- Single commit sequence on feature branch; revert branch or cherry-pick removal commit out if abandoning.
- No dual-path code retained: azuread removed cleanly.

---
This document guides the Graph policy implementation. After completion, remove this file or convert to permanent design notes in README.
