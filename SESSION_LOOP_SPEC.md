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

### Context Monitor

Claude Code statusline records context usage into `.session-loop/context/claude-status.json`.

When context usage reaches the configured target, initially 60%, the loop should compact before starting another substantial execution round.

### Optional Bridge

The bridge is a later component that launches and owns the Claude Code process.

Its purpose is not to replace Claude Code. Its purpose is to:

- pass startup flags consistently
- observe context usage
- inject `/compact` when the threshold is crossed
- keep logs
- recover from simple terminal/session interruptions

The bridge should be added only after the `/loop`-based MVP works.

**Phase 4 clarification (from PHASE4_COMPACT_BRIDGE_DESIGN.md):** Status observation (reading `claude-status.json`) and command injection (running `/compact`) are separate concerns. The MVP design uses a **Post-Task Compact Gate**: compaction is checked only after a task completes, never mid-task. The `/loop` blocks before the next substantial task when: (a) live context reaches threshold, (b) status is mock-derived, (c) status is stale (timestamp > ~10 min old), or (d) status file is missing. In all four cases, `next_actor` is set to `"user"` with the appropriate `stop_reason`. Mock/stale/missing status is treated as **unknown** and blocks further substantial work — it must not be treated as safe-low or used to suppress compaction.

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

## Context Compaction Flow

```text
1. Claude statusline receives session metadata from Claude Code.
2. The statusline script writes used_percentage to .session-loop/context/claude-status.json.
3. After a Claude task completes, the loop checks used_percentage.
4. If used_percentage >= 60, compact before the next substantial task.
5. The compaction summary preserves goal, completed work, decisions, files, verification, blockers, and next step.
```

The first implementation can use a manual compact instruction. Full automatic `/compact` is a later bridge feature.

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

- `/loop` can rerun prompts on a schedule inside a Claude Code session.
- statusline can expose context window usage data.
- `/compact` can reduce conversation history while preserving important context.

These assumptions should be verified during Phase 1 before building the bridge.

## Sources to Re-Check

- https://code.claude.com/docs/en/scheduled-tasks
- https://code.claude.com/docs/en/statusline
- https://code.claude.com/docs/en/commands
- https://code.claude.com/docs/en/agent-sdk/slash-commands

