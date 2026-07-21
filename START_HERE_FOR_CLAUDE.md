# Start Here for Claude Code

This file is the first document to give Claude Code in the long-running Cursor terminal session.

## One-Time Session Prompt

After opening Claude Code in the project root, give it this natural-language prompt:

```text
请先阅读 START_HERE_FOR_CLAUDE.md。

你是 persistent session agent loop 里的执行端，不是总规划端。
你的任务来自 .session-loop/inbox/。
你执行完成后，把结构化报告写到 .session-loop/outbox/。
如果没有新任务，就不要改文件。
如果任务需要密钥、付费 API、长时间训练、大量下载、大量删除、git 历史重写，必须停止并在报告里写 Blocked。
```

Then start a scheduled loop inside the same Claude Code session:

```text
/loop 5m "Run: Get-Location. Run: Get-Content -LiteralPath '.session-loop\STATE.json' -Encoding UTF8. Never decide next_actor from conversation memory — only from the file you just read from disk. If next_actor is not 'claude', do nothing. If next_actor IS 'claude', run: Get-Content -LiteralPath '.session-loop\inbox\<id>.md' -Encoding UTF8 to read the task file from disk. Execute the task, write the report to .session-loop/outbox/, update STATE.json, and append to events.jsonl."
```

The exact interval can be changed later. Five minutes is a practical first value.

## Your Role

You are the executor.

You should:

1. Read the current Codex task.
2. Execute only the requested work.
3. Keep changes inside the allowed file scope.
4. Run the requested verification commands when possible.
5. Write a structured report.
6. Stop when the task is complete or blocked.

You should not:

- invent a new project roadmap
- continue into the next task without a new Codex task file
- modify files outside the allowed scope
- hide failed commands
- claim a test passed unless it was run in this session

## Polling Behavior

On each loop tick:

1. Read `.session-loop/STATE.json`.
2. If `next_actor` is not `claude`, do nothing.
3. Find the task id in `current_task_id`.
4. Read `.session-loop/inbox/<current_task_id>.md`.
5. If that task id already has a completed report in `.session-loop/outbox/`, do nothing.
6. Execute the task.
7. Write `.session-loop/outbox/claude-report-NNNN.md`.
8. Update `STATE.json` so `next_actor` becomes `codex`.

## Report Format

Every report must use this structure:

```markdown
# Claude Report: claude-report-NNNN

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

If a section has nothing to say, write `None`.

### Context Usage Reporting (Deprecated)

Context usage monitoring is deprecated. The project relies on Claude Code's default auto-compact behavior. Do not observe or record context usage as a required behavior.

In the report, write `None` for the `## Context Usage` section, or state "Context monitoring is deprecated; relying on Claude Code auto-compact."

## Fresh Disk Read Rule

The most common Phase 2 failure mode is deciding `next_actor` from stale conversation context instead of reading the file from disk.

Every loop tick must:

1. Run `Get-Location` first to confirm the shell is in the project root.
2. Run `Get-Content -LiteralPath ".session-loop\STATE.json" -Encoding UTF8` to read STATE.json fresh from disk.
3. Never reuse a `next_actor` value remembered from an earlier conversation turn.
4. When `next_actor` is `claude`, run `Get-Content -LiteralPath ".session-loop\inbox\<id>.md" -Encoding UTF8` to read the task file fresh from disk.
5. If a Read tool result says "file unchanged since your last Read", force a re-read: use `cat` (Bash) or `Get-Content` (PowerShell) to bypass the cache.

## Compaction

This project relies on Claude Code's default auto-compact behavior. The custom Post-Task Compact Gate (Phase 4a) is deprecated:

- Do not run `check-compact-gate.ps1`.
- Do not set `next_actor = "user"` based on context percentage.
- Do not require manual `/compact` for loop operation.
- `context_at_threshold` is no longer a blocking reason.

Users may run `/compact` manually if they personally want to, but the loop does not enforce it.

## Statusline Context Monitor (Optional / Deprecated)

The statusline script (`.session-loop/context/claude-statusline.ps1`) and compact gate checker (`.session-loop/context/check-compact-gate.ps1`) are legacy files. They may remain in the project but are not required by the active loop. The loop does not observe context usage or block on context thresholds.

The `context_compact_threshold` field in `STATE.json` is also optional and not used by the active loop.

## Stop Conditions

Stop and write `Blocked` when the task requires:

- secrets or credentials
- paid API use
- large downloads
- long training or heavy compute
- broad deletion or file moves
- git history rewrite
- unclear paper, dataset, metric, or expected result
- permission that the current Claude session does not have

