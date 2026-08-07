# =============================================================================
# GitHub Project Assistant — one item, one stage, optional one Status hop
#
# No Fabrik, Claude CLI, Cursor, Ubuntu, or remote runner. GitHub integration
# only: gh api graphql + issue comments (+ optional Projects v2 Status update).
# =============================================================================

locals {
  module_prefix = "github-project-assistant"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name       = "${local.module_prefix}${local.suffix}"
  workflow_name    = "github-project-item-assist${local.suffix}"
  sop_name         = "github-project-item-assist${local.suffix}"
  webhook_name     = "github-project-item-assist-issues${local.suffix}"
  pr_webhook_name  = "github-project-item-assist-prs${local.suffix}"
  enable_pr_merged = var.enable_github_webhook && var.enable_implement && var.enable_pr_merged_webhook

  github_integration_name = "${local.module_prefix}-github${local.suffix}"

  webhook_repo_allowlist = [
    for r in var.webhook_repository_full_names : trimspace(r) if trimspace(r) != ""
  ]
  webhook_allowlist_text = length(local.webhook_repo_allowlist) == 0 ? "any repository" : join(", ", local.webhook_repo_allowlist)

  provision_github = trimspace(var.existing_github_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )

  github_hitl_always_allowed = var.auto_approve_github_tools ? compact([
    "web_search",
    "note",
    "read_notes",
    "load_skill",
    "${local.resolved_github_integration_name}_test_connection",
    "${local.resolved_github_integration_name}_execute_command",
    "${local.resolved_github_integration_name}_execute_series",
  ]) : ["web_search", "note", "read_notes", "load_skill"]

  github_auto_approve_tools = var.auto_approve_github_tools ? [
    { tool = "${local.resolved_github_integration_name}_*" },
    { tool = "note" },
    { tool = "read_notes" },
    { tool = "load_skill" },
    { tool = "web_search" },
    ] : [
    { tool = "note" },
    { tool = "read_notes" },
    { tool = "load_skill" },
  ]

  stage_skill_refs = try(var.workflow_skill_refs["${local.workflow_name}::assist_item"], [])
}

resource "terraform_data" "github_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_github_integration_name) != ""
      error_message = "aiden-github-project-assistant needs a GitHub Aiden integration: provide `github_secret_id` (module provisions one) or `existing_github_integration_name`."
    }
    precondition {
      condition     = !(trimspace(var.github_secret_id) != "" && trimspace(var.existing_github_integration_name) != "")
      error_message = "aiden-github-project-assistant cannot accept both `github_secret_id` and `existing_github_integration_name`; pass only one."
    }
    precondition {
      condition     = !var.enable_github_webhook || trimspace(var.default_project_url) != ""
      error_message = "aiden-github-project-assistant: default_project_url is required when enable_github_webhook is true."
    }
  }
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "./modules/github-integration"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration for ${local.agent_name} (Projects v2 Status + issue comments)."
}

resource "sg_agent" "github_project_assistant" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/github-project-assistant.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = local.github_hitl_always_allowed
  }

  auto_approve_tools = local.github_auto_approve_tools

  integrations = compact([
    local.resolved_github_integration_name,
  ])

  # Provider UpdateAgent 400s when reconciling auto_approve when_args_contain / HITL wildcards
  # against a live agent that already has github-integration_* entries. Persona/integrations
  # still update; patch HITL via API if those must change.
  lifecycle {
    ignore_changes = [auto_approve_tools, hitl]
  }
}

resource "sg_agent_budget" "github_project_assistant" {
  agent_name  = sg_agent.github_project_assistant.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_policy" "guardrails" {
  name        = "github-project-assistant-guardrails${local.suffix}"
  description = "Requires HITL for destructive shell and merge/CI; PR create is runbook-gated via enable_implement."
  type        = "intervention"
  rego_source = file("${path.module}/policies/github-project-assistant-guardrails.rego")
}

resource "sg_agent_policy_attachment" "guardrails" {
  agent_name = sg_agent.github_project_assistant.name
  policy_id  = sg_policy.guardrails.id
  enabled    = true
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  count = trimspace(try(var.policy_ids.dangerous_ops, "")) != "" ? 1 : 0

  agent_name = sg_agent.github_project_assistant.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_runbook_sop" "item_assist" {
  name    = local.sop_name
  approve = true
  description = trimspace(templatefile("${path.module}/templates/github-project-item-assist.md", {
    stage_specify        = var.stage_names.specify
    stage_research       = var.stage_names.research
    stage_plan           = var.stage_names.plan
    stage_done           = coalesce(try(var.stage_names.done, null), "Done")
    default_project_url  = trimspace(var.default_project_url)
    webhook_auto_advance = var.webhook_auto_advance
    sdlc_chain           = var.sdlc_chain
    enable_implement     = var.enable_implement
  }))
}

resource "sg_workflow" "item_assist" {
  name        = local.workflow_name
  domain      = "software-engineering"
  description = trimspace(file("${path.module}/templates/workflow-github-project-item-assist.md"))
  approve     = true

  required_inputs = ["project_url", "issue_number"]
  optional_inputs = ["repository", "auto_advance", "sdlc_chain", "pr_merged", "pull_request_number"]

  example_queries = [
    "Assist GitHub Project https://github.com/orgs/acme/projects/5 issue 42",
    "Run Specify on project https://github.com/orgs/acme/projects/5 issue #18 (auto_advance false)",
    "Research then comment on issue 7 in https://github.com/orgs/acme/projects/3",
    "Full SDLC chain on project https://github.com/users/sks/projects/1 issue 29",
    "Mark Done after PR merged for project https://github.com/users/sks/projects/1 issue 29",
  ]

  stages = [
    {
      stage_id    = "assist_item"
      description = "Board SDLC for one issue: Specify/Research/Plan (optional chain), comments, Status hops; optional GitHub PR after Plan; Done when PR merges."
      required    = true
    },
  ]

  stage_bindings = [
    {
      stage_id     = "assist_item"
      agent_ref    = sg_agent.github_project_assistant.name
      runbook_refs = [sg_runbook_sop.item_assist.name]
      skill_refs   = local.stage_skill_refs
    },
  ]
}

# =============================================================================
# Webhook ingress — GitHub issue.created / issues.opened
# =============================================================================

resource "sg_webhook" "github_project_item_assist" {
  count = var.enable_github_webhook ? 1 : 0

  name           = local.webhook_name
  target_type    = "workflow"
  target_name    = sg_workflow.item_assist.name
  enabled        = true
  token_rotation = var.webhook_token_rotation

  action = <<-EOT
    A GitHub issue was opened (normalized events issue.created / issues.opened).
    Normalize the payload and start github-project-item-assist for exactly one issue.

    Extract:
      - repository = repository.full_name (or repository.owner.login + "/" + repository.name)
      - issue_number = issue.number
      - project_url = ${trimspace(var.default_project_url)}
      - auto_advance = ${var.webhook_auto_advance}
      - sdlc_chain = ${var.sdlc_chain}

    Repository allowlist: ${local.webhook_allowlist_text}.
    If the allowlist is not "any repository" and repository is not on it, stop without running the stage.

    Ignore non-open / non-created issue noise (edits, closes, comments-only).
    If the issue is not yet on the Project, add it with Status ${var.stage_names.specify}, then run that stage.
    When sdlc_chain is true: after each successful stage, hop Status and continue Specify → Research → Plan in this run.
    When implement is enabled (${var.enable_implement}): after Plan, open a GitHub PR that implements the plan (no Cursor/remote-runner).
    Do not merge the PR. After humans merge, a separate PR webhook / status poll moves Status to ${coalesce(try(var.stage_names.done, null), "Done")}.
  EOT
}

# PR merge → Done (repo Issues webhooks do not see merges).
resource "sg_webhook" "github_project_item_assist_prs" {
  count = local.enable_pr_merged ? 1 : 0

  name           = local.pr_webhook_name
  target_type    = "workflow"
  target_name    = sg_workflow.item_assist.name
  enabled        = true
  token_rotation = "${var.webhook_token_rotation}-prs"

  action = <<-EOT
    A GitHub pull_request event arrived (closed / merged).
    Only proceed when the PR is merged (merged=true or pull_request.merged_at set). Ignore pure closes without merge, reviews, and synchronize noise.

    Extract:
      - repository = repository.full_name
      - pull_request_number = pull_request.number
      - issue_number = first linked issue from closing Issues / body Fixes|Refs|Closes, or from an issue comment "### Aiden project assist — Implement" that cites this PR URL
      - project_url = ${trimspace(var.default_project_url)}
      - pr_merged = true
      - auto_advance = true
      - sdlc_chain = false

    Repository allowlist: ${local.webhook_allowlist_text}.
    If the allowlist is not "any repository" and repository is not on it, stop.

    Run github-project-item-assist Done completion only: hop Project Status to ${coalesce(try(var.stage_names.done, null), "Done")}, close the issue if still open, post "### Aiden project assist — Done". Do not open another PR. Do not merge (already merged).
  EOT
}

# Status drag / missed PR webhook — poll the Project periodically.
module "status_poll" {
  count  = var.enable_status_poll_schedule && trimspace(var.default_project_url) != "" ? 1 : 0
  source = "./modules/schedules"

  target_type = "workflow"
  target_name = sg_workflow.item_assist.name

  schedules = [
    {
      name       = "github-project-status-poll${local.suffix}"
      expression = var.status_poll_cron
      enabled    = true
      action     = <<-EOT
        Status poll for Project ${trimspace(var.default_project_url)}.
        Priority 1 (Done): when enable_implement=${var.enable_implement}, list items still in Status ${var.stage_names.plan}
        that have an "### Aiden project assist — Implement" comment citing a PR URL whose PR is already merged,
        and that do not yet have "### Aiden project assist — Done". Prefer these first.
        For a Done pick, run github-project-item-assist with:
          project_url = ${trimspace(var.default_project_url)}
          issue_number = <picked>
          repository = owner/name
          pr_merged = true
          pull_request_number = <merged PR>
          auto_advance = true
          sdlc_chain = false

        Priority 2 (board SDLC): otherwise list items in Status ${var.stage_names.research} or ${var.stage_names.plan}
        missing a matching "### Aiden project assist — <Stage>" comment. Prefer Plan over Research.
        Then run with auto_advance=${var.webhook_auto_advance} sdlc_chain=${var.sdlc_chain}.
        When enable_implement=${var.enable_implement} and Status is Plan with a Plan comment but no open/merged Aiden PR yet, run Implement.

        If no eligible item, reply "status poll: idle" and stop. At most one issue per poll.
      EOT
    },
  ]
}
