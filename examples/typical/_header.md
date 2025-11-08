# Typical Example

This scenario provisions a production-style Privileged Access Group (PAG) that operations teams can activate through Microsoft Entra PIM. The configuration generates demo users, randomises names to avoid collisions, assigns the PAG as an eligible `Contributor`, and onboards a nested operations-team group whose members activate individually even though the group is listed as eligible.

## What the example builds

- Two Microsoft Entra users: a PIM approver and an operations on-call operator.
- A role-assignable security group with a random suffix and the approver as owner.
- A nested operations-team security group that contains the operator and is configured as an eligible member of the PAG.
- Azure Role-Based Access Control wiring that keeps the PAG permanently assigned while users activate their access on demand.
- PIM policy rules requiring MFA, approval, and a 4 hour activation window.

## Permissions required

Run this example with the same app registration or credentials you use for the full demo. The identity must have:

- Azure RBAC: `User Access Administrator` (or `Owner`) for the subscription.
- Microsoft Graph application permissions:
  - `Domain.Read.All`
  - `User.Read.All`
  - `User.ReadWrite.All`
  - `Group.Read.All`
  - `Group.ReadWrite.All`
  - `PrivilegedAccess.ReadWrite.AzureADGroup`
  - `PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup`
  - `PrivilegedEligibilitySchedule.Remove.AzureADGroup`
  - `RoleManagementPolicy.ReadWrite.AzureADGroup`
  - `RoleManagement.ReadWrite.Directory`
  - `Directory.ReadWrite.All`

Grant and admin-consent these scopes on the service principal, then run `terraform init`, `terraform plan`, and `terraform apply` inside this folder.

## References

- [Privileged Identity Management (PIM) for Groups – Making group of users eligible for Microsoft Entra role](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/concept-pim-for-groups#making-group-of-users-eligible-for-microsoft-entra-role)
