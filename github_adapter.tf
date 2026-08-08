locals {
  # `github-project-item-assist` is already used by the original v0.1 dogfood
  # deployment in this tenant. Keep adapter names distinct so both can coexist.
  github_workflow_name = "github-project-adapter-assist${local.suffix}"
  github_sop_name      = "github-project-adapter-assist${local.suffix}"
  github_webhook_name  = "github-project-adapter-issues${local.suffix}"
  github_pr_name       = "github-project-adapter-prs${local.suffix}"

  github_repo_allowlist = [
    for repository in var.webhook_repository_full_names :
    trimspace(repository) if trimspace(repository) != ""
  ]
  github_allowlist_text = length(local.github_repo_allowlist) == 0 ? "any repository" : join(", ", local.github_repo_allowlist)
  enable_github_pr_webhook = (
    var.enable_github_webhook &&
    var.enable_implement &&
    var.enable_pr_merged_webhook
  )
}

resource "sg_runbook_sop" "github_project_item_assist" {
  count = local.want_github ? 1 : 0

  name    = local.github_sop_name
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
    enable_slack_notify  = var.enable_slack_notify
    slack_notify_channel = trimspace(var.slack_notify_channel)
  }))
}

resource "sg_workflow" "github_project_item_assist" {
  count = local.want_github ? 1 : 0

  name        = local.github_workflow_name
  domain      = "software-engineering"
  description = trimspace(file("${path.module}/templates/workflow-github-project-item-assist.md"))
  approve     = true

  required_inputs = ["project_url", "issue_number"]
  optional_inputs = ["tracker_type", "repository", "auto_advance", "sdlc_chain", "pr_merged", "pull_request_number"]

  example_queries = [
    "Assist GitHub Project https://github.com/orgs/acme/projects/5 issue 42",
    "Full SDLC chain on project https://github.com/users/sks/projects/1 issue 29",
    "Mark Done after PR merged for project issue 29",
  ]

  stages = [{
    stage_id    = "assist_item"
    description = "Run tracker-neutral SDLC through the GitHub Projects adapter."
    required    = true
  }]

  stage_bindings = [{
    stage_id     = "assist_item"
    agent_ref    = sg_agent.board_sdlc_assistant.name
    runbook_refs = [sg_runbook_sop.github_project_item_assist[0].name]
    skill_refs   = try(var.workflow_skill_refs["${local.github_workflow_name}::assist_item"], [])
  }]
}

resource "sg_webhook" "github_project_item_assist" {
  count = var.enable_github_webhook ? 1 : 0

  name           = local.github_webhook_name
  target_type    = "workflow"
  target_name    = sg_workflow.github_project_item_assist[0].name
  enabled        = true
  token_rotation = "${var.webhook_token_rotation}-github"

  action = <<-EOT
    GitHub issue opened event. Set tracker_type=github-project and process exactly one
    issue. Extract repository.full_name and issue.number; project_url defaults to
    ${trimspace(var.default_project_url)}. Repository allowlist: ${local.github_allowlist_text}.
    Add a missing item to the Project at ${var.stage_names.specify}; then run with
    auto_advance=${var.webhook_auto_advance}, sdlc_chain=${var.sdlc_chain}.
    Evidence and transitions stay in GitHub issue comments and Project Status.
  EOT
}

resource "sg_webhook" "github_project_item_assist_prs" {
  count = local.enable_github_pr_webhook ? 1 : 0

  name           = local.github_pr_name
  target_type    = "workflow"
  target_name    = sg_workflow.github_project_item_assist[0].name
  enabled        = true
  token_rotation = "${var.webhook_token_rotation}-github-prs"

  action = <<-EOT
    GitHub pull_request closed event for a GitHub-Project-backed issue. Proceed only
    when merged. Resolve the linked issue and Project, set tracker_type=github-project,
    pr_merged=true, auto_advance=true, sdlc_chain=false. Verify repository against
    ${local.github_allowlist_text}. Post Done evidence on the issue and transition
    Project Status to ${coalesce(try(var.stage_names.done, null), "Done")}. Never merge.
  EOT
}

module "github_status_poll" {
  count  = var.enable_status_poll_schedule && var.enable_github_webhook ? 1 : 0
  source = "./modules/schedules"

  target_type = "workflow"
  target_name = sg_workflow.github_project_item_assist[0].name
  schedules = [{
    name       = "github-project-status-poll${local.suffix}"
    expression = var.status_poll_cron
    enabled    = true
    action     = "Process at most one eligible item in ${trimspace(var.default_project_url)}: merged Implement PR missing Done first, otherwise ${var.stage_names.plan}/${var.stage_names.research} item missing its receipt. Use tracker_type=github-project."
  }]
}
