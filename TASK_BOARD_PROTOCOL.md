# Task Board Protocol

Installer-created task boards (Phase 5) must start from this protocol. Every file, directory, STATE.json initial value, and template specified here is the canonical reference for `install.ps1`.

## Directory Layout

The v2 loop uses `.session-loop/` instead of `.agent-loop/` to avoid confusing the persistent-session architecture with the old batch architecture.

```text
.session-loop/
  STATE.json
  inbox/
    codex-task-0001.md
  outbox/
    claude-report-0001.md
  reviews/
    codex-review-0001.md
  memory/
    project-summary.md
    decisions.md
  context/
    (scripts and runtime files)
  logs/
    events.jsonl
  locks/
```

## STATE.json

Initial state:

```json
{
  "protocol_version": 1,
  "status": "init",
  "round": 0,
  "current_task_id": "",
  "last_report_id": "",
  "last_review_id": "",
  "next_actor": "codex",
  "goal_done": false,
  "stop_reason": ""
}
```

Allowed `next_actor` values:

```text
codex
claude
user
none
```

Allowed `status` values:

```text
init
ready_for_claude
executing
ready_for_codex
reviewing
blocked
done
failed
```

## Codex Task Format

Path:

```text
.session-loop/inbox/codex-task-0001.md
```

Template:

```markdown
# Codex Task: codex-task-0001

## Objective

## Context

## Allowed File Scope

## Non-Goals

## Required Steps

## Verification Commands

## Acceptance Criteria

## Stop And Ask If

## Required Report Path

.session-loop/outbox/claude-report-0001.md
```

### Allowed File Scope Discipline

The `Allowed File Scope` list is a hard boundary. Claude must not modify files outside it. Codex must not list files outside the intended scope.

If Claude discovers a fix or improvement needs to touch a file outside the allowed scope:
1. Do NOT edit the file silently.
2. If the fix is required to complete the task, stop and report it in `## Blockers`.
3. Codex will either expand the scope in a follow-up task or decide the fix is out-of-band.

This discipline prevents unintended side effects from incremental task execution — every file change is explicitly authorized by Codex in the task definition.

## Claude Report Format

Path:

```text
.session-loop/outbox/claude-report-0001.md
```

Template:

```markdown
# Claude Report: claude-report-0001

## Task Understood

## Changes Made

## Files Modified

## Commands Run

## Results

## Verification

## Context Usage

## Blockers

## Suggested Next Step
```

## Codex Review Format

Path:

```text
.session-loop/reviews/codex-review-0001.md
```

Template:

```markdown
# Codex Review: codex-review-0001

## Reviewed Report

## Findings

## Verification

## Decision

One of: continue, done, blocked, needs_user_decision

## Next Task

## User Decision Needed
```

## Event Log Format

Path:

```text
.session-loop/logs/events.jsonl
```

Each line is one JSON object:

```json
{"ts":"2026-07-20T12:00:00+08:00","actor":"codex","event":"task_created","id":"codex-task-0001"}
```

## Locking Rule

The MVP can rely on `next_actor` and task ids instead of complex locks.

When a bridge is added, it may use `.session-loop/locks/claude.lock` to avoid duplicate Claude executions.

## Idempotency Rule

Claude must not execute a task again if the expected report already exists.

Codex must not review the same report again unless the user explicitly asks for a re-review.

## State Transition

```text
init -> ready_for_claude -> executing -> ready_for_codex -> reviewing -> ready_for_claude
```

Terminal states:

```text
done
blocked
failed
```

### Compaction

This project relies on Claude Code's default auto-compact behavior. The custom Post-Task Compact Gate (Phase 4a) is deprecated. The loop does not observe context usage, does not run `check-compact-gate.ps1`, and does not block on `context_at_threshold`. Users may run `/compact` manually if they wish.

