# terraform-msgraph-pim-group

Azure Verified style module for managing an Entra ID (Microsoft Graph) group plus:

* Role-assignable group lifecycle via `msgraph_resource` (`groups@v1.0`)
* Permanent Azure RBAC role assignments and PIM eligible role assignments via AzAPI
* Entra ID Group PIM eligibility schedule requests (membership/ownership) via Graph
* Optional advanced group attributes (`group_advanced`) and ownership enforcement
* Telemetry headers aligned with AVM guidance (opt-out via `enable_telemetry = false`)

## Graph Permissions (Minimum Application Permissions)

| Capability | Permissions |
|------------|-------------|
| Create / Update Group | `Group.ReadWrite.All`, `Directory.ReadWrite.All` |
| Role-Assignable Group | `RoleManagement.ReadWrite.Directory` |
| Group PIM Eligibility Requests | `PrivilegedAccess.ReadWrite.AzureADGroup` |

## Technical notes

### Role Definition Resolution Pattern

Name→ID resolution handled by helper module mapping; IDs pass through unchanged. Fallback preserves user-supplied value if unmapped (supports custom roles defined at narrower scopes if user supplies full ID).

### Ownership Enforcement

Role-assignable groups must declare at least one owner via `group_settings.owners` or `group_default_owner_object_ids`; enforced with resource lifecycle precondition.
