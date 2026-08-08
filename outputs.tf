output "agent_name" {
  description = "Aiden name of the linear-board-assistant agent."
  value       = sg_agent.linear_board_assistant.name
}

output "workflow_name" {
  description = "Name of the linear-item-assist workflow."
  value       = sg_workflow.item_assist.name
}

output "runbook_name" {
  description = "Runbook SOP name for one-issue Linear assist."
  value       = sg_runbook_sop.item_assist.name
}

output "linear_integration_name" {
  description = "Resolved Linear Aiden integration name."
  value       = nonsensitive(local.resolved_linear_integration_name)
}

output "slack_integration_name" {
  description = "Resolved Slack Aiden integration name (empty when notify disabled)."
  value       = nonsensitive(local.resolved_slack_integration_name)
}

output "github_integration_name" {
  description = "Resolved GitHub Aiden integration name (empty when GitHub disabled)."
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "policy_ids" {
  description = "Policy IDs owned by this module."
  value = {
    guardrails = sg_policy.guardrails.id
  }
}

output "stage_names" {
  description = "Configured Linear workflow state names for Specify / Research / Plan / Done."
  value       = var.stage_names
}

output "default_team_key" {
  description = "Default Linear team key used for webhook-triggered runs."
  value       = var.default_team_key
}

output "slack_notify_channel" {
  description = "Slack channel receiving stage receipts (empty when notify disabled)."
  value       = var.enable_slack_notify ? var.slack_notify_channel : ""
}

# --- Linear webhook ---------------------------------------------------------

output "linear_webhook_id" {
  description = "ID of the Linear webhook ingress. Empty when enable_linear_webhook is false."
  value       = try(sg_webhook.linear_item_assist[0].id, "")
}

output "linear_webhook_token" {
  description = "Secret token for the Linear webhook ingress. Empty when disabled."
  value       = try(sg_webhook.linear_item_assist[0].token, "")
  sensitive   = true
}

output "linear_webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL for the Linear webhook (paste into Linear webhook settings). Null when disabled or URL/token missing."
  sensitive   = true
  value = (
    var.enable_linear_webhook && trimspace(var.webhook_trigger_base_url) != "" && try(sg_webhook.linear_item_assist[0].token, null) != null && trimspace(sg_webhook.linear_item_assist[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.linear_item_assist[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

# --- PR-merge webhook -------------------------------------------------------

output "pr_webhook_id" {
  description = "ID of the pull_request merge webhook ingress. Empty when disabled."
  value       = try(sg_webhook.linear_item_assist_prs[0].id, "")
}

output "pr_webhook_token" {
  description = "Secret token for the PR-merge webhook ingress. Empty when disabled."
  value       = try(sg_webhook.linear_item_assist_prs[0].token, "")
  sensitive   = true
}

output "pr_webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL for the PR-merge webhook (GitHub Payload URL). Null when disabled."
  sensitive   = true
  value = (
    local.enable_pr_merged && trimspace(var.webhook_trigger_base_url) != "" && try(sg_webhook.linear_item_assist_prs[0].token, null) != null && trimspace(sg_webhook.linear_item_assist_prs[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.linear_item_assist_prs[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "webhook_trigger_endpoint" {
  description = "Non-sensitive POST …/api/v1/webhooks/trigger URL when webhook_trigger_base_url is set; empty otherwise."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

# --- Behavior flags ---------------------------------------------------------

output "sdlc_chain" {
  description = "Whether webhook/poll runs chain Specify → Research → Plan in one execution."
  value       = var.sdlc_chain
}

output "enable_implement" {
  description = "Whether Plan is followed by a GitHub PR implement step."
  value       = var.enable_implement
}

output "enable_slack_notify" {
  description = "Whether the agent posts stage receipts to Slack."
  value       = var.enable_slack_notify
}

output "merge_poll_enabled" {
  description = "True when the merge-safety poll schedule is instantiated."
  value       = var.enable_status_poll_schedule && var.enable_implement
}
