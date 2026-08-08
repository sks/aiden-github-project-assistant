# =============================================================================
# Linear Board Assistant — one Linear issue, one stage, optional one state hop.
#
# Board of truth: Linear (workflow state + issue comments).
# Notify only: Slack (short stage receipt; never a trigger, never source of truth).
# Optional implement: GitHub PR (agent opens; a human merges). Done after merge.
#
# No Fabrik, Claude CLI, Cursor, Ubuntu, or remote runner.
# =============================================================================

locals {
  module_prefix = "linear-board-assistant"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name          = "${local.module_prefix}${local.suffix}"
  workflow_name       = "linear-item-assist${local.suffix}"
  sop_name            = "linear-item-assist${local.suffix}"
  linear_webhook_name = "linear-item-assist-issues${local.suffix}"
  pr_webhook_name     = "linear-item-assist-prs${local.suffix}"

  # --- Linear integration (required) ---------------------------------------
  provision_linear        = trimspace(var.existing_linear_integration_name) == ""
  linear_integration_name = "${local.module_prefix}-linear${local.suffix}"
  resolved_linear_integration_name = trimspace(var.existing_linear_integration_name) != "" ? var.existing_linear_integration_name : (
    local.provision_linear ? module.linear_integration[0].integration_name : ""
  )

  # --- Slack integration (notify only, optional) ----------------------------
  want_slack             = var.enable_slack_notify
  provision_slack        = local.want_slack && trimspace(var.existing_slack_integration_name) == ""
  slack_integration_name = "${local.module_prefix}-slack${local.suffix}"
  resolved_slack_integration_name = local.want_slack ? (
    trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
      local.provision_slack ? module.slack_integration[0].integration_name : ""
    )
  ) : ""

  # --- GitHub integration (Research + optional implement PR) ----------------
  want_github             = var.enable_github || var.enable_implement
  provision_github        = local.want_github && trimspace(var.existing_github_integration_name) == ""
  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  resolved_github_integration_name = local.want_github ? (
    trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
      local.provision_github ? module.github_integration[0].integration_name : ""
    )
  ) : ""

  enable_pr_merged = var.enable_implement && var.enable_pr_merged_webhook && trimspace(local.resolved_github_integration_name) != ""

  webhook_repo_allowlist = [
    for r in var.webhook_repository_full_names : trimspace(r) if trimspace(r) != ""
  ]
  webhook_allowlist_text = length(local.webhook_repo_allowlist) == 0 ? "any repository" : join(", ", local.webhook_repo_allowlist)

  label_gate_text = trimspace(var.linear_trigger_label) == "" ? "any issue on the team" : "only issues labelled ${trimspace(var.linear_trigger_label)}"

  # --- Tool approval surfaces ----------------------------------------------
  active_integrations = compact([
    local.resolved_linear_integration_name,
    local.resolved_slack_integration_name,
    local.resolved_github_integration_name,
  ])

  base_always_allowed = ["web_search", "note", "read_notes", "load_skill"]
  integration_always_allowed = flatten([
    for n in local.active_integrations : [
      "${n}_test_connection",
      "${n}_execute_command",
      "${n}_execute_series",
    ]
  ])
  hitl_always_allowed = var.auto_approve_integration_tools ? concat(local.base_always_allowed, local.integration_always_allowed) : local.base_always_allowed

  auto_approve_tools = var.auto_approve_integration_tools ? concat(
    [for n in local.active_integrations : { tool = "${n}_*" }],
    [{ tool = "note" }, { tool = "read_notes" }, { tool = "load_skill" }, { tool = "web_search" }],
    ) : [
    { tool = "note" }, { tool = "read_notes" }, { tool = "load_skill" },
  ]

  stage_skill_refs = try(var.workflow_skill_refs["${local.workflow_name}::assist_item"], [])
}

resource "terraform_data" "preconditions" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_linear_integration_name) != ""
      error_message = "linear-board-assistant needs a Linear Aiden integration: provide `linear_api_key` / `linear_secret_id` / `linear_credential_provider_id` (module provisions one) or `existing_linear_integration_name`."
    }
    precondition {
      condition     = !var.enable_linear_webhook || trimspace(var.default_team_key) != ""
      error_message = "linear-board-assistant: default_team_key is required when enable_linear_webhook is true."
    }
    precondition {
      condition     = !var.enable_slack_notify || trimspace(local.resolved_slack_integration_name) != ""
      error_message = "linear-board-assistant: enable_slack_notify requires a Slack integration (slack_bot_token / slack_secret_id / existing_slack_integration_name)."
    }
    precondition {
      condition     = !var.enable_slack_notify || trimspace(var.slack_notify_channel) != ""
      error_message = "linear-board-assistant: slack_notify_channel is required when enable_slack_notify is true."
    }
    precondition {
      condition     = !var.enable_implement || trimspace(local.resolved_github_integration_name) != ""
      error_message = "linear-board-assistant: enable_implement requires a GitHub integration (github_secret_id / existing_github_integration_name)."
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
  description            = "Linear integration for ${local.agent_name} (workflow state + issue comments)."
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "./modules/slack-integration"

  integration_name   = local.slack_integration_name
  slack_bot_token    = var.slack_bot_token
  existing_secret_id = var.slack_secret_id
  description        = "Slack notifications for ${local.agent_name} stage receipts."
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "./modules/github-integration"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration for ${local.agent_name} (Research repo APIs + optional implement PR)."
}

resource "sg_agent" "linear_board_assistant" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/linear-board-assistant.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = local.hitl_always_allowed
  }

  auto_approve_tools = local.auto_approve_tools

  integrations = local.active_integrations

  # Provider UpdateAgent 400s when reconciling auto_approve / HITL wildcards
  # against a live agent that already has integration_* entries. Persona/integrations
  # still update; patch HITL via API if those must change.
  lifecycle {
    ignore_changes = [auto_approve_tools, hitl]
  }
}

resource "sg_agent_budget" "linear_board_assistant" {
  agent_name  = sg_agent.linear_board_assistant.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_policy" "guardrails" {
  name        = "linear-board-assistant-guardrails${local.suffix}"
  description = "Requires HITL for destructive shell and merge/CI; allows Linear comment/state + Slack notify; PR create is runbook-gated via enable_implement."
  type        = "intervention"
  rego_source = file("${path.module}/policies/linear-board-assistant-guardrails.rego")
}

resource "sg_agent_policy_attachment" "guardrails" {
  agent_name = sg_agent.linear_board_assistant.name
  policy_id  = sg_policy.guardrails.id
  enabled    = true
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  count = trimspace(try(var.policy_ids.dangerous_ops, "")) != "" ? 1 : 0

  agent_name = sg_agent.linear_board_assistant.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_runbook_sop" "item_assist" {
  name    = local.sop_name
  approve = true
  description = trimspace(templatefile("${path.module}/templates/linear-item-assist.md", {
    stage_specify        = var.stage_names.specify
    stage_research       = var.stage_names.research
    stage_plan           = var.stage_names.plan
    stage_done           = coalesce(try(var.stage_names.done, null), "Done")
    default_team_key     = trimspace(var.default_team_key)
    trigger_label        = trimspace(var.linear_trigger_label)
    webhook_auto_advance = var.webhook_auto_advance
    sdlc_chain           = var.sdlc_chain
    enable_implement     = var.enable_implement
    enable_slack_notify  = var.enable_slack_notify
    slack_notify_channel = trimspace(var.slack_notify_channel)
  }))
}

resource "sg_workflow" "item_assist" {
  name        = local.workflow_name
  domain      = "software-engineering"
  description = trimspace(file("${path.module}/templates/workflow-linear-item-assist.md"))
  approve     = true

  required_inputs = ["linear_issue_id"]
  optional_inputs = ["linear_identifier", "linear_issue_title", "linear_issue_body", "linear_state", "team_key", "repository", "auto_advance", "sdlc_chain", "pr_merged", "pull_request_number"]

  example_queries = [
    "Assist Linear issue CORE-42 (Specify then chain)",
    "Run Specify on Linear SKS-18 (auto_advance false)",
    "Research then comment on Linear CORE-7",
    "Full SDLC chain on Linear SKS-29",
    "Mark Done after PR merged for Linear SKS-29",
  ]

  stages = [
    {
      stage_id    = "assist_item"
      description = "Board SDLC for one Linear issue: Specify/Research/Plan (optional chain), Linear comments, state hops; optional GitHub PR after Plan; Done when PR merges. Slack notify after each stage when enabled."
      required    = true
    },
  ]

  stage_bindings = [
    {
      stage_id     = "assist_item"
      agent_ref    = sg_agent.linear_board_assistant.name
      runbook_refs = [sg_runbook_sop.item_assist.name]
      skill_refs   = local.stage_skill_refs
    },
  ]
}

# =============================================================================
# Linear webhook ingress — Issue create / update (board motion)
# =============================================================================

resource "sg_webhook" "linear_item_assist" {
  count = var.enable_linear_webhook ? 1 : 0

  name           = local.linear_webhook_name
  target_type    = "workflow"
  target_name    = sg_workflow.item_assist.name
  enabled        = true
  token_rotation = var.webhook_token_rotation

  action = <<-EOT
    A Linear webhook arrived (type Issue; action create or update).
    Normalize the payload and start linear-item-assist for exactly one issue.

    Extract from data:
      - linear_issue_id   = data.id
      - linear_identifier = data.identifier
      - linear_issue_title = data.title
      - linear_issue_body  = data.description
      - linear_state       = data.state.name
      - team_key           = data.team.key (fallback ${trimspace(var.default_team_key)})
      - labels             = data.labels[].name

    Label gate: ${local.label_gate_text}.
    If a trigger label is configured and the issue does not carry it, stop without running a stage.

    Ignore noise: comment-only events, remove actions, and updates that do not change the
    workflow state or create the issue.

    - action create: treat as a new issue. If its state is not one of the board states,
      move it to ${var.stage_names.specify} and run Specify. Then chain when sdlc_chain is true.
    - action update where the workflow state changed: run the stage matching the new state
      (${var.stage_names.specify} / ${var.stage_names.research} / ${var.stage_names.plan}).

    Set auto_advance = ${var.webhook_auto_advance} and sdlc_chain = ${var.sdlc_chain} unless overridden.
    When implement is enabled (${var.enable_implement}): after Plan, open a GitHub PR that implements the plan.
    Do not merge the PR. After a human merges, a separate PR webhook / poll moves the state to ${coalesce(try(var.stage_names.done, null), "Done")}.
  EOT
}

# =============================================================================
# GitHub PR-merge webhook → Done (Linear does not see GitHub merges)
# =============================================================================

resource "sg_webhook" "linear_item_assist_prs" {
  count = local.enable_pr_merged ? 1 : 0

  name           = local.pr_webhook_name
  target_type    = "workflow"
  target_name    = sg_workflow.item_assist.name
  enabled        = true
  token_rotation = "${var.webhook_token_rotation}-prs"

  action = <<-EOT
    A GitHub pull_request event arrived (closed / merged).
    Only proceed when the PR is merged (merged=true or pull_request.merged_at set). Ignore pure closes,
    reviews, and synchronize noise.

    Extract:
      - repository          = repository.full_name
      - pull_request_number = pull_request.number
      - linear_issue_id     = the Linear issue referenced by the PR — from the PR body magic word
        (Fixes|Closes|Refs <Linear URL or identifier>), the branch name (e.g. sks-29-…), or the
        "### Aiden linear assist — Implement" Linear comment that cites this PR URL
      - pr_merged           = true
      - auto_advance        = true
      - sdlc_chain          = false

    Repository allowlist: ${local.webhook_allowlist_text}.
    If the allowlist is not "any repository" and repository is not on it, stop.

    Run linear-item-assist Done completion only: hop the Linear state to ${coalesce(try(var.stage_names.done, null), "Done")},
    post "### Aiden linear assist — Done" on the Linear issue. Do not open another PR. Do not merge (already merged).
  EOT
}

# =============================================================================
# Optional fallback poll — catch a missed GitHub PR-merge webhook.
# Linear state drags DO fire webhooks, so this is a merge-safety net only.
# =============================================================================

module "status_poll" {
  count  = var.enable_status_poll_schedule && var.enable_implement ? 1 : 0
  source = "./modules/schedules"

  target_type = "workflow"
  target_name = sg_workflow.item_assist.name

  schedules = [
    {
      name       = "linear-board-merge-poll${local.suffix}"
      expression = var.status_poll_cron
      enabled    = true
      action     = <<-EOT
        Merge-safety poll for Linear team ${trimspace(var.default_team_key)}.
        List issues still in state ${var.stage_names.plan} that have an
        "### Aiden linear assist — Implement" comment citing a PR URL whose PR is already merged,
        and that do not yet have "### Aiden linear assist — Done".
        For each (at most one per poll), run linear-item-assist with:
          linear_issue_id = <picked>
          pr_merged = true
          pull_request_number = <merged PR>
          auto_advance = true
          sdlc_chain = false
        If no eligible issue, reply "merge poll: idle" and stop.
      EOT
    },
  ]
}
