# Persistent Session Agent Loop Spec

## Goal

Build a local collaboration loop where Codex App and Claude Code keep their own long-lived context while coordinating through explicit project-local files.

The target user workflow is:

```text
User works in Codex App
Codex App plans and reviews in the same task
Cursor terminal keeps one Claude Code session open
Claude Code executes tasks in that same session
Local files carry tasks, reports, state, and memory
The loop continues until Codex marks the goal done or asks the user
```

## Non-Goal

This is not a stateless batch orchestrator.

The first version should not center on:

- `claude -p` one-shot calls
- `codex exec` as the main reviewer
- a PowerShell script that owns the whole loop
- hidden orchestration state
- fully autonomous destructive changes

Batch execution can remain a reference implementation, but it should not define the v2 architecture.

## System Components

### Codex App Controller

Codex App runs in one task and acts as the controller.

Responsibilities:

- maintain the goal and plan
- write bounded Claude tasks
- review Claude reports and diffs
- ask the user only for meaningful decisions
- update project-local memory

### Claude Code Executor

Claude Code runs in one long-lived Cursor terminal session.

Responsibilities:

- use `/loop` to periodically check for assigned work
- execute only the current Codex task
- write structured reports
- keep its own execution context alive across tasks
- stop when blocked by permission, cost, data, or scope

### Local Task Board

The `.session-loop/` directory is the shared state surface.

It is intentionally plain text and JSON so both humans and agents can inspect it.

### Context Monitor (deprecated)

**Deprecated (round 16–17):** The custom context monitoring infrastructure is deprecated. The project relies exclusively on Claude Code's default auto-compact behavior. The statusline script (`claude-statusline.ps1`) and compact gate checker (`check-compact-gate.ps1`) remain as legacy files but are not required by the active loop, not installed into new projects by the Phase 5 installer, and not validated by doctor. The loop does not observe context usage, does not block on `context_at_threshold`, and does not require manual `/compact`.

### Optional Bridge

The bridge is a later component that launches and owns the Claude Code process.

Its purpose is not to replace Claude Code. Its purpose is to:

- pass startup flags consistently
- observe context usage
- inject `/compact` when the threshold is crossed
- keep logs
- recover from simple terminal/session interruptions

The bridge should be added only after the `/loop`-based MVP works.

**Phase 4 clarification (historical, from PHASE4_COMPACT_BRIDGE_DESIGN.md):** The Post-Task Compact Gate was implemented and live-validated in Phase 4a (round 12), then deprecated by user decision (round 16–17). All custom compact infrastructure — including `check-compact-gate.ps1`, the 60% threshold, and `context_at_threshold` blocking — is no longer active. The project relies exclusively on Claude Code's default auto-compact. See PHASE4_COMPACT_BRIDGE_DESIGN.md for the full historical design record.

## Data Flow

```text
1. Codex writes .session-loop/inbox/codex-task-0001.md
2. Codex sets next_actor = "claude" in .session-loop/STATE.json
3. Claude /loop notices the task
4. Claude executes the task in the same Cursor terminal session
5. Claude writes .session-loop/outbox/claude-report-0001.md
6. Claude sets next_actor = "codex"
7. Codex reads the report and reviews the repository state
8. Codex writes the next task, marks done, or asks the user
```

## Context Compaction (deprecated custom flow)

The custom context compaction flow described below is deprecated (round 16–17). The project relies on Claude Code's default auto-compact behavior. The loop does not observe context usage, does not enforce a 60% threshold, and does not require manual `/compact`. Users may run `/compact` manually if they wish.

The original (deprecated) flow was:

```text
1. Claude statusline receives session metadata from Claude Code.
2. The statusline script writes used_percentage to .session-loop/context/claude-status.json.
3. After a Claude task completes, the loop checks used_percentage.
4. If used_percentage >= 60, compact before the next substantial task.
5. The compaction summary preserves goal, completed work, decisions, files, verification, blockers, and next step.
```

## Safety Model

Only one agent should modify project files during a task execution window.

Default ownership:

```text
Codex owns: .session-loop/inbox/, reviews, planning notes
Claude owns: execution changes and .session-loop/outbox/
Both may read: all task board files and project files
```

Claude should stop and report blocked for risky actions rather than escalating silently.

## External Behavior Assumptions

This design depends on current Claude Code behavior:

- `/loop` can rerun prompts on a schedule inside a Claude Code session (verified).
- `/compact` can reduce conversation history while preserving important context (verified).
- ~~statusline can expose context window usage data~~ — no longer required. The project relies on Claude Code default auto-compact.

These assumptions were verified during Phase 1. The statusline assumption is crossed out because custom context monitoring is deprecated (round 16–17).

## Sources to Re-Check

- https://code.claude.com/docs/en/scheduled-tasks
- https://code.claude.com/docs/en/statusline
- https://code.claude.com/docs/en/commands
- https://code.claude.com/docs/en/agent-sdk/slash-commands

