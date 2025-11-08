# Next Steps

Focused roadmap for the `terraform-msgraph-avm-ptn-pim-group` module (AVM Pattern Module).

## High-Priority

1. ✅ ~~Graph PIM Policy Migration~~ **COMPLETED**
   - ✅ Replaced `azuread_group_role_management_policy` with Microsoft Graph resources (`msgraph_resource` for policy assignment, `msgraph_update_resource` for selective rule patching)
   - ✅ Implemented unifiedRoleManagementPolicy/Assignment pattern with 17+ rule types (enablement, approval, expiration, notification)
   - ✅ Added selective PATCH strategy for policy rules with drift detection
   - ✅ Wrapper abstraction maintains stable variable surface via `pim_*` variables
2. Graph API POST-Restricted Properties
   - The following msgraph group properties cannot be set during initial POST but require PATCH (update): `allowExternalSenders`, `autoSubscribeNewMembers`, `hideFromAddressLists`, `hideFromOutlookClients`.
   - Currently these are omitted from group creation. Consider implementing post-creation updates using `msgraph_update_resource` if these properties are needed.
3. Eligibility Schedule Enhancements
   - Support explicit endDateTime & duration synthesis (days/hours→ISO 8601) for group membership/ownership eligibility.
   - Add validation on mutually exclusive fields (permanent vs duration vs end date).
4. ✅ ~~Documentation Refresh~~ **COMPLETED**
   - ✅ Generated terraform-docs reflecting new variables and PIM policy structure
   - ✅ Added 5 example variants: default (minimal), typical, full, group-eligible, role-assignable-pim
   - ✅ Added AVM agent instructions (AGENTS.md, .github/copilot-instructions.md)
   - ✅ Created migration plan documentation (docs/migration-plan-pim-policy-graph.md)

## Medium-Priority

1. **AVM Pattern Module Compliance**
   - ✅ Added `resource_id` output (AVM RMFR7 requirement)
   - ✅ Created `avm.tflint_module.override.hcl` documenting intentional deviations (role_assignments interface)
   - ⚠️ **TODO**: Fix PR check failures (module version availability issue with role_definitions dependency)
   - **Note**: As a Pattern Module, this combines multiple resources (Entra ID group + Azure RBAC assignments + PIM policies) which is appropriate for PTN spec
2. Outputs Review
   - Consider exporting eligibility schedule request IDs and PIM policy rule status (partially done via `pim_policy_rule_status` output).
3. Example Permissions Doc
   - ✅ Documented in README: `Group.ReadWrite.All`, `Directory.ReadWrite.All`, `RoleManagement.ReadWrite.Directory`, `PrivilegedAccess.ReadWrite.AzureADGroup`
   - Consider adding detailed app registration step-by-step guide if needed
4. Role Definition Lookup UX
   - Warning output (or doc note) when names provided but `role_definition_lookup_scope` is null.

## Low-Priority / Future

1. Dynamic Membership Rule Helper
   - Optional input map → generate OData rule string.
   - ✅ Current implementation accepts raw rule string (sufficient for PTN module)
2. Sensitivity Labels & Licenses Expansion
   - Validate label IDs and SKU IDs against known sets if caching pattern emerges.
3. Complex Schedule Composition
   - Support schedule templates (business hours windows, phased eligibility).
4. Retry Logic for Replication Delays
   - **Known Issue**: Azure AD replication delay causes role assignments to fail with `PrincipalNotFound` immediately after group creation.
   - Consider adding azapi retry block with `error_message_regex = ["PrincipalNotFound"]` to handle replication delays (cleaner than time_sleep).

## Done (Major Items)

- ✅ **msgraph group resource adoption** - using `msgraph_resource` for group management
- ✅ **Microsoft Graph PIM Policy implementation** - unifiedRoleManagementPolicy/Assignment with selective rule patching
- ✅ **AzAPI permanent role assignments + PIM eligible role assignments** - both permanent and eligible patterns implemented
- ✅ **Helper module for role definition name→ID** - using `avm-res-authorization-roledefinition` (no azurerm dependency in core module)
- ✅ **Advanced group inputs + ownership enforcement** - lifecycle preconditions for role-assignable groups
- ✅ **Telemetry headers alignment** - AVM-compliant telemetry with `modtm` provider
- ✅ **Code organization** - separated PIM logic into `*.pim.tf` files for maintainability
- ✅ **AVM governance compliance** - pre-commit checks passing, tflint overrides documented
- ✅ **Variable schema fixes** - corrected `dynamic_membership` schema (enabled→processing_state)

## Not Applicable (AVM Pattern Module Context)

The following items from original roadmap are **not relevant** for an AVM Pattern (PTN) module:

- ❌ **Test Coverage (Smoke + Validation)** - AVM PTN modules rely on examples as validation; extensive unit testing is for RES modules
- ❌ **Optional Lint/Pre-Commit Hooks** - Already handled by AVM governance pipeline (`./avm pre-commit` and `./avm pr-check`)

## Guiding Principles (AVM PTN Module)

- ✅ Keep provider surface minimal; this PTN module uses `msgraph`, `azapi`, `random`, `modtm` (no azurerm/azuread in core)
- ✅ Fail early with Terraform validation for structural issues (UUIDs, enum values)
- ✅ Provide clear opt-in flags for costlier behaviors (live role definition lookup, forced replacements)
- ✅ Follow AVM Pattern Module spec: compose multiple resources to solve a specific use case (Entra ID PIM group + Azure RBAC)
- ✅ Maintain backwards compatibility where possible; document breaking changes explicitly

---
Update this file as tasks are completed; keep only forward-looking items.
