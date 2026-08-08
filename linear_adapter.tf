locals {
  linear_workflow_name = "linear-item-assist${local.suffix}"
  linear_sop_name      = "linear-item-assist${local.suffix}"
  linear_webhook_name  = "linear-item-assist-issues${local.suffix}"
  linear_pr_name       = "linear-item-assist-prs${local.suffix}"

  linear_label_gate = trimspace(var.linear_trigger_label) == "" ? "any issue on the team" : "only issues labelled ${trimspace(var.linear_trigger_label)}"
  enable_linear_pr_webhook = (
    local.want_linear &&
    var.enable_implement &&
    var.enable_pr_merged_webhook &&
    local.want_github
  )
}

resource "sg_runbook_sop" "linear_item_assist" {
  count = local.want_linear ? 1 : 0

  name    = local.linear_sop_name
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

resource "sg_workflow" "linear_item_assist" {
  count = local.want_linear ? 1 : 0

  name        = local.linear_workflow_name
  domain      = "software-engineering"
  description = trimspace(file("${path.module}/templates/workflow-linear-item-assist.md"))
  approve     = true

  required_inputs = ["linear_issue_id"]
  optional_inputs = ["tracker_type", "linear_identifier", "linear_issue_title", "linear_issue_body", "linear_state", "team_key", "repository", "auto_advance", "sdlc_chain", "pr_merged", "pull_request_number"]

  example_queries = [
    "Assist Linear issue CORE-42",
    "Full SDLC chain on Linear SKS-29",
    "Mark Done after PR merged for Linear SKS-29",
  ]

  stages = [{
    stage_id    = "assist_item"
    description = "Run tracker-neutral SDLC through the Linear adapter."
    required    = true
  }]

  stage_bindings = [{
    stage_id     = "assist_item"
    agent_ref    = sg_agent.board_sdlc_assistant.name
    runbook_refs = [sg_runbook_sop.linear_item_assist[0].name]
    skill_refs   = try(var.workflow_skill_refs["${local.linear_workflow_name}::assist_item"], [])
  }]
}

resource "sg_webhook" "linear_item_assist" {
  count = var.enable_linear_webhook ? 1 : 0

  name           = local.linear_webhook_name
  target_type    = "workflow"
  target_name    = sg_workflow.linear_item_assist[0].name
  enabled        = true
  token_rotation = var.webhook_token_rotation

  action = <<-EOT
    Linear Issue create/update event. Set tracker_type=linear and process exactly one issue.
    Extract data.id, data.identifier, data.title, data.description, data.state.name,
    data.team.key (fallback ${trimspace(var.default_team_key)}), and data.labels[].name.
    Label gate: ${local.linear_label_gate}.
    Ignore comment-only/remove/non-state-change noise.
    On create, place unsupported initial state into ${var.stage_names.specify}; on a state
    update run the matching stage. auto_advance=${var.webhook_auto_advance};
    sdlc_chain=${var.sdlc_chain}. Evidence and transitions stay in Linear.
  EOT
}

resource "sg_webhook" "linear_item_assist_prs" {
  count = local.enable_linear_pr_webhook ? 1 : 0

  name           = local.linear_pr_name
  target_type    = "workflow"
  target_name    = sg_workflow.linear_item_assist[0].name
  enabled        = true
  token_rotation = "${var.webhook_token_rotation}-linear-prs"

  action = <<-EOT
    GitHub pull_request closed event for a Linear-backed item. Proceed only when merged.
    Resolve the Linear identifier from the PR body, branch name, or existing Implement
    receipt. Set tracker_type=linear, pr_merged=true, auto_advance=true, sdlc_chain=false.
    Verify repository against the configured allowlist. Post Done evidence and transition
    only in Linear; never merge or open another PR.
  EOT
}

module "linear_merge_poll" {
  count  = var.enable_linear_merge_poll_schedule && var.enable_implement && local.want_linear ? 1 : 0
  source = "./modules/schedules"

  target_type = "workflow"
  target_name = sg_workflow.linear_item_assist[0].name
  schedules = [{
    name       = "linear-merge-poll${local.suffix}"
    expression = var.status_poll_cron
    enabled    = true
    action     = "Find at most one ${var.stage_names.plan} Linear issue with an Aiden Implement receipt whose PR is merged and no Done receipt; run Done with tracker_type=linear. Otherwise idle."
  }]
}
