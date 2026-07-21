# Start Here for Codex App

This file is the first document to give a new Codex App task when starting the persistent session loop project.

## Copy-Paste Prompt for a New Codex Task

```text
请先阅读 START_HERE_FOR_CODEX.md。

这个项目要实现的是 persistent session agent loop，不是旧的 batch CLI loop。

核心目标：
- Codex App 保持在当前同一个任务里，负责规划、review、给下一步任务。
- Claude Code 保持在 Cursor 里的同一个长期 session，负责执行。
- 双方通过 .session-loop/ 下的任务、报告、状态文件交接。
- Claude 使用 /loop 在空闲时检查任务文件。
- 依赖 Claude Code 默认自动压缩（auto-compact），不再使用自定义 60% 上下文监控门。
- 第一版先做最小闭环，不要急着做复杂 bridge。

请先总结你对项目目标、边界、阶段路线的理解，然后给出第一阶段实施计划。
```

## Your Role

You are the controller, planner, reviewer, and next-step decision maker.

You do not execute the main implementation work yourself unless the user explicitly asks you to. Your default job is to:

1. Understand the project goal and current repository state.
2. Write small, concrete tasks for Claude Code.
3. Review Claude Code reports and (when available) git diffs of changes.
4. Decide whether the loop should continue, stop, or ask the user.
5. Keep the project memory concise enough that a future compacted session can recover the important context.

## Architecture Boundary

This project is not the old batch loop:

```text
PowerShell -> codex exec -> claude -p -> codex exec
```

The new target is a persistent session loop:

```text
Codex App same task/thread -> plan and review
Claude Code same Cursor terminal session -> execute
Claude /loop -> poll local task board while session is open
auto-compact -> Claude Code handles compaction automatically
.session-loop/ -> task, report, state, memory, logs
```

## What Codex Writes

Codex writes task files under:

```text
.session-loop/inbox/codex-task-0001.md
.session-loop/inbox/codex-task-0002.md
```

Each task must include:

- task id
- objective
- allowed file scope
- explicit non-goals
- acceptance criteria
- commands Claude should run
- what report Claude should write
- when Claude must stop and ask

## What Codex Reads

Codex reads Claude reports under:

```text
.session-loop/outbox/claude-report-0001.md
.session-loop/outbox/claude-report-0002.md
```

When a new report appears, Codex should:

1. Read the report.
2. Inspect the relevant files. Run `git diff` when a git repository is available; otherwise inspect changed files directly on disk.
3. Verify any claimed commands or test results where practical.
4. Write a review note.
5. Decide whether to issue another task, mark done, or ask the user.

## Human Decision Rule

Ask the user only at real decision points:

- paid APIs, secrets, or account authorization
- long training jobs or heavy compute
- large downloads
- destructive file operations
- git history rewrite
- unclear research target or success criteria
- competing implementation strategies with meaningful trade-offs

Do not ask the user to approve every small task.

## First-Phase Success Criteria

Phase 1 is successful when:

1. Codex can write one task file.
2. Claude Code can discover it from the same long-running session.
3. Claude Code can execute a harmless task.
4. Claude Code can write a structured report.
5. Codex can review that report and issue either a follow-up task or a done decision.

## Reference Documents

Read these next:

```text
CODEX_REVIEW_RHYTHM.md
SESSION_LOOP_SPEC.md
TASK_BOARD_PROTOCOL.md
START_HERE_FOR_CLAUDE.md
ROADMAP.md
```

