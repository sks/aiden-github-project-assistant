Use the stable Board SDLC persona through the **GitHub Projects adapter**.

Set `tracker_type=github-project`. Process exactly one GitHub issue / Project item.

## Inputs

- `project_url` — GitHub Projects v2 URL (deployment default `${default_project_url}`)
- `issue_number` — issue number
- `repository` — `owner/name`
- `auto_advance` — webhook default `${webhook_auto_advance}`
- `sdlc_chain` — deployment default `${sdlc_chain}`
- `pr_merged` / `pull_request_number` — Done-only completion after human merge

## Stage map

| Stable stage | GitHub Project Status |
|---|---|
| Specify | `${stage_specify}` |
| Research | `${stage_research}` |
| Plan | `${stage_plan}` |
| Done | `${stage_done}` |

## Adapter contract

1. Read the issue and its Project Status through GitHub REST/GraphQL. Never invent Status.
2. If an issue-created webhook item is absent from the Project, add it and set `${stage_specify}`.
3. Run the stable persona stage matching Status.
4. Post the durable receipt as a GitHub issue comment using heading `### Aiden SDLC assist — <Stage>` and `Tracker: github-project`.
5. When `auto_advance=true`, update Project Status exactly one step after a successful stage. Never advance Plan to Done before a verified human merge.
6. When `${enable_implement}` is true, open one GitHub PR after Plan and post its URL as the Implement receipt. Never merge.
7. When `pr_merged=true`, verify the PR merge, post Done, and move Project Status to `${stage_done}`.
8. When Slack notify is enabled, notify `${slack_notify_channel}` only after the issue comment succeeds. Slack failure is non-fatal.

## GitHub command rules

- PAT needs `repo`, `read:project`, and `project`.
- Start with `gh api user -q .login`; auth/Project GraphQL failures are fatal.
- Use GraphQL variables; never put `#<issue>` on fragile shell command lines.
- For file bodies and GraphQL files use capital `-F query=@/absolute/path` / `-F body=@/absolute/path`; lowercase `-f` sends a literal path.
- Research content misses are soft: one attempt per path, report missing evidence, continue.
- No local clone. No force push. No `gh pr merge`. No CI dispatch.

## Chaining

With `sdlc_chain=true`, continue Specify → Research → Plan after each successful one-step Status hop. Cap the run there, plus one Implement PR when enabled. Done is a separate verified merge run.
