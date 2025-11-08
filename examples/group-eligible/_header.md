# Group-Eligible Pattern (generally not recommended)

This sample demonstrates the “group-eligible role” pattern where the group itself activates the Azure role while users remain permanently assigned to the group. It now creates a demo owner account with a random suffix so it can run end to end in CI without naming collisions.

This scenario supports the recommended approach for PIM for specific M365 portals (SharePoint, Exchange, and Microsoft Purview are noted).  Microsoft guidance notes that PIM for Group can take hours to reach the portal. See the SharePoint [activation delay article](https://learn.microsoft.com/en-us/troubleshoot/sharepoint/administration/access-denied-to-pim-user-accounts).

| Feature | Recommended pattern (eligible users, permanent role) | This example (group eligible for role) |
| --- | --- | --- |
| Role assignment | Group is permanently assigned the Azure role | Group is eligible for the Azure role and must activate it |
| Group membership | Users remain eligible and activate individually | Users stay permanently in the group |
| Activation flow | User signs into PIM and activates their group membership (“Typical” example) | Admin or owner activates the group role on behalf of all members |
| Audit trail | Per-user activation history is visible | Audit shows only group-level activations |

## Why This Pattern Is Not Recommended

- Activation audits are coarse: Microsoft Entra logs record the group activation, not which individual used the access. See the Microsoft guidance on [group-level eligibility trade-offs](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/concept-pim-for-groups#making-group-of-users-eligible-for-microsoft-entra-role).
- Approvals become indirect: approvers evaluate a group activation request and must separately confirm who will consume the access, which increases operational risk.
- Privileged sessions last longer than necessary: when the group is activated, _all_ members inherit the role until the activation expires or an administrator manually ends it.
- Automation is harder: workflow tooling typically expects per-user approvals and notifications, so group activations require custom guardrails.

## When you should consider it

- Activation delays affect Microsoft 365 portals: SharePoint and OneDrive access can take up to 24 hours to materialise after activation when this pattern is used. Microsoft recommends assigning the role directly to the user or making the group eligible for the role while keeping user membership active instead. See [Error when accessing SharePoint or OneDrive after role activation in PIM](https://learn.microsoft.com/en-us/troubleshoot/sharepoint/administration/access-denied-to-pim-user-accounts#cause).

## When You Must Use It

- Document the business exception and expected retirement date.
- Shorten activation durations and enforce ticket metadata to offset the broader blast radius.
- Pair the pattern with manual or automated post-activation reviews to identify who actually used the role.

## References

- [Privileged Identity Management (PIM) for Groups overview](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/concept-pim-for-groups)
- [Error when accessing SharePoint or OneDrive after role activation in PIM](https://learn.microsoft.com/en-us/troubleshoot/sharepoint/administration/access-denied-to-pim-user-accounts)
- [Microsoft Entra ID Governance best practices](https://learn.microsoft.com/en-us/entra/id-governance/best-practices-secure-id-governance#preventing-lateral-movement)
