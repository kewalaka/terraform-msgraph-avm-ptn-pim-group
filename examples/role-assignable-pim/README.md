# Role-assignable PIM example (two-step)

This example creates a brand-new role-assignable Entra ID security group with an owner, using this module. It intentionally leaves PIM policy assignment and rule management disabled on the first apply to guarantee success in any tenant. If your tenant has PIM for Groups enabled, you can enable those switches on a second apply.

## What it does

- Creates an Entra ID user to act as the group owner (so we don't bypass best practices)
- Creates a role-assignable security group with that owner
- Leaves PIM policy management OFF by default to avoid first-apply failures

## Try it

First apply (creates group and owner only):

```sh
terraform init
terraform apply
```

Optional second apply (attach PIM policy and patch rules):

1. Edit `main.tf` and set:

```hcl
create_pim_policy_assignment_if_missing = true
manage_pim_policy_rules                 = true
```

1. Apply again:

```sh
terraform apply
```

## Notes and prerequisites

- Group must be created as role-assignable from the start; Microsoft Graph does not allow flipping `isAssignableToRole` later.
- PIM policy/rule endpoints for Groups are on Graph beta. Enable them only if your tenant has PIM for Groups and you accept beta API behavior.
- If enabling rule management, you can tune durations and approval behavior with the module's `pim_*` variables.
