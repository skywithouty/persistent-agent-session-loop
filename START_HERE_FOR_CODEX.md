# Start Here for Codex App

This file is the first document to give a new Codex App task when starting the persistent session loop project.

## Two Entry Points

There are two distinct starting points for Codex App:

### 1. Cross-Project Research Use (primary)

You are in a target research project that already has `.session-loop/` installed (or needs it installed). The user describes a research goal. Your job includes creating a **reviewer heartbeat** so you automatically review Claude reports and write the next task without the user having to poke you.

```text
Please set up a persistent session agent loop for this project.

Install it from https://github.com/skywithouty/persistent-agent-session-loop:
- Clone the repo to a temporary location
- Run .\install.ps1 -TargetPath "<this project directory>" -SourcePath "<cloned repo>"
- Run .\doctor.ps1 to verify the installation

Then act as the controller/planner/reviewer:
- Read START_HERE_FOR_CODEX.md for your full role description
- Read CODEX_REVIEW_RHYTHM.md for the round lifecycle checklist
- Write concrete bounded tasks to .session-loop/inbox/
- Review Claude reports in .session-loop/outbox/
- Write reviews to .session-loop/reviews/
- Keep concise memory in .session-loop/memory/project-summary.md
- Ask the user only at real decision gates (secrets, paid APIs, large downloads, destructive ops)

Create a Codex reviewer heartbeat that runs every 5 minutes in this project/task:
- On each wake, fresh-read .session-loop/STATE.json from disk
- If next_actor is NOT "codex", do nothing and exit quietly
- If next_actor IS "codex", review the latest Claude report, inspect changed files, write
  a review, decide the next step (continue/done/blocked/needs_user_decision), and update
  STATE.json
- Do not check custom context usage or enforce a 60% compact gate

My research goal is: [describe the goal here — paper reproduction, experiment, analysis, etc.]
```

If the loop is already installed (`.session-loop/STATE.json` exists), skip the install steps and start from "Then act as the controller/planner/reviewer."

When the user says "set up the loop and create a reviewer heartbeat," you should:
1. Install if needed.
2. Create the heartbeat/scheduled task in Codex App for this project.
3. Write the first bounded Claude task.
4. Set `next_actor = "claude"` so the Claude executor loop picks it up.

### 2. Developing the Loop Itself (project-internal)

You are working inside the `persistent-agent-session-loop` source repository, building the loop tooling.

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

