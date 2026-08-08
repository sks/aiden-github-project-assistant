Process exactly one Linear issue through board SDLC (and optional implement + Slack notify).

Orchestration: the parent may use ReAcTree `create_agent` (`task_type=terminal_calling`). That is expected.

**create_agent goal hygiene (mandatory):** do **not** write absolute filesystem paths (`/tmp`, `/workspace`, …) in the create_agent `goal` or `context`. The execution-surface guard treats those as local workspace signals and false-blocks `*_execute_command`. Put real paths only in tool arguments.

**`create_files` paths (mandatory):** `*_create_files` requires **absolute** paths (e.g. `/tmp/plan_comment.md`). Relative paths fail with `path must be absolute`.

## Inputs

- `linear_issue_id` (required) — Linear issue id or identifier (e.g. `CORE-42`).
- `linear_identifier` (optional) — human identifier when the id is a UUID.
- `linear_state` (optional) — workflow state name from the webhook payload; still re-read from Linear before acting.
- `team_key` (optional) — Linear team key; default `${default_team_key}`.
- `repository` (optional) — `owner/name` for Research / implement when not obvious from the issue.
- `auto_advance` (optional) — default `false` for chat. Webhook / poll runs use deployment default `${webhook_auto_advance}`.
- `sdlc_chain` (optional) — default from deployment `${sdlc_chain}`.
- `pr_merged` (optional) — when `true`, run **Done completion** only (PR already merged by a human).
- `pull_request_number` (optional) — merged PR number when `pr_merged` is true.

### Webhook ingress (Issue create / update)

1. Read `data.id`, `data.identifier`, `data.title`, `data.description`, `data.state.name`, `data.team.key`, `data.labels[].name` from the payload (do not invent them).
%{ if trigger_label != "" ~}
2. Label gate: only proceed when the issue carries the `${trigger_label}` label. Otherwise stop.
%{ endif ~}
3. `action=create`: if the state is not a board state, move it to `${stage_specify}` and run **Specify**, then chain when enabled.
4. `action=update` with a changed workflow state: run the stage matching the new state.
5. Ignore comment-only events, `remove` actions, and updates that did not change the state.

### Merge poll / PR merged webhook / Done completion

When `pr_merged` is true:

1. Resolve the issue + current workflow state (do not invent state).
2. Confirm the cited PR is merged (`gh api repos/OWNER/REPO/pulls/<n> --jq .merged`).
3. If state is already `${stage_done}` and a Done comment exists: reply idle and stop.
4. Else run **Done** (below): hop state to `${stage_done}`, post the Done comment. Do not Implement again.

## State map (this deployment)

| Logical stage | Linear workflow state |
|---------------|-----------------------|
| Specify | `${stage_specify}` |
| Research | `${stage_research}` |
| Plan | `${stage_plan}` |
| Done | `${stage_done}` |

Next-state chain: `${stage_specify}` → `${stage_research}` → `${stage_plan}`. Do **not** auto-advance from `${stage_plan}` until a human merges the Implement PR — then hop to `${stage_done}`.

## Linear operations (board of truth)

Use the Linear integration tools (prefixed with the Linear integration name). Typical operations:

- **Read issue:** `get_issue` by id or identifier → title, description, `state.name`, `team.key`, labels, url.
- **List workflow states:** to resolve the target state id for the team before a hop (states are per-team; match by name from the table above, case-insensitive).
- **Comment:** `create_comment` / `save_comment` with the issue id and the mandatory comment body.
- **Hop state:** `update_issue` / `save_issue` with the resolved `stateId` for the next state. Never skip states; never advance past `${stage_plan}` on board stages.

If a Linear read/write fails, surface the error and stop for that stage — do not invent state.

## GitHub operations (Research + implement)

GitHub PAT / vault token must include **`repo`**. Use the GitHub integration tools.

**Fatal vs soft `gh` failures:**

- **Fatal (stop):** auth preflight failure; inability to open the implement PR after the plan is ready. Re-run **once** with `2>&1`, paste stderr, stop.
- **Soft (continue):** Contents/raw/search reads during Research. **One attempt per path.** Non-zero exit → treat as `path: not in repo` and move on. Do not re-run with `2>&1`. Do not batch multiple paths in one script.

Fetch files one at a time; prefer raw bytes:

```bash
gh api "repos/$${OWNER}/$${REPO}/contents/$${PATH}" -H "Accept: application/vnd.github.raw"
```

## Steps

1. Resolve the issue via Linear (`get_issue`). Confirm `team_key`. For webhook runs, prefer payload fields.
2. Read the current workflow state from Linear.
3. If `pr_merged` is true: run **Done** and stop.
4. Match the state to Specify / Research / Plan (case-insensitive against the table). If state is `${stage_done}`: idle. If no match: comment "unsupported state" and stop.
5. Run **the matched stage** (bodies below).

### Specify

Rewrite the issue into: Goal (1–2 sentences); In scope / out of scope; Acceptance criteria (checklist); Open questions. Do not invent requirements that contradict the issue; mark assumptions.

### Research

Using GitHub APIs only (contents, search, tree, README, recent commits/PRs): relevant paths / entry points; existing patterns to reuse; risks / unknowns. Cite `owner/repo` paths. No local clone. One attempt per path; incomplete evidence is OK — say what was missing.

### Plan

Produce: implementation steps (ordered); files likely to change (best effort); test plan; rollout / rollback notes (brief).

### Done

Only when the Implement PR is **merged** (never invent a merge):

- Hop the Linear workflow state to `${stage_done}` (`update_issue` with the Done state id).
- Post `### Aiden linear assist — Done` on the Linear issue with the merged PR URL and **State (after):** `${stage_done}`.
- Do not open another PR. Do not merge.

## After each stage

1. Post the mandatory Linear comment (stage name, before/after state, output, next human step). Write the body via `*_create_files` to an **absolute** path, then pass it to the Linear comment call.
2. Advancement after a board stage:
   - If `auto_advance` is not true: leave state unchanged; **State (after)** = same as before.
   - If `auto_advance` is true and the stage succeeded: hop the issue to the next state once. Never advance more than one hop. Never advance from `${stage_plan}` on board stages.
3. **SDLC chain** (`sdlc_chain` true, deployment default `${sdlc_chain}`): after Specify (state → Research) continue Research; after Research (state → Plan) continue Plan. After Plan go to Implement only when `${enable_implement}` is true; otherwise stop. Cap: Specify + Research + Plan (+ optional Implement) in one run. Done is a separate run after merge.
4. **Implement (MANDATORY when `${enable_implement}` is true):** after the Plan comment is posted in this run **or** when state is `${stage_plan}` and a Plan comment already exists, you **must** open the PR in the **same run** before stopping.
   - Ground work in the Plan comment + Research/Specify comments + issue description.
   - Create a feature branch from the default branch (Contents API / `gh api`; no local clone). Prefer a branch name that starts with the Linear identifier (e.g. `sks-29-…`) so the merge webhook can back-reference the issue.
   - Commit concrete file changes matching the Plan. Prefer small, reviewable diffs.
   - Open a PR with `gh pr create`. In the PR body use **`Fixes <Linear issue URL or identifier>`** and the plan summary. Use `--body-file` / `-F body=@…` with an absolute path.
   - Comment on the Linear issue with the PR URL under `### Aiden linear assist — Implement`.
   - Do **not** merge. Leave the Linear state on `${stage_plan}` until Done after merge.
   - If implement fails, comment the error under Implement and stop — do not pretend success.
%{ if enable_slack_notify ~}
5. **Slack notify (enabled):** after the Linear comment lands, post a one-line receipt to `${slack_notify_channel}` using the Slack integration:
   `[<identifier>] <Stage> done → state <after>. <Linear URL>  (PR: <url if any>)`
   Notify failures are non-fatal — log and continue; never block the board on Slack.
%{ else ~}
5. Slack notify is disabled for this deployment — skip channel posts.
%{ endif ~}
6. Summarize in chat: Linear issue URL, comments, state hops, PR URL if any.

## Safety

- One issue per run.
- Board stages: Linear comment + optional one state hop; chain when `sdlc_chain` is true.
- Implement (when enabled): branch + commits + open PR only — never merge, never force-push, never delete.
- Done (after human merge): state → `${stage_done}`, Done comment — still never `gh pr merge`.
- Forbidden always: `gh pr merge`, force-push, destructive shell, changing unrelated Linear fields, running CI dispatch.
- Slack is notify only.
