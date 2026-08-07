output "agent_name" {
  value = module.github_project_assistant.agent_name
}

output "workflow_name" {
  value = module.github_project_assistant.workflow_name
}

output "webhook_ingress_payload_url" {
  value     = module.github_project_assistant.webhook_ingress_payload_url
  sensitive = true
}

output "webhook_token" {
  value     = module.github_project_assistant.webhook_token
  sensitive = true
}

output "pr_webhook_ingress_payload_url" {
  value     = module.github_project_assistant.pr_webhook_ingress_payload_url
  sensitive = true
}
