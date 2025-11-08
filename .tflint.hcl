config {
  format = "compact"
  call_module_type = "all"
}

plugin "terraform" {
  enabled = true
  preset  = "all"
}

plugin "azurerm" {
  enabled = true
}

# Disable check for terraform_module_version on role_definitions module
# This utility module uses a version constraint to allow compatible updates
rule "terraform_module_version" {
  enabled = false
}

# Note: The role_assignments variable in this module does not comply with standard AVM interface
# because this module assigns the created GROUP to Azure RBAC roles at external scopes,
# rather than assigning roles TO the created resource (the standard AVM pattern).
# The AVM spec check for role_assignments cannot be disabled via tflint, so it will continue
# to show as a warning in PR checks but can be accepted as a known deviation.
