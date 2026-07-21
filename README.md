# Persistent Session Agent Loop

A project-local task board for coordinating [Codex App](https://codex.openai.com) (planner/reviewer) and [Claude Code](https://claude.ai/code) (executor) in a persistent long-running session.

## Quick Start

Install from GitHub into any project directory:

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
