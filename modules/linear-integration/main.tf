terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.33, != 0.1.35, < 0.2.0" }
  }
}

# =============================================================================
# Linear integration (remote MCP — mcp.linear.app)
#
# Vendored, self-contained copy. No dependency on appcd-dev/solutions.
# Auth is exactly one of:
#   - credential_provider_id  (StackGen Vault OAuth, per-user tokens), or
#   - linear_api_key          (personal API key — this module creates the vault secret), or
#   - existing_secret_id      (pre-existing sg_secret holding LINEAR_API_KEY).
# =============================================================================

locals {
  use_oauth     = trimspace(var.credential_provider_id) != ""
  use_api_key   = !local.use_oauth && (trimspace(var.linear_api_key) != "" || trimspace(var.existing_secret_id) != "")
  create_secret = local.use_api_key && trimspace(var.existing_secret_id) == "" && trimspace(var.linear_api_key) != ""
  secret_id     = local.create_secret ? sg_secret.linear_vault[0].id : var.existing_secret_id

  integration_desc = trimspace(var.description) != "" ? trimspace(var.description) : "Linear project management via remote MCP (mcp.linear.app)."
}

resource "terraform_data" "validate_auth_input" {
  lifecycle {
    precondition {
      condition     = local.use_oauth || local.use_api_key
      error_message = "linear-integration requires credential_provider_id (OAuth) or linear_api_key / existing_secret_id (API key)."
    }
    precondition {
      condition     = !(local.use_oauth && (trimspace(var.linear_api_key) != "" || trimspace(var.existing_secret_id) != ""))
      error_message = "linear-integration cannot accept credential_provider_id together with linear_api_key or existing_secret_id."
    }
    precondition {
      condition     = !(trimspace(var.linear_api_key) != "" && trimspace(var.existing_secret_id) != "")
      error_message = "linear-integration cannot accept both linear_api_key and existing_secret_id; pass only one."
    }
  }
}

resource "sg_secret" "linear_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "Linear API key for MCP integration"
  category    = "ProjectManagement"
  subcategory = "linear"
  metadata = {
    LINEAR_API_KEY = var.linear_api_key
  }
}

resource "sg_guild_integration" "linear" {
  name        = var.integration_name
  description = local.integration_desc
  type        = "linear"
  scope       = var.scope
  enabled     = var.enabled

  credential_provider_id = local.use_oauth ? var.credential_provider_id : null
  secret_ref_ids         = local.use_api_key ? [local.secret_id] : null
}
