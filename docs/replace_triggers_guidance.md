# Replacement and schedule request cleanup guidance

This module exposes `role_assignment_replace_on_immutable_value_changes` to control whether certain immutable properties trigger replacement instead of in-place update for ARM resources:

- properties.principalId
- properties.roleDefinitionId
- properties.scheduleInfo (for PIM eligibility schedule requests)

These attributes are effectively immutable at the API level. If they change, Azure will not accept a PATCH/PUT and a new resource must be created.

## Why the module default is false

Keeping the default to `false` avoids noisy two-pass applies in cases where values are unknown at plan time and only become known after the first apply:

- principalId can be unknown initially when you let the module create the group and then use its objectId as principal
- roleDefinitionId can be unknown when you supply a role name and rely on name→ID lookup

Making replacements on unknown→known transitions leads to an unnecessary second apply. This is confusing and adds churn.

## When to enable replacement

Set `role_assignment_replace_on_immutable_value_changes = true` when:

- You pass explicit, known-at-plan-time `principal_id`
- You provide role definitions by full ID (or your lookup scope resolves deterministically)
- You are intentionally rotating immutables and want Terraform to replace

Example:

```hcl
module "privileged_group" {
  source = "kewalaka/terraform-msgraph-avm-ptn-pim-group"

  # ...
  role_definition_lookup_scope = "/subscriptions/00000000-0000-0000-0000-000000000000"
  role_assignment_replace_on_immutable_value_changes = true
}
```

## About PIM schedule requests (Azure RBAC)

Resources of type `Microsoft.Authorization/roleEligibilityScheduleRequests` are workflow requests. They are create-only and typically not patchable or deletable post-processing. As a result:

- Updates to schedule info should be modeled as new requests (replacements)
- Destroy may fail with 404/403 if the request was already processed or delete is disallowed
- The safe cleanup for these requests is to remove them from Terraform state before destroy:

```bash
terraform state rm 'module.privileged_group.azapi_resource.pim_eligible["<key>"]'
terraform destroy -auto-approve
```

See also: `docs/ISSUE_eligibility_schedule_request_404.md` for details and upstream recommendations.

## Future improvement: smart default

We may switch to a guarded default that enables replacements only when the values are known at plan time, avoiding apply loops while keeping correct semantics on real changes. Feedback welcome.

## AzureAD provider removal note

We are actively deprecating AzureAD usage. Remaining functionality (e.g., group role management policy) will migrate to AzAPI or Microsoft Graph endpoints, at which point retry/scheduling behavior can be aligned and the temporary `time_sleep` can be removed.
