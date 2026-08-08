package policy

import rego.v1

default approval_required := false

tool_name := input.tool.name

# Adapter reads/comments/transitions, Slack notify, create_agent, and runbook-gated
# PR creation are allowed. Destructive shell, merge, and CI dispatch require HITL.
approval_required if {
	contains(tool_name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	some pattern in destructive_patterns
	contains(cmd, pattern)
}

destructive_patterns := {
	"rm -rf",
	"rm -fr",
	"terraform destroy",
	"tofu destroy",
	"kubectl delete",
	"helm uninstall",
	"helm delete",
	"drop table",
	"drop database",
	"truncate ",
	"dd if=",
	"> /dev/",
	"mkfs",
	"--force-delete",
	"git push --force",
	"git push -f ",
	"gh pr merge",
	"gh workflow run",
}

approval_reason := "board-sdlc-assistant guardrails: destructive or merge/CI command requires human approval" if {
	approval_required
}
