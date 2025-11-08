# Issue: eligibilityScheduleRequest 404 on Destroy

## Summary

The `msgraph_resource` provider attempts to DELETE eligibility schedule request resources during `terraform destroy`, resulting in 404 errors. This occurs because Microsoft Graph API treats eligibility schedule requests as ephemeral workflow objects that are consumed/processed and no longer exist as deleteable resources after creation.

## Environment

- **Provider**: `microsoft/msgraph` v0.2.0
- **Resource Type**: `msgraph_resource` (eligibilityScheduleRequests)
- **API Endpoint**: `identityGovernance/privilegedAccess/group/eligibilityScheduleRequests`
- **Terraform Version**: 1.9+

## Expected Behavior

When destroying resources, eligibility schedule requests should either:

1. Be skipped during deletion (treating them as create-only/ephemeral resources), OR
2. Handle 404 responses gracefully during DELETE operations (since the resource no longer exists after processing)

## Actual Behavior

Terraform attempts to DELETE the eligibility schedule request and receives a 404 error, causing the destroy operation to fail:

```text
Error: Failed to delete resource

DELETE https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/eligibilityScheduleRequests/<id>
--------------------------------------------------------------------------------
RESPONSE 404: 404 Not Found
ERROR CODE: UnknownError
--------------------------------------------------------------------------------
{
  "error": {
    "code": "UnknownError",
    "message": "{\"message\":\"No HTTP resource was found that matches the request URI 'https://api.azrbac.mspim.azure.com/api/v3/privilegedAccessGroupEligibilityScheduleRequests('<id>')?'.\"}",
    "innerError": {
      "date": "2025-11-08T00:18:18",
      "request-id": "...",
      "client-request-id": "..."
    }
  }
}
```

## Root Cause Analysis

### Request vs Schedule Distinction

Graph API has two distinct resource types:

- **EligibilityScheduleRequests** (workflow/request objects) - Transient, used to initiate changes
- **EligibilitySchedules** (persistent assignments) - Remain active, can be managed/deleted

### Lifecycle Pattern

1. Graph API accepts and processes the request
2. Creates/updates the corresponding eligibilitySchedule
3. The request object is consumed and no longer available for subsequent operations

### PowerShell SDK Evidence

Graph SDK cmdlet patterns confirm this design:

- `Remove-MgIdentityGovernancePrivilegedAccessGroupEligibilitySchedule` exists (for schedules)
- No corresponding `Remove-*EligibilityScheduleRequest` cmdlet (requests aren't meant to be deleted)

### Microsoft Documentation References

1. **Graph API Resource Types**:
   - Requests: `https://learn.microsoft.com/graph/api/resources/privilegedaccessgroupeligibilityschedulerequest`
   - Schedules: `https://learn.microsoft.com/graph/api/resources/privilegedaccessgroupeligibilityschedule`

2. **PowerShell Cmdlet Pattern**:
   - Remove cmdlets exist for schedules but not for active deletion of requests
   - `Remove-MgIdentityGovernancePrivilegedAccessGroupEligibilitySchedule` deletes navigation property, not the request

3. **API Behavior**:
   - Requests are write-only workflow initiators
   - They transition to completed/archived state and cannot be retrieved or deleted by ID

## Impact

- **Severity**: Medium - Workaround available but requires manual intervention
- **Frequency**: Every destroy operation that includes eligibility schedule requests
- **User Impact**:
  - Destroy fails requiring manual state cleanup (`terraform state rm`)
  - Confusing error message for users unfamiliar with Graph API patterns
  - Additional operational overhead

## Current Workaround

Manual state removal before destroy:

```bash
terraform state rm 'module.privileged_group.msgraph_resource.eligibility_schedule_requests["key_name"]'
terraform destroy -auto-approve
```

Or handle 404 after failed destroy:

```bash
terraform destroy -auto-approve  # Fails with 404
terraform state rm 'module.privileged_group.msgraph_resource.eligibility_schedule_requests["key_name"]'
terraform destroy -auto-approve  # Succeeds
```

## Proposed Solutions

### Option 1: Provider-Level Fix (Preferred)

Update `msgraph` provider to:

- Recognize eligibilityScheduleRequest resources as ephemeral/write-only
- Skip DELETE operations for these resource types
- OR silently ignore 404 responses during destroy for schedule request endpoints

**Implementation**: Provider code change to handle DELETE lifecycle:

```go
// Pseudo-code
if isEphemeralResourceType(resourceType) || is404(err) && isScheduleRequest(url) {
    // Log and continue without error
    return nil
}
```

### Option 2: Resource Lifecycle Configuration

Allow Terraform resource configuration to ignore delete errors:

```hcl
resource "msgraph_resource" "eligibility_schedule_requests" {
  lifecycle {
    ignore_errors_on = ["delete"]  # Proposed feature
  }
}
```

### Option 3: Documentation Enhancement

At minimum, document this behavior clearly in:

- Provider documentation
- Resource examples
- Known issues section

Include explanation that:

- Schedule requests are ephemeral by design
- 404 on destroy is expected and safe to ignore
- Provide state removal workaround

## Related Resources

- **Similar Pattern**: Azure Role Eligibility Schedule Requests follow the same pattern
- **Microsoft Graph API Docs**:
  - [EligibilityScheduleRequest Resource Type](https://learn.microsoft.com/graph/api/resources/privilegedaccessgroupeligibilityschedulerequest)
  - [PIM for Groups Features](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/groups-features)

## Testing Evidence

Reproducible with:

```hcl
resource "msgraph_resource" "eligibility_schedule_requests" {
  for_each = local.eligibility_schedules

  url         = "identityGovernance/privilegedAccess/group/eligibilityScheduleRequests"
  api_version = "v1.0"

  body = {
    groupId     = azuread_group.example.id
    principalId = azuread_user.example.object_id
    action      = "adminAssign"
    accessId    = "member"
    justification = "Test eligibility"
    scheduleInfo = {
      expiration = { type = "noExpiration" }
    }
  }
}
```

1. `terraform apply` - Succeeds, request processed
2. `terraform destroy` - Fails with 404 on DELETE

## Questions for Provider Maintainers

1. Is there existing support for marking resources as create-only/ephemeral?
2. Should the provider detect schedule request endpoints and handle them specially?
3. Would a flag to ignore 404 on destroy be acceptable for these resource types?
4. Are there other Graph API endpoints with similar ephemeral request patterns?

## Additional Context

This issue affects production use cases where:

- Infrastructure is created and destroyed frequently (testing, ephemeral environments)
- CI/CD pipelines require clean destroy operations without manual intervention
- Multi-resource modules need reliable cleanup

The current behavior forces users to understand Graph API internals and perform manual state surgery, which is not typical for Terraform resource management.

---

**Module Context**: This issue was discovered while developing `terraform-msgraph-pim-group` module implementing Azure AD PIM group eligibility schedules using the msgraph provider.

**Date Reported**: 2025-11-08
**Reporter**: Module maintainer (to be submitted to microsoft/terraform-provider-msgraph)
