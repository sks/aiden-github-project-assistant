variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Optional shared policy IDs. When dangerous_ops is set, it is attached in addition to this module's guardrails (aios-policies no longer always exports dangerous_ops)."
  type = object({
    dangerous_ops = optional(string, "")
  })
  default = {}
}

variable "github_secret_id" {
  description = <<-EOT
    Optional `sg_secret` ID holding the GitHub PAT. When set (and
    `existing_github_integration_name` is empty), this module provisions an
    internal GitHub Aiden integration. Prefer `existing_github_integration_name`
    when the root already created a GitHub Aiden integration.
    PAT needs `repo` plus Projects v2 scopes `read:project` and `project`.
    Missing project scopes make `gh api graphql` exit 1 with opaque sidecar errors.
  EOT
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional Aiden integration name to share an existing GitHub integration instead of provisioning one."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix appended to agent / workflow / runbook / integration resource names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

variable "agent_budget" {
  description = "Daily USD budget for the github-project-assistant agent."
  type        = number
  default     = 8
}

variable "auto_approve_github_tools" {
  description = <<-EOT
    When true, allow GitHub `test_connection` and `execute_command` without HITL
    so the agent can run bounded `gh api graphql` / issue-comment calls. Destructive
    shell patterns remain blocked by the module guardrails policy.
  EOT
  type        = bool
  default     = true
}

variable "stage_names" {
  description = <<-EOT
    Map of logical stage keys to GitHub Project Status column names. Defaults
    match Specify → Research → Plan → Done. Create a Done column on the Project
    before enabling PR-merge completion.
  EOT
  type = object({
    specify  = string
    research = string
    plan     = string
    done     = optional(string, "Done")
  })
  default = {
    specify  = "Specify"
    research = "Research"
    plan     = "Plan"
    done     = "Done"
  }
}

variable "workflow_skill_refs" {
  description = "Optional extra skill_refs keyed by `<workflow>::<stage>`."
  type        = map(list(string))
  default     = {}
}

# ---------------------------------------------------------------------------
# Optional GitHub issue.created webhook ingress
# ---------------------------------------------------------------------------

variable "enable_github_webhook" {
  description = "When true, creates sg_webhook targeting github-project-item-assist for GitHub issue opened events."
  type        = bool
  default     = false
}

variable "webhook_token_rotation" {
  description = "Token rotation marker for sg_webhook. Change to force a new webhook token."
  type        = string
  default     = "v1"
}

variable "default_project_url" {
  description = <<-EOT
    GitHub Projects v2 URL used when the workflow is started from a webhook
    (issue payloads do not include the Project). Required when
    `enable_github_webhook` is true. Example: `https://github.com/users/sks/projects/1`.
  EOT
  type        = string
  default     = ""
}

variable "webhook_repository_full_names" {
  description = <<-EOT
    Optional allowlist of `owner/name` repositories. When non-empty, webhook runs
    must ignore issues outside this list. Empty means any repository is accepted.
  EOT
  type        = list(string)
  default     = []
}

variable "webhook_auto_advance" {
  description = "When true, webhook-triggered runs set auto_advance=true so Status hops one column after a successful stage."
  type        = bool
  default     = true
}

variable "sdlc_chain" {
  description = <<-EOT
    When true, after a successful stage the run continues through the board
    (Specify → Research → Plan) with Status hops between stages, instead of
    stopping after one column. Webhook and status-poll runs should set this true
    for full board SDLC. Chat can override via input `sdlc_chain`.
  EOT
  type        = bool
  default     = true
}

variable "enable_implement" {
  description = <<-EOT
    When true, after a successful Plan stage the agent implements via GitHub
    APIs (branch + commits + `gh pr create`). Leave Status on Plan until the
    human merges; then Done completion (webhook/poll) hops to `stage_names.done`.
    Relaxes guardrails that otherwise require HITL for `gh pr create`.
  EOT
  type        = bool
  default     = false
}

variable "enable_pr_merged_webhook" {
  description = <<-EOT
    When true (and `enable_github_webhook` + `enable_implement`), creates a second
    sg_webhook for pull_request closed/merged events that runs Done completion:
    hop Project Status to Done, close the issue if still open, comment receipt.
    Register Pull request events on that ingress URL in GitHub.
  EOT
  type        = bool
  default     = true
}

variable "enable_status_poll_schedule" {
  description = <<-EOT
    When true, creates a cron schedule that scans `default_project_url` for
    Research/Plan items needing work (and Plan items whose Aiden PR is already
    merged → Done). Needed because repo Issues webhooks do not fire on Project
    Status drag, and PR-merge may be missed if the PR webhook is not registered.
  EOT
  type        = bool
  default     = false
}

variable "status_poll_cron" {
  description = "Five-field cron for the Status poll schedule (UTC). Default: every five minutes."
  type        = string
  default     = "*/5 * * * *"
}

variable "webhook_trigger_base_url" {
  description = <<-EOT
    Optional StackGen HTTP API origin (e.g. `https://ai.dev.stackgen.com`). When set,
    outputs include `webhook_trigger_endpoint` and, when the ingress token exists,
    `webhook_ingress_payload_url` for GitHub Payload URL.
  EOT
  type        = string
  default     = ""
}

variable "webhook_trigger_org_id" {
  description = "Optional orgId query on webhook_ingress_payload_url (provider project_id)."
  type        = string
  default     = ""
}
