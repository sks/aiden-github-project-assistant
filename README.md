# Aiden Board SDLC Assistant

OpenTofu / Terraform module for one stable SDLC loop:

**Specify → Research → Plan → optional review PR → Done after human merge**

The persona is the durable DNA. Trackers are adapters:

- **GitHub Projects:** Project Status is the stage; issue comments are evidence.
- **Linear:** workflow state is the stage; Linear comments are evidence.
- **Slack:** notify-only after evidence is durable. It is never the board or trigger.
- **Jira tomorrow:** add an adapter implementing read → comment → one-step transition; do not rewrite the persona.

Both GitHub Projects and Linear can be enabled on the same deployed agent. Each webhook selects its adapter, and a run updates only that tracker.

This is a community/personal module under [`sks`](https://github.com/sks), not an official StackGen product repo. It is self-contained: Linear, Slack, GitHub, and schedule modules live under [`modules/`](modules/) with no dependency on `appcd-dev/solutions`.

## Prerequisites

- Active Aiden / StackGen tenant
- OpenTofu ≥ 1.5 and StackGen provider `>= 0.1.33, != 0.1.35, < 0.2.0`
- GitHub PAT with `repo`, `read:project`, and `project` for GitHub Projects / repository research / PRs
- Linear API key or OAuth credential provider when enabling Linear
- Optional Slack bot token and channel for notifications
- Tracker stages named Specify / Research / Plan / Done, or a custom `stage_names` map shared by that module instance

## Easy path: both trackers

```hcl
module "board_sdlc_assistant" {
  source = "github.com/sks/aiden-github-project-assistant//wrappers/all-in-one?ref=v0.2.0"

  openai_api_key = var.openai_api_key
  github_token   = var.github_token
  linear_api_key = var.linear_api_key

  # GitHub Projects adapter
  enable_github_webhook = true
  default_project_url   = "https://github.com/users/YOU/projects/1"

  # Linear adapter
  enable_linear_webhook = true
  default_team_key      = "CORE"

  # Shared behavior
  enable_implement = true
  webhook_repository_full_names = ["YOU/your-repo"]

  # Optional notify-only Slack
  enable_slack_notify  = true
  slack_bot_token      = var.slack_bot_token
  slack_notify_channel = "#aiden-sdlc"

  webhook_trigger_base_url = "${var.stackgen_url}/guild"
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

Runnable dogfood: [`examples/complete`](examples/complete/).

## Composable path

Reuse existing tenant integrations:

```hcl
module "board_sdlc_assistant" {
  source = "github.com/sks/aiden-github-project-assistant?ref=v0.2.0"

  model_names                       = module.foundation.model_names
  existing_github_integration_name = module.github.integration_name
  existing_linear_integration_name = module.linear.integration_name
  existing_slack_integration_name  = module.slack.integration_name

  enable_github_webhook = true
  default_project_url   = "https://github.com/orgs/acme/projects/5"

  enable_linear_webhook = true
  default_team_key      = "CORE"

  enable_slack_notify  = true
  slack_notify_channel = "#aiden-sdlc"
}
```

## Architecture

| Layer | Stable or adapter-specific? | Responsibility |
|---|---|---|
| `personas/github-project-assistant.md` | Stable DNA (legacy filename retained) | Stage meaning, receipts, HITL, human merge, grounding |
| `github_adapter.tf` + GitHub runbook | Adapter | Issue comments, Projects v2 Status, GitHub webhooks/poll |
| `linear_adapter.tf` + Linear runbook | Adapter | Linear comments, workflow states, Linear webhook |
| Slack integration | Cross-cutting notify | Short receipt only after tracker write succeeds |
| Future Jira adapter | Adapter | Same read/comment/transition contract |

## Trigger map

| Human gesture | Workflow |
|---|---|
| GitHub issue opened | GitHub Projects adapter |
| GitHub Project card moved | GitHub status poll (Projects v2 does not emit an Issues event) |
| Linear issue created/state moved | Linear webhook |
| GitHub PR merged for a GitHub-backed item | GitHub Projects Done webhook |
| GitHub PR merged for a Linear-backed item | Linear Done webhook |
| Slack message | Not a trigger |

When both trackers are enabled, register both adapter-specific PR webhook URLs because each routes Done evidence to a different tracker.

## Board rules

| Do | Don't |
|---|---|
| Process one work item per run | Mix tracker state in one run |
| Put evidence on the selected tracker | Keep findings only in chat/Slack |
| Move one stage after successful work | Jump Specify → Done |
| Let humans merge review PRs | Auto-merge |
| Add future trackers as adapters | Fork the persona per tracker |

## Versioning

- `v0.1.0`: GitHub Projects-only implementation.
- `v0.2.0`: shared tracker-neutral persona with GitHub Projects + Linear adapters and notify-only Slack.

## License

Apache-2.0. See [LICENSE](LICENSE).
