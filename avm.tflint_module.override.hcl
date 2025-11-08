# AVM-specific tflint overrides for this module
# This file follows the AVM approach used in other AVM modules and disables
# a small set of rules that are incompatible with this module's purpose:
# - This module creates an Entra ID group and assigns it to Azure RBAC roles at external scopes.
# - The AVM interface checks expect role_assignments to be assignments "on" the created resource.
# Disable the AVM rules that enforce that interface and a few related warnings.

# Disable the AVM interface check for role_assignments variable
# This module's role_assignments has 'scope' field because it assigns the created group
# TO Azure resources at various scopes, not roles assigned TO the group itself.
# See variables.tf for full explanation.
rule "role_assignments" {
  enabled = false
}

rule "required_output_rmfr7" {
  enabled = false
}

rule "terraform_module_version" {
  enabled = false
}

rule "terraform_unused_required_providers" {
  enabled = false
}

rule "terraform_unused_declarations" {
  enabled = false
}

# Keep comment syntax checking enabled (we converted // to # where needed), but if
# leftover warnings appear you can disable terraform_comment_syntax as well.
# rule "terraform_comment_syntax" {
#   enabled = false
# }
