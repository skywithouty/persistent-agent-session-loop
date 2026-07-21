# Persistent Session Agent Loop

A project-local task board for coordinating [Codex App](https://codex.openai.com) (planner/reviewer) and [Claude Code](https://claude.ai/code) (executor) in a persistent long-running session.

## Natural-Language Cross-Project Quick Start (primary)

This is the recommended workflow for research use. You describe your goal in natural language; Codex App plans/reviews and Claude Code executes through the `.session-loop/` task board.

A complete setup has **two long-running loops** that keep the project moving without manual intervention:

| Loop | Runs in | What it does |
|---|---|---|
| **Codex reviewer heartbeat** | Codex App (scheduled task/project) | Polls `STATE.json`. If `next_actor = "codex"`, reads the latest Claude report, inspects changed files, writes a review, and creates the next task. If `next_actor` is anything else, exits quietly. |
| **Claude executor `/loop`** | Claude Code (Cursor terminal) | Polls `STATE.json`. If `next_actor = "claude"`, reads the task from `.session-loop/inbox/`, executes it, writes a report, and hands back to Codex. Otherwise does nothing. |

Choose an interval that fits your work rhythm:

- **5 minutes**: active interactive research — the loop responds quickly after each handoff
- **30 minutes**: slower background work — overnight monitoring, long-running experiments

### Step 1: In Codex App — install the loop and start the reviewer heartbeat

Open Codex App in your target research project directory and give it this prompt:

```text
Please set up a persistent session agent loop for this project.

Install it from https://github.com/skywithouty/persistent-agent-session-loop:
- Clone the repo to a temporary location
- Run .\install.ps1 -TargetPath "<this project directory>" -SourcePath "<cloned repo>"
- Run .\doctor.ps1 to verify the installation
- Delete the temporary clone (the installed files are self-contained)

Then act as the controller/planner/reviewer:
- Read START_HERE_FOR_CODEX.md for your full role description
- Read CODEX_REVIEW_RHYTHM.md for the round lifecycle checklist
- Write concrete bounded tasks to .session-loop/inbox/
- Review Claude's reports in .session-loop/outbox/
- Write reviews to .session-loop/reviews/
- Keep project memory in .session-loop/memory/

Crucially, create a Codex reviewer heartbeat that runs every 5 minutes:
- On each wake, fresh-read .session-loop/STATE.json from disk
- If next_actor is NOT "codex", do nothing and exit quietly
- If next_actor IS "codex", then:
  - Read the latest Claude report in .session-loop/outbox/
  - Inspect the actual changed files on disk (do not trust the report alone)
  - Run at least one verification command yourself
  - Write a review to .session-loop/reviews/codex-review-NNNN.md
  - Decide: continue (write next task), done (goal complete), blocked, or needs_user_decision
  - Update .session-loop/STATE.json accordingly
- Do NOT check custom context usage or enforce a 60% compact gate
  (Claude Code auto-compact handles context management)

My research goal is: [describe your paper reproduction, experiment, or research goal here]

Start by reading the project files, understanding the goal, and writing the first bounded task
for Claude Code to .session-loop/inbox/codex-task-0001.md. Then update .session-loop/STATE.json
so next_actor = "claude".
```

### Step 2: In Claude Code (Cursor terminal) — start the executor loop

Open Claude Code in the same project root and give it this prompt:

```text
Please read START_HERE_FOR_CLAUDE.md.

You are the executor in a persistent session agent loop. Your tasks arrive as markdown files
in .session-loop/inbox/. After completing each task, write a structured report to
.session-loop/outbox/ and update .session-loop/STATE.json to hand control back to Codex.
If there is no new task, do not modify any files.

Start a scheduled polling loop so you check for new tasks automatically:
/loop 5m "Read .session-loop/STATE.json fresh from disk. If next_actor is not 'claude',
do nothing. If it is 'claude', read the task from .session-loop/inbox/, execute every
required step, write the report to .session-loop/outbox/, update STATE.json, and append
to .session-loop/logs/events.jsonl."
```

### Example: Paper Reproduction Workflow

A typical paper reproduction session might go:

1. **User (in Codex):** "Reproduce the baseline from paper X. The repo is at https://github.com/..., the dataset is on HuggingFace."
2. **Codex:** Installs the loop, reads the paper repo, writes task-0001: "Set up the environment and verify the dataset loads."
3. **Claude:** Executes task-0001 (creates conda env, downloads dataset subset, verifies shapes), writes report.
4. **Codex:** Reviews report, writes task-0002: "Run the baseline training script and collect metrics."
5. **Claude:** Executes, reports metrics.
6. **Codex reviews → continue or ask user:** If metrics match the paper, issue next task. If not, flag the discrepancy for the user.

At every step:
- Codex checks gates: paid APIs, large downloads (>1 GB), long training, destructive operations — asks the user before proceeding.
- Claude stops and writes Blocked if a task requires credentials, paid API access, broad deletion, or git history changes.
- All results are traceable through `.session-loop/outbox/` reports and `.session-loop/logs/events.jsonl`.

## Command-Line Quick Start (reference)

The commands below are the underlying technical interface. Use these for scripting, debugging, or when you prefer explicit control:

```powershell
# Clone the installer source. This repository is private, so gh auth is required.
gh repo clone skywithouty/persistent-agent-session-loop
cd persistent-agent-session-loop

# Install into a target project:
.\install.ps1 -TargetPath "D:\Projects\my-project"
```

## Commands

### Doctor — validate an existing installation

```powershell
# Check current directory:
powershell -NoProfile -ExecutionPolicy Bypass -File ".\doctor.ps1"

# Check a specific project:
powershell -NoProfile -ExecutionPolicy Bypass -File ".\doctor.ps1" -TargetPath "D:\Projects\my-project"
```

### Install — set up a new project

```powershell
# Standard install (skips existing files):
.\install.ps1 -TargetPath "D:\Projects\my-project"

# Overwrite existing files:
.\install.ps1 -TargetPath "D:\Projects\my-project" -Force

# Dry-run — see what would happen without making changes:
.\install.ps1 -TargetPath "D:\Projects\my-project" -WhatIf

# Install from a specific source:
.\install.ps1 -TargetPath "D:\Projects\my-project" -SourcePath "C:\path\to\templates"

# Doctor-only — validate without installing:
.\install.ps1 -TargetPath "D:\Projects\my-project" -Check
```

### Uninstall — remove the session loop from a project

```powershell
# Standard uninstall (skips user-edited files):
.\uninstall.ps1 -TargetPath "D:\Projects\my-project"

# Force — remove even user-edited session-loop files:
.\uninstall.ps1 -TargetPath "D:\Projects\my-project" -Force

# Dry-run — see what would be removed:
.\uninstall.ps1 -TargetPath "D:\Projects\my-project" -WhatIf
```

## Requirements

- Windows PowerShell 5.1 or later
- No package manager, network access, or external dependencies

## Project Structure

After installation, the project looks like:

```text
<project>/
  START_HERE_FOR_CLAUDE.md    # Executor instructions
  START_HERE_FOR_CODEX.md     # Planner/reviewer instructions
  TASK_BOARD_PROTOCOL.md      # Protocol reference
  CODEX_REVIEW_RHYTHM.md      # Review rhythm reference
  SESSION_LOOP_SPEC.md        # Architecture spec
  PHASE4_COMPACT_BRIDGE_DESIGN.md
  PHASE5_INSTALLER_DESIGN.md
  ROADMAP.md
  README.md
  .session-loop/
    STATE.json                # Current state
    inbox/                    # Task files from Codex
    outbox/                   # Reports from Claude
    reviews/                  # Reviews from Codex
    memory/                   # Persistent memory
    context/                  # Scripts and runtime files
    logs/events.jsonl         # Event log
    locks/                    # Reserved for future bridge
    tmp/                      # Temporary files
```

## How It Works

1. Codex App writes a task to `.session-loop/inbox/` and sets `next_actor = "claude"` in `STATE.json`.
2. Claude Code, running in a long-lived Cursor terminal with a `/loop` cron, picks up the task, executes it, and writes a report to `.session-loop/outbox/`.
3. Codex App reviews the report, writes a review to `.session-loop/reviews/`, and either creates the next task or marks the goal as done.


## Release Readiness

Phase 5 core — install, doctor/check, uninstall — is locally validated as of round 24:

- Full fixture sweep: 11/11 PASS (round 23)
- Cross-project E2E (install → check → uninstall): PASS (round 24)
- All scripts run offline on PowerShell 5.1+ with zero external dependencies

GitHub-hosted install path is enabled at:

```text
https://github.com/skywithouty/persistent-agent-session-loop
```

Runtime history is intentionally not published. The repository excludes `.session-loop/` and `.claude/`; installed projects generate their own local task board state.
