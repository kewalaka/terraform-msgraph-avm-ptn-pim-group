# terraform-msgraph-avm-ptn-pim-group

Azure Verified style module for managing an Entra ID Privileged Identity Management group.

Experimental approach using the Microsoft-owned providers (`msgraph` and `azapi`), instead of
traditional `azurerm` and `azuread`.

## Status

Functional however there is a `destroy` bug that prevent resources being tidied.

See <https://github.com/microsoft/terraform-provider-msgraph/issues/66>

Workaround until the above is fixed is to adjust terraform state before destroy:

```bash
terraform state rm 'module.privileged_group.msgraph_resource.eligibility_schedule_requests["default_000"]'
terraform destroy -auto-approve
```

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
