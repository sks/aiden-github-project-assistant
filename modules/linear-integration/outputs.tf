output "integration_name" {
  value = nonsensitive(sg_guild_integration.linear.name)
}

output "integration_id" {
  value = sg_guild_integration.linear.id
}

output "secret_id" {
  description = "ID of the sg_secret bound to the Linear integration when using an API key. Empty for OAuth."
  value       = local.use_api_key ? local.secret_id : ""
  sensitive   = true
}
