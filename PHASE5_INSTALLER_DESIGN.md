# Phase 5 Installer Design

## Purpose

Define what the persistent session loop installer must copy, validate, and never overwrite. This is a design spec — no installer code is written yet. It drives a future `install.ps1` and `doctor.ps1`.

## Installer Scope

The installer sets up a persistent session loop in a target project directory. It does not:

- run Claude Code or Codex App;
- modify the user's shell profile or Claude Code settings;
- initialize git or touch `.gitignore`;
- download models, datasets, or external tools;
- depend on npm, pip, winget, or any package manager.

It does:

- copy templates into the target project;
- create the `.session-loop/` directory scaffold with empty state and directories;
- validate the result with a built-in doctor pass.

## Template Inventory

Files are classified into four groups.

### Copy Once (static, no project edits expected)

| File | Notes |
|---|---|
| `TASK_BOARD_PROTOCOL.md` | Protocol reference |
| `CODEX_REVIEW_RHYTHM.md` | Review rhythm reference |
| `SESSION_LOOP_SPEC.md` | Architecture spec |
| `PHASE4_COMPACT_BRIDGE_DESIGN.md` | Compact bridge policy (Phase 4a finalized) |
| `PHASE5_INSTALLER_DESIGN.md` | This design doc |

### Merge / Manual Review (template provided; user edits per project)

| File | Notes |
|---|---|
| `START_HERE_FOR_CLAUDE.md` | Contains project-specific prompt text; user should review compaction strategy section |
| `START_HERE_FOR_CODEX.md` | Contains project-specific Codex prompt; user should review role description |
| `ROADMAP.md` | Project-specific phases; installer writes a starter with Phase 1 only |
| `README.md` | If absent, installer writes a minimal stub; if present, installer warns and skips |

### Generated Per Project (factory-fresh, never copied from elsewhere)

| File / Directory | Notes |
|---|---|
| `.session-loop/STATE.json` | Init state: `status = "init"`, `round = 0`, `next_actor = "codex"` |
| `.session-loop/logs/events.jsonl` | Empty file |
| `.session-loop/inbox/` | Empty directory |
| `.session-loop/outbox/` | Empty directory |
| `.session-loop/reviews/` | Empty directory |
| `.session-loop/locks/` | Empty directory (reserved for future bridge) |
| `.session-loop/memory/` | Empty directory; user or Codex populates |

### Never Copied (runtime artifacts)

| File / Directory | Notes |
|---|---|
| `.session-loop/outbox/*` (report files) | Specific to source project |
| `.session-loop/inbox/*` (task files) | Specific to source project |
| `.session-loop/reviews/*` (review files) | Specific to source project |
| `.session-loop/logs/events.jsonl` (non-empty) | Specific to source project |
| `.session-loop/locks/*` | Runtime lock files |
| `.session-loop/tmp/` | Temporary scripts |

## Target Project Layout

After installation:

```text
<target-project>/
  START_HERE_FOR_CLAUDE.md
  START_HERE_FOR_CODEX.md
  TASK_BOARD_PROTOCOL.md
  CODEX_REVIEW_RHYTHM.md
  SESSION_LOOP_SPEC.md
  PHASE4_COMPACT_BRIDGE_DESIGN.md
  PHASE5_INSTALLER_DESIGN.md
  ROADMAP.md
  README.md                (if absent, stub created)
  .session-loop/
    STATE.json
    inbox/                 (empty)
    outbox/                (empty)
    reviews/               (empty)
    logs/
      events.jsonl         (empty)
    locks/                 (empty)
    memory/                (empty)
    context/               (scripts and runtime files)
    tmp/                   (empty)
```

## Safety Rules

1. **Never overwrite without confirmation.** If a file already exists at the target path, the installer must warn and ask (`-Force` to overwrite). Exceptions: empty `.session-loop/` directories may be created silently; factory-fresh `STATE.json` may overwrite only if the existing file is still at `status = "init"`.
2. **Never copy runtime state.** `.session-loop/outbox/`, `inbox/`, `reviews/` contents, non-empty `events.jsonl`, lock files, and `tmp/` contents are never copied between projects.
3. **Project-local only.** The installer writes everything into the target project root. It never writes to `$HOME`, `$PROFILE`, or system directories.
4. **No network calls.** The installer runs fully offline. Template files are read from the source installation, not downloaded.
5. **Idempotent.** Running the installer twice on the same project must not duplicate files or corrupt state. The second run should behave like a doctor check (see `-Check` mode).
6. **Dry-run.** A `-WhatIf` parameter shows what would be created or overwritten without making changes.
7. **Windows-first.** PowerShell 5.1+ is the required runtime. Bash/zsh support is deferred.
8. **Dependency-free.** The installer uses only PowerShell built-ins. No `Install-Module`, `npm`, `pip`, or `winget` calls.

## Doctor Checks

A `doctor.ps1` (or `install.ps1 -Check`) validates an existing installation. Every check returns PASS, WARN, or FAIL.

### Check 1: Root Docs Present

| File | Severity |
|---|---|
| `START_HERE_FOR_CLAUDE.md` | FAIL if missing |
| `START_HERE_FOR_CODEX.md` | FAIL if missing |
| `TASK_BOARD_PROTOCOL.md` | FAIL if missing |
| `CODEX_REVIEW_RHYTHM.md` | FAIL if missing |
| `SESSION_LOOP_SPEC.md` | WARN if missing (reference doc) |
| `PHASE4_COMPACT_BRIDGE_DESIGN.md` | WARN if missing |
| `ROADMAP.md` | WARN if missing |

### Check 2: STATE.json

- File exists and is valid JSON: FAIL if missing or unparseable.
- `protocol_version` field present: FAIL if missing.
- `status`, `next_actor`, `round`, `current_task_id` fields present: WARN if missing.

### Check 3: Directory Scaffold

| Directory | Severity |
|---|---|
| `.session-loop/inbox/` | FAIL if missing |
| `.session-loop/outbox/` | FAIL if missing |
| `.session-loop/reviews/` | FAIL if missing |
| `.session-loop/context/` | FAIL if missing |
| `.session-loop/logs/` | FAIL if missing |
| `.session-loop/locks/` | WARN if missing (not yet used) |
| `.session-loop/memory/` | WARN if missing |

### Check 4: Claude /loop Prompt

- `START_HERE_FOR_CLAUDE.md` contains a `/loop` command line with `*/5 * * * *` or similar cron: WARN if missing (user might configure differently).
- `START_HERE_FOR_CLAUDE.md` contains the Fresh Disk Read Rule: WARN if absent.

### Check 5: No Stale Bootstrap References

Scope: active project files only. Historical `.session-loop/inbox/`, `outbox/`, `reviews/`, `logs/`, and `memory/` contents are excluded — they are runtime history artifacts, not current configuration.

- No active project file contains `docs/session-loop-bootstrap/`: FAIL if found (stale path from old architecture).
- No active project file references `claude -p` as the primary execution model: WARN if found (known spec documents are excluded).
- No active project file references `codex exec` as the primary review model: WARN if found (known spec documents are excluded).

The project relies on Claude Code auto-compact. No custom context monitoring scripts or threshold configuration are installed or required.

### Check Summary Format

```text
PASS: 10  WARN: 2  FAIL: 0
```

Exit code 0 if FAIL count is 0. Exit code 1 if FAIL > 0.

## Install Command Shape

```powershell
# Install into a target project
.\install.ps1 -TargetPath "D:\Projects\my-paper-repro"

# Install with overwrite confirmation
.\install.ps1 -TargetPath "D:\Projects\my-paper-repro" -Force

# Dry-run (no changes)
.\install.ps1 -TargetPath "D:\Projects\my-paper-repro" -WhatIf

# Doctor-only mode (no install, just validate)
.\install.ps1 -TargetPath "D:\Projects\my-paper-repro" -Check

# Install from a specific source (default: script's own directory)
.\install.ps1 -TargetPath "D:\Projects\my-paper-repro" -SourcePath "D:\Codex_projects\persistent-agent-session-loop"
```

Parameters:

| Parameter | Required | Default | Description |
|---|---|---|---|
| `-TargetPath` | Yes | (none) | Project directory to install into |
| `-SourcePath` | No | Script directory | Where templates are read from |
| `-Force` | No | false | Overwrite existing files without prompt |
| `-WhatIf` | No | false | Show what would happen, make no changes |
| `-Check` | No | false | Run doctor checks only, no file copy |

## Uninstall or Cleanup Behavior

An `uninstall.ps1` (or `install.ps1 -Clean`) removes the session loop from a project.

**Removes:**
- `.session-loop/` directory tree (all contents).
- Root doc files that match the template hash (i.e., unmodified since install). Files the user edited are listed and skipped with a warning.

**Never removes:**
- User-edited root docs (warn and list them).
- Non-session-loop files in the project.
- Parent directories.

**Parameters:**

| Parameter | Required | Default | Description |
|---|---|---|---|
| `-TargetPath` | Yes | (none) | Project directory to clean |
| `-Force` | No | false | Remove even user-edited root docs |
| `-WhatIf` | No | false | Show what would be removed |

**Behavior:**
- If `.session-loop/outbox/` or `inbox/` contain files, warn that task/report history will be lost.
- Exit code 0 on clean removal. Exit code 1 if user-edited files block cleanup (and `-Force` not given).

## Validation Fixtures

Before the installer ships, it must pass these fixture tests:

### Fixture 1: Fresh install
- Target is an empty directory.
- Run `install.ps1 -TargetPath <tmp>`.
- All Copy Once files present, all directories created, `STATE.json` at init values, `events.jsonl` empty.
- Doctor returns zero FAIL.

### Fixture 2: Re-install onto existing init project
- Target has a prior install with `STATE.json` at `status = "init"`.
- Run `install.ps1 -TargetPath <tmp>`.
- Installer detects prior install, reports "already installed", runs doctor.
- Doctor returns zero FAIL.

### Fixture 3: Overwrite protection
- Target has user-edited `ROADMAP.md`.
- Run `install.ps1 -TargetPath <tmp>` (no `-Force`).
- Installer warns and skips `ROADMAP.md`.
- Other files updated normally.

### Fixture 4: Doctor catches missing files
- Delete `STATE.json` from an installed project.
- Run `install.ps1 -Check`.
- Doctor returns FAIL with message about missing `STATE.json`.
- Exit code 1.

### Fixture 5: Doctor catches stale references
- Create a file containing `docs/session-loop-bootstrap/something.md`.
- Run `install.ps1 -Check`.
- Doctor returns FAIL with the stale reference location.

### Fixture 6: Uninstall from clean project
- Target has only unmodified root docs and standard `.session-loop/` contents.
- Run `uninstall.ps1 -TargetPath <tmp>`.
- `.session-loop/` removed. Unmodified root docs removed. Project directory left clean.

### Fixture 7: Uninstall with user edits
- Target has user-edited `START_HERE_FOR_CLAUDE.md`.
- Run `uninstall.ps1 -TargetPath <tmp>` (no `-Force`).
- Uninstaller warns, skips `START_HERE_FOR_CLAUDE.md`, removes everything else.
- Exit code 1.

### Fixture 8: WhatIf no-op
- Run any command with `-WhatIf`.
- No filesystem changes made.

## Phase 5 Acceptance Criteria

1. `install.ps1` creates the full target layout in one command.
2. `install.ps1 -Check` (or `doctor.ps1`) validates an installation with concrete PASS / WARN / FAIL output.
3. Safety rules are enforced: no silent overwrite, no runtime state copy, no network calls.
4. Context monitoring is handled by Claude Code auto-compact; no custom context scripts are installed or validated.
5. All validation fixtures pass (validated round 23, 11/11 PASS).
6. `ROADMAP.md` reflects the completed Phase 5 deliverables.
7. The installer is self-contained: copy-pasting the source directory is sufficient to install elsewhere (no git clone required for the end user).

## Round 23 Fixture Sweep Results

All 8 standard Phase 5 fixtures plus 3 additional edge-case validations pass:

| Fixture | Description | Result |
|---|---|---|
| 1 | Fresh install | PASS |
| 2 | Re-install onto existing init project | PASS |
| 3 | Overwrite protection | PASS |
| 4 | Doctor catches missing files | PASS |
| 5 | Doctor catches stale references | PASS |
| 6 | Uninstall from clean project | PASS |
| 7 | Uninstall with user edits | PASS |
| 8 | WhatIf no-op (install + uninstall) | PASS |
| 9 | Source guard (target == source refused) | PASS |
| 10 | Force removal of user-edited project | PASS |
| 11 | WhatIf reports planned removals (removedCount) | PASS |

Two bugs found and fixed during sweep:
- `doctor.ps1`: `@()` wrapper added around `Where-Object` results for `$passCount`/`$warnCount`/`$failCount` — PS 5.1 returns a bare PSCustomObject (not array) for single matches, which lacks `.Count`
- `uninstall.ps1`: `Write-Error` replaced with `Write-Host -ForegroundColor Red` in source-guard checks — `$ErrorActionPreference = "Stop"` turned `Write-Error` into a terminating error, swallowing `exit 2`

## Round 24 Cross-Project E2E Validation

Full end-to-end flow executed in a fresh temporary project (not the source project):

1. **Install**: `install.ps1 -TargetPath <temp>` → 20 created, auto-doctor PASS
2. **Standalone doctor**: `doctor.ps1 -TargetPath <temp>` → PASS: 18 WARN: 2 FAIL: 0
3. **Check mode**: `install.ps1 -TargetPath <temp> -Check` → PASS: 18 WARN: 2 FAIL: 0
4. **Task-board readiness**: `STATE.json` at factory-fresh init values (`status: "init"`, `round: 0`, `next_actor: "codex"`), all 8 `.session-loop/` directories present, 9 root docs present
5. **Uninstall**: `uninstall.ps1 -TargetPath <temp>` → 10 removed, 0 skipped, 0 blocked, exit 0
6. **Post-uninstall**: Project directory empty, all session-loop artifacts removed

Phase 5 core (install / check / uninstall) is locally validated and release-ready. The remaining step — GitHub-hosted install path — is a user-controlled external publishing decision. All scripts are self-contained, dependency-free, and require only PowerShell 5.1+.
