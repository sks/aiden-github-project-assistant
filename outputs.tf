output "agent_name" {
  description = "Aiden name of the github-project-assistant agent."
  value       = sg_agent.github_project_assistant.name
}

output "workflow_name" {
  description = "Name of the github-project-item-assist workflow."
  value       = sg_workflow.item_assist.name
}

output "runbook_name" {
  description = "Runbook SOP name for one-item Project assist."
  value       = sg_runbook_sop.item_assist.name
}

output "github_integration_name" {
  description = "Resolved GitHub Aiden integration name."
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "policy_ids" {
  description = "Policy IDs owned by this module."
  value = {
    guardrails = sg_policy.guardrails.id
  }
}

output "stage_names" {
  description = "Configured Project Status column names for Specify / Research / Plan / Done."
  value       = var.stage_names
}

output "pr_webhook_id" {
  description = "ID of the pull_request merge webhook ingress. Empty when disabled."
  value       = try(sg_webhook.github_project_item_assist_prs[0].id, "")
}

output "pr_webhook_token" {
  description = "Secret token for the PR-merge webhook ingress. Empty when disabled."
  value       = try(sg_webhook.github_project_item_assist_prs[0].token, "")
  sensitive   = true
}

output "pr_webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL for the PR-merge webhook (GitHub Payload URL). Null when disabled."
  sensitive   = true
  value = (
    local.enable_pr_merged && trimspace(var.webhook_trigger_base_url) != "" && try(sg_webhook.github_project_item_assist_prs[0].token, null) != null && trimspace(sg_webhook.github_project_item_assist_prs[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.github_project_item_assist_prs[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "default_project_url" {
  description = "Default Projects v2 URL used for webhook-triggered runs."
  value       = var.default_project_url
}

output "webhook_id" {
  description = "ID of the GitHub issues webhook ingress. Empty when enable_github_webhook is false."
  value       = try(sg_webhook.github_project_item_assist[0].id, "")
}

output "webhook_token" {
  description = "Secret token for the GitHub webhook ingress (GitHub Secret field). Empty when enable_github_webhook is false."
  value       = try(sg_webhook.github_project_item_assist[0].token, "")
  sensitive   = true
}

output "webhook_trigger_endpoint" {
  description = "Non-sensitive POST …/api/v1/webhooks/trigger URL when webhook_trigger_base_url is set; empty otherwise."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "webhook_ingress_payload_url" {
  description = <<-EOT
    Full StackGen trigger URL including apiKey (and optional orgId) when
    webhook_trigger_base_url is set and the ingress token is non-empty. Paste into
    GitHub Payload URL. Null when webhook is disabled or URL/token missing.
  EOT
  sensitive   = true
  value = (
    var.enable_github_webhook && trimspace(var.webhook_trigger_base_url) != "" && try(sg_webhook.github_project_item_assist[0].token, null) != null && trimspace(sg_webhook.github_project_item_assist[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.github_project_item_assist[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "sdlc_chain" {
  description = "Whether webhook/poll runs chain Specify → Research → Plan in one execution."
  value       = var.sdlc_chain
}

output "enable_implement" {
  description = "Whether Plan is followed by a GitHub PR implement step."
  value       = var.enable_implement
}

output "status_poll_enabled" {
  description = "True when the Status poll schedule module is instantiated."
  value       = var.enable_status_poll_schedule && trimspace(var.default_project_url) != ""
}
