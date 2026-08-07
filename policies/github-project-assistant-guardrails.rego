package policy

import rego.v1

default approval_required := false

tool_name := input.tool.name

# Destructive shell and merge/CI remain HITL. `gh pr create` is allowed when
# enable_implement is on (runbook-gated); keep it ungated here so SDLC can open PRs.
# create_agent is allowed (ReAcTree); do not gate it here.
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

approval_reason := "github-project-assistant guardrails: destructive or merge/CI command requires human approval" if {
	approval_required
}
