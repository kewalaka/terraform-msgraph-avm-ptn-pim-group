# Next Steps

Focused roadmap for the `terraform-msgraph-pim-group` module. This file intentionally omits historical migration detail.

## High-Priority

0. Verifying the existing examples in this repository work.
   - It is acceptable these continue to use `azuread` and `azurerm` providers.
   - **Known Issue**: Azure AD replication delay causes role assignments to fail with `PrincipalNotFound` immediately after group creation. Consider adding azapi retry block with `error_message_regex = ["PrincipalNotFound"]` to handle replication delays.
1. Graph PIM Policy Migration
   - Replace `azuread_group_role_management_policy` with Graph policy resources (`unifiedRoleManagementPolicy`, `unifiedRoleManagementPolicyAssignment`) when Terraform coverage/patterns become viable.
   - Provide wrapper abstraction to keep variable surface stable.
   - **Benefit**: Once migrated to azapi, remove the `time_sleep.wait_for_group_replication` resource and replace with azapi retry logic (more elegant, self-tuning wait for replication).
2. Graph API POST-Restricted Properties
   - The following msgraph group properties cannot be set during initial POST but require PATCH (update): `allowExternalSenders`, `autoSubscribeNewMembers`, `hideFromAddressLists`, `hideFromOutlookClients`.
   - Currently these are omitted from group creation. Consider implementing post-creation updates using `azapi_update_resource` or lifecycle management if these properties are needed.
3. Eligibility Schedule Enhancements
   - Support explicit endDateTime & duration synthesis (days/hours→ISO 8601) for group membership/ownership eligibility.
   - Add validation on mutually exclusive fields (permanent vs duration vs end date).
4. Documentation Refresh
   - Regenerate terraform-docs to reflect new variables (`role_definition_lookup_scope`, lookup/live-data toggles, owner inputs).
   - Add example variants: basic group, role-assignable group, dynamic membership, PIM eligible role assignment.
5. Test Coverage (Smoke + Validation)
   - Local `terraform plan` CI matrix (msgraph + azapi provider versions).
   - Negative tests: missing owner for role-assignable group, invalid principal UUID, bad condition_version.
6. Policy Abstraction Planning
   - Draft variable model for future Graph PIM policy (activation, notifications, approval) to smooth transition.

## Medium-Priority

1. Outputs Review
   - Consider exporting eligibility schedule request IDs and PIM eligible role assignment IDs.
2. Example Permissions Doc
   - Add minimal app registration permission list & consent guidance.
3. Role Definition Lookup UX
   - Warning output (or doc note) when names provided but `role_definition_lookup_scope` is null.
4. Optional Lint/Pre-Commit Hooks
   - Add markdownlint and terraform fmt validation if not already invoked by AVM pre-commit pipeline.

## Low-Priority / Future

1. Dynamic Membership Rule Helper
   - Optional input map -> generate OData rule string.
2. Sensitivity Labels & Licenses Expansion
   - Validate label IDs and SKU IDs against known sets if caching pattern emerges.
3. Complex Schedule Composition
   - Support schedule templates (business hours windows, phased eligibility).

## Done (Key Items)

- msgraph group resource adoption.
- AzAPI permanent role assignments + PIM eligible role assignments.
- Helper module for role definition name→ID (no azurerm dependency).
- Advanced group inputs + ownership enforcement.
- Telemetry headers alignment.

## Guiding Principles

- Keep provider surface minimal; avoid reintroducing azurerm/azuread.
- Fail early with Terraform validation for structural issues (UUIDs, enum values).
- Provide clear opt-in flags for costlier behaviors (live role definition lookup, forced replacements).

---
Update this file as tasks are completed; keep only forward-looking items.
