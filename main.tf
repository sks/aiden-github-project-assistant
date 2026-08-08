# =============================================================================
# Tracker-agnostic Board SDLC Assistant
#
# Stable DNA: Specify → Research → Plan → optional PR → human merge → Done.
# Adapters: GitHub Projects and Linear today; Jira can implement the same contract.
# Slack: notify-only after a durable tracker receipt.
# =============================================================================

locals {
  # Keep the v0.2 preview resource prefix so upgrading the already-applied
  # dogfood changes behavior in place instead of replacing integrations/secrets.
  # The public architecture is tracker-neutral; resource names are migration IDs.
  module_prefix = "linear-board-assistant"
  suffix        = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name = "${local.module_prefix}${local.suffix}"

  want_linear = (
    var.enable_linear_webhook ||
    trimspace(var.existing_linear_integration_name) != "" ||
    trimspace(var.linear_api_key) != "" ||
    trimspace(var.linear_secret_id) != "" ||
    trimspace(var.linear_credential_provider_id) != ""
  )
  provision_linear        = local.want_linear && trimspace(var.existing_linear_integration_name) == ""
  linear_integration_name = "${local.module_prefix}-linear${local.suffix}"
  resolved_linear_integration_name = local.want_linear ? (
    trimspace(var.existing_linear_integration_name) != "" ? var.existing_linear_integration_name :
    module.linear_integration[0].integration_name
  ) : ""

  want_slack             = var.enable_slack_notify
  provision_slack        = local.want_slack && trimspace(var.existing_slack_integration_name) == ""
  slack_integration_name = "${local.module_prefix}-slack${local.suffix}"
  resolved_slack_integration_name = local.want_slack ? (
    trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name :
    module.slack_integration[0].integration_name
  ) : ""

  want_github = (
    var.enable_github ||
    var.enable_github_webhook ||
    var.enable_implement ||
    trimspace(var.existing_github_integration_name) != "" ||
    trimspace(var.github_secret_id) != ""
  )
  provision_github        = local.want_github && trimspace(var.existing_github_integration_name) == ""
  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  resolved_github_integration_name = local.want_github ? (
    trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name :
    module.github_integration[0].integration_name
  ) : ""

  active_integrations = compact([
    local.resolved_github_integration_name,
    local.resolved_linear_integration_name,
    local.resolved_slack_integration_name,
  ])

  base_always_allowed = ["web_search", "note", "read_notes", "load_skill"]
  integration_always_allowed = flatten([
    for name in local.active_integrations : [
      "${name}_test_connection",
      "${name}_execute_command",
      "${name}_execute_series",
    ]
  ])
  hitl_always_allowed = var.auto_approve_integration_tools ? concat(
    local.base_always_allowed,
    local.integration_always_allowed,
  ) : local.base_always_allowed

  auto_approve_tools = var.auto_approve_integration_tools ? concat(
    [for name in local.active_integrations : { tool = "${name}_*" }],
    [
      { tool = "note" },
      { tool = "read_notes" },
      { tool = "load_skill" },
      { tool = "web_search" },
    ],
    ) : [
    { tool = "note" },
    { tool = "read_notes" },
    { tool = "load_skill" },
  ]
}

resource "terraform_data" "preconditions" {
  lifecycle {
    precondition {
      condition     = local.want_github || local.want_linear
      error_message = "board-sdlc-assistant requires at least one tracker adapter: GitHub Projects or Linear."
    }
    precondition {
      condition     = !var.enable_github_webhook || trimspace(var.default_project_url) != ""
      error_message = "default_project_url is required when enable_github_webhook is true."
    }
    precondition {
      condition     = !var.enable_linear_webhook || trimspace(var.default_team_key) != ""
      error_message = "default_team_key is required when enable_linear_webhook is true."
    }
    precondition {
      condition     = !local.want_github || trimspace(local.resolved_github_integration_name) != ""
      error_message = "GitHub support requires github_secret_id or existing_github_integration_name."
    }
    precondition {
      condition     = !local.want_linear || trimspace(local.resolved_linear_integration_name) != ""
      error_message = "Linear support requires linear_api_key, linear_secret_id, linear_credential_provider_id, or existing_linear_integration_name."
    }
    precondition {
      condition     = !var.enable_slack_notify || (trimspace(local.resolved_slack_integration_name) != "" && trimspace(var.slack_notify_channel) != "")
      error_message = "Slack notify requires a Slack integration and slack_notify_channel."
    }
  }
}

module "linear_integration" {
  count  = local.provision_linear ? 1 : 0
  source = "./modules/linear-integration"

  integration_name       = local.linear_integration_name
  linear_api_key         = var.linear_api_key
  existing_secret_id     = var.linear_secret_id
  credential_provider_id = var.linear_credential_provider_id
  description            = "Linear tracker adapter for ${local.agent_name}."
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "./modules/slack-integration"

  integration_name   = local.slack_integration_name
  slack_bot_token    = var.slack_bot_token
  existing_secret_id = var.slack_secret_id
  description        = "Notify-only Slack integration for ${local.agent_name}."
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "./modules/github-integration"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub tracker/repository adapter for ${local.agent_name}."
}

resource "sg_agent" "board_sdlc_assistant" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/github-project-assistant.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = local.hitl_always_allowed
  }
  auto_approve_tools = local.auto_approve_tools
  integrations       = local.active_integrations

  lifecycle {
    ignore_changes = [auto_approve_tools, hitl]
  }
}

resource "sg_agent_budget" "board_sdlc_assistant" {
  agent_name  = sg_agent.board_sdlc_assistant.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_policy" "guardrails" {
  name        = "linear-board-assistant-guardrails${local.suffix}"
  description = "Tracker-neutral SDLC safety: durable receipts, one-step transitions, human merge, and notify-only Slack."
  type        = "intervention"
  rego_source = file("${path.module}/policies/board-sdlc-assistant-guardrails.rego")
}

resource "sg_agent_policy_attachment" "guardrails" {
  agent_name = sg_agent.board_sdlc_assistant.name
  policy_id  = sg_policy.guardrails.id
  enabled    = true
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  count = trimspace(try(var.policy_ids.dangerous_ops, "")) != "" ? 1 : 0

  agent_name = sg_agent.board_sdlc_assistant.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}
