variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agent (highest preference first). Forwarded to sg_agent.model_names after compact()."
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Optional shared policy IDs. When dangerous_ops is set, it is attached in addition to this module's guardrails."
  type = object({
    dangerous_ops = optional(string, "")
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Linear tracker adapter (workflow state + comments)
# ---------------------------------------------------------------------------

variable "existing_linear_integration_name" {
  description = "Optional Aiden integration name to share an existing Linear integration instead of provisioning one."
  type        = string
  default     = ""
}

variable "linear_api_key" {
  description = <<-EOT
    Linear personal API key (lin_api_…). When set (and no existing integration /
    secret / OAuth provider is passed), this module provisions an internal Linear
    Aiden integration backed by a fresh vault secret.
  EOT
  type        = string
  default     = ""
  sensitive   = true
}

variable "linear_secret_id" {
  description = "Optional pre-existing sg_secret ID holding LINEAR_API_KEY metadata. Used when provisioning a Linear integration without an inline api key."
  type        = string
  default     = ""
}

variable "linear_credential_provider_id" {
  description = "Optional StackGen Vault OAuth credential provider ID for Linear (per-user tokens). Mutually exclusive with linear_api_key / linear_secret_id."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Slack integration (notify only — not a trigger, not source of truth)
# ---------------------------------------------------------------------------

variable "enable_slack_notify" {
  description = "When true, the agent posts a short receipt to Slack after each stage. Requires a Slack integration (slack_bot_token / slack_secret_id / existing_slack_integration_name)."
  type        = bool
  default     = false
}

variable "existing_slack_integration_name" {
  description = "Optional Aiden integration name to share an existing Slack integration instead of provisioning one."
  type        = string
  default     = ""
}

variable "slack_bot_token" {
  description = "Slack Bot Token (xoxb-…). When set (and no existing integration/secret), this module provisions an internal Slack integration."
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_secret_id" {
  description = "Optional pre-existing sg_secret ID holding Slack credentials, used instead of an inline slack_bot_token."
  type        = string
  default     = ""
}

variable "slack_notify_channel" {
  description = "Slack channel name or ID that stage receipts are posted to (e.g. #aiden-sdlc or C0123ABC). Required when enable_slack_notify is true."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# GitHub integration (Research via repo APIs + optional implement PR)
# ---------------------------------------------------------------------------

variable "existing_github_integration_name" {
  description = "Optional Aiden integration name to share an existing GitHub integration instead of provisioning one."
  type        = string
  default     = ""
}

variable "github_secret_id" {
  description = <<-EOT
    Optional `sg_secret` ID holding the GitHub PAT. When set (and
    `existing_github_integration_name` is empty), this module provisions an
    internal GitHub Aiden integration for Research and (optionally) the
    implement PR. PAT needs `repo` scope.
  EOT
  type        = string
  default     = ""
}

variable "enable_github" {
  description = <<-EOT
    When true, attach a GitHub integration for Research (repo APIs) and the
    optional implement PR. Automatically treated as true when enable_implement
    is true. Provide github_secret_id or existing_github_integration_name.
  EOT
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# GitHub Projects tracker adapter
# ---------------------------------------------------------------------------

variable "enable_github_webhook" {
  description = "Create the GitHub Issues webhook that drives the GitHub Projects adapter."
  type        = bool
  default     = false
}

variable "default_project_url" {
  description = "GitHub Projects v2 URL used by webhook/status-poll runs. Required when enable_github_webhook is true."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Shared stage mapping + behavior
# ---------------------------------------------------------------------------

variable "default_team_key" {
  description = <<-EOT
    Default Linear team key (e.g. `CORE`, `SKS`) used when a webhook payload does
    not carry team context. Required when enable_linear_webhook is true.
  EOT
  type        = string
  default     = ""
}

variable "stage_names" {
  description = <<-EOT
    Map of stable SDLC stages to tracker stage names. For GitHub Projects these
    are Status option names; for Linear they are workflow state names. Deploy
    separate module instances when trackers use different names.
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

variable "linear_trigger_label" {
  description = <<-EOT
    Optional Linear label that gates webhook runs. When non-empty, the webhook
    only acts on issues carrying this label (e.g. `aiden`). Empty means any
    issue on the team is eligible.
  EOT
  type        = string
  default     = ""
}

variable "webhook_auto_advance" {
  description = "When true, webhook-triggered runs move the selected tracker one stage after successful work."
  type        = bool
  default     = true
}

variable "sdlc_chain" {
  description = <<-EOT
    When true, after a successful stage the run continues through the board
    (Specify → Research → Plan) with state hops between stages, instead of
    stopping after one state. Chat can override via input `sdlc_chain`.
  EOT
  type        = bool
  default     = true
}

variable "enable_implement" {
  description = <<-EOT
    When true, after a successful Plan stage the agent implements via GitHub
    APIs (branch + commits + `gh pr create`) and posts the PR URL as a Linear
    comment on the selected tracker. Leave its stage on Plan until the human
    merges; then Done completion hops to `stage_names.done`.
  EOT
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Linear webhook ingress
# ---------------------------------------------------------------------------

variable "enable_linear_webhook" {
  description = "When true, creates an sg_webhook targeting the workflow for Linear Issue create/update events (board motion)."
  type        = bool
  default     = false
}

variable "webhook_token_rotation" {
  description = "Token rotation marker for the Linear sg_webhook. Change to force a new webhook token."
  type        = string
  default     = "v1"
}

# ---------------------------------------------------------------------------
# GitHub PR-merge webhook → Done
# ---------------------------------------------------------------------------

variable "enable_pr_merged_webhook" {
  description = <<-EOT
    When true (and enable_implement), creates a second sg_webhook for GitHub
    pull_request closed/merged events that run adapter-specific Done completion.
    When both trackers are enabled, register both adapter PR ingress URLs.
  EOT
  type        = bool
  default     = true
}

variable "webhook_repository_full_names" {
  description = "Optional allowlist of `owner/name` repositories for the PR-merge webhook. Empty means any repository is accepted."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Optional missed-merge fallback poll (Linear webhooks cover board drags, so
# this is off by default and only guards against a missed GitHub PR webhook).
# ---------------------------------------------------------------------------

variable "enable_status_poll_schedule" {
  description = "GitHub Projects adapter poll for card drags and missed PR events (v0.1-compatible behavior)."
  type        = bool
  default     = false
}

variable "enable_linear_merge_poll_schedule" {
  description = "Linear adapter fallback poll for a missed GitHub PR-merge event. Linear board motion itself is webhook-driven."
  type        = bool
  default     = false
}

variable "status_poll_cron" {
  description = "Five-field cron for the fallback poll schedule (UTC)."
  type        = string
  default     = "*/15 * * * *"
}

# ---------------------------------------------------------------------------
# Trigger URL surfacing + misc
# ---------------------------------------------------------------------------

variable "webhook_trigger_base_url" {
  description = "Optional StackGen HTTP API origin (e.g. https://ai.dev.stackgen.com/guild). When set, outputs include ingress payload URLs for Linear/PR webhooks."
  type        = string
  default     = ""
}

variable "webhook_trigger_org_id" {
  description = "Optional orgId query on webhook ingress URLs (provider project_id)."
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
  description = "Daily USD budget for the tracker-agnostic board-sdlc-assistant agent."
  type        = number
  default     = 8
}

variable "auto_approve_integration_tools" {
  description = <<-EOT
    When true, allow the Linear / Slack / GitHub integration `test_connection`
    and `execute_command` tools without HITL so the agent can run bounded MCP /
    `gh api` calls. Destructive shell patterns remain blocked by the guardrails
    policy.
  EOT
  type        = bool
  default     = true
}

variable "workflow_skill_refs" {
  description = "Optional extra skill_refs keyed by `<workflow>::<stage>`."
  type        = map(list(string))
  default     = {}
}
