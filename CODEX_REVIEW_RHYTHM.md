# Codex Review Rhythm

An operational guide for Codex App to run repeated planner/reviewer rounds in the persistent session loop. Every section is a checklist — follow it each round.

## Purpose

This document keeps the Codex controller consistent across rounds. It defines what to check before writing a task, how to review a Claude report, when to update memory, and when to stop and ask the user.

Phase 2 success means Codex follows these checklists every round without drift.

## Round Lifecycle

Each round follows one path:

```text
read state → review last report → update memory → decide next step
  ├─ continue → write next task → update state → wait
  ├─ done → close goal
  ├─ blocked → record reason → wait for user
  └─ needs_user_decision → ask user one concrete question
```

A round starts when `next_actor` is `"codex"` and a new Claude report exists in `outbox/`. A round ends when Codex updates `STATE.json` and hands off to `claude`, `user`, or `none`.

## Task Creation Checklist

Before writing a task file, confirm every item:

- [ ] Read `.session-loop/STATE.json` and the latest Claude report.
- [ ] Read `.session-loop/memory/project-summary.md` and `decisions.md` if they exist.
- [ ] The task objective fits in one sentence.
- [ ] `Allowed File Scope` lists exact files Claude may touch.
- [ ] `Non-Goals` lists at least three things Claude must not do.
- [ ] `Required Steps` are ordered and each step is concrete.
- [ ] `Verification Commands` are copy-paste runnable from the project root.
- [ ] `Acceptance Criteria` are falsifiable (you can say yes/no after reading the report).
- [ ] `Stop And Ask If` covers: secrets, paid APIs, large downloads, destructive ops, git history rewrite, unclear targets.
- [ ] `Required Report Path` points to `.session-loop/outbox/claude-report-NNNN.md` matching the task id number.
- [ ] The task does not ask Claude to invent architecture, choose strategy, or decide scope.

Task file path: `.session-loop/inbox/codex-task-NNNN.md` (zero-padded, 4 digits).

## Claude Report Review Checklist

When a new Claude report appears in `outbox/`, start with a fresh disk read of every file you are about to judge. Never decide from conversation memory.

**Fresh disk reads (mandatory first step):**

- [ ] Run `Get-Content -LiteralPath ".session-loop\STATE.json" -Encoding UTF8` to read current state from disk.
- [ ] Run `Get-Content` on the Claude report file to read it fresh from disk.
- [ ] Run `Get-Content` or open each modified file to read the actual on-disk content.
- [ ] Do not trust a stale `next_actor` or report summary from a prior conversation turn.

**Review checklist:**

- [ ] Read the full report.
- [ ] Check `Task Understood` — does it match the objective you wrote?
- [ ] Check `Changes Made` — are they inside `Allowed File Scope`?
- [ ] Check `Files Modified` — any file outside scope? If a file was modified outside scope, treat it as a blocker: the fix may be valid, but the scope boundary was violated. Either accept the out-of-scope change in the review decision and note it, or mark the round as blocked and create a scoped follow-up task.
- [ ] Check `Commands Run` — were the verification commands actually run?
- [ ] Check `Results` — do they satisfy the acceptance criteria?
- [ ] Check `Verification` — did every verification command pass?
- [ ] Check `Context Usage` — deprecated. The project relies on Claude Code default auto-compact. The report's `## Context Usage` section should say "None" or "Context monitoring is deprecated." Do not rerun compact gate checks, do not block on context percentage, and do not read `claude-status.json` or `compact-gate-result.json` for gating decisions.
- [ ] Check `Blockers` — is anything blocked? If so, stop the round and triage.
- [ ] Inspect the modified files on disk. Run `git diff` if a git repo exists; otherwise read changed files directly. Do not trust the report alone.
- [ ] Run at least one verification command yourself to confirm.

After review, write a review file at `.session-loop/reviews/codex-review-NNNN.md` with the standard template from `TASK_BOARD_PROTOCOL.md`.

## State Transition Checklist

After every action, update `.session-loop/STATE.json`:

| Trigger | Set `status` | Set `next_actor` | Other fields |
|---|---|---|---|
| Task written | `ready_for_claude` | `claude` | `current_task_id`, increment `round` |
| Review: continue | `ready_for_claude` | `claude` | after writing next task |
| Review: done | `done` | `none` | `goal_done: true`, `stop_reason` |
| Review: blocked | `blocked` | `user` | `stop_reason` with specific blocker |
| Review: needs user | `blocked` | `user` | `stop_reason` with the question |

Also append one line to `.session-loop/logs/events.jsonl` for every state change. Use the format from `TASK_BOARD_PROTOCOL.md`.

## Memory Update Format

After each review, update `.session-loop/memory/project-summary.md`. Keep it under 20 lines. Use this structure:

```markdown
# Project Summary (last updated: YYYY-MM-DD)

## Goal
[one sentence]

## Completed Rounds
- round N: [what was done, one line]

## Current State
- status: [from STATE.json]
- next task: [one-line description or "none"]

## Key Decisions
- [decision, one line each]

## Open Blockers
- [blocker or "none"]
```

Update `.session-loop/memory/decisions.md` only when a real architectural or scope decision is made. Each entry:

```markdown
## YYYY-MM-DD: [decision title]
- **Context:** [why this came up]
- **Decision:** [what was chosen]
- **Alternatives considered:** [briefly]
```

Do not create memory files for routine round-to-round status.

## Manual User Decision Gates

Ask the user only at these gates. Do not ask for every task or report.

| Gate | Trigger |
|---|---|
| Secrets / auth | Task needs credentials, tokens, or account access |
| Paid API | Task would incur a bill |
| Heavy compute | Training, large inference, multi-hour runs |
| Large download | Dataset or model download > 1 GB |
| Destructive ops | Bulk delete, rm -rf, format, disk-level changes |
| Git history rewrite | rebase -i, filter-branch, force push |
| Strategy choice | Two viable approaches with real trade-offs |
| Unclear target | Paper, metric, or expected result is ambiguous |

When you hit a gate: pause the round, write the question, set `next_actor` to `user`, and wait.

## Stop Conditions

Stop the loop entirely when:

- `goal_done` is `true` and no follow-up goals are defined.
- The user explicitly asks to stop.
- A blocker cannot be resolved without external action (e.g., waiting for account approval).

Do not stop just because a single task was blocked — hand off to the user instead.

## Phase 2 Acceptance Criteria

Phase 2 is successful when:

1. Codex follows these checklists for at least 3 full rounds without missing a step.
2. Codex asks the user only at real decision gates (not for routine task approval).
3. Codex issues tasks that are small enough for Claude to complete in one execution window.
4. Codex inspects changed files directly (or reviews `git diff` when a git repo exists) and re-runs at least one verification command per report.
5. Memory files stay concise and recoverable by a future compacted session.
