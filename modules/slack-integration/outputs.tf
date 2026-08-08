output "integration_name" {
  value = nonsensitive(sg_guild_integration.slack.name)
}

output "integration_id" {
  value = sg_guild_integration.slack.id
}

output "secret_id" {
  description = "ID of the sg_secret bound to the Slack integration."
  value       = local.secret_id
  sensitive   = true
}
