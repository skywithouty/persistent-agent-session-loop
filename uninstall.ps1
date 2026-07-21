# Phase 5 Uninstaller -- persistent session loop
# Usage:
#   .\uninstall.ps1 -TargetPath "D:\Projects\my-project"
#   .\uninstall.ps1 -TargetPath "D:\Projects\my-project" -Force
#   .\uninstall.ps1 -TargetPath "D:\Projects\my-project" -WhatIf

param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Project directory to clean")]
    [string]$TargetPath,

    [string]$SourcePath,

    [switch]$Force,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Resolve paths
if (-not $SourcePath) {
    $SourcePath = $PSScriptRoot
}
$SourcePath = (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path
$TargetPath = (Resolve-Path -LiteralPath $TargetPath -ErrorAction Stop).Path

# --- Safety: refuse to uninstall source project ---
if ($TargetPath -eq $SourcePath) {
    Write-Host "REFUSING: TargetPath equals SourcePath ($TargetPath). Cannot uninstall the source project." -ForegroundColor Red
    exit 2
}

# --- Safety: refuse if TargetPath is a parent of SourcePath or vice versa ---
$targetRoot = (Get-Item -LiteralPath $TargetPath).FullName.TrimEnd('\')
$sourceRoot = (Get-Item -LiteralPath $SourcePath).FullName.TrimEnd('\')
if ($targetRoot.StartsWith($sourceRoot + '\') -or $sourceRoot.StartsWith($targetRoot + '\')) {
    Write-Host "REFUSING: TargetPath ($targetRoot) and SourcePath ($sourceRoot) are related. Cannot uninstall across project boundaries." -ForegroundColor Red
    exit 2
}

# --- State ---
$shouldWrite = -not $WhatIf
$script:removedCount = 0
$script:skippedCount = 0
$script:blockers = @()

function Write-UninstallInfo($message) {
    if ($WhatIf) {
        Write-Host "[WHATIF] $message" -ForegroundColor Cyan
    } else {
        Write-Host $message
    }
}

function Write-SkipWarn($message) {
    $script:skippedCount++
    Write-Warning "SKIP: $message"
}

function Add-Blocker($message) {
    $script:blockers += $message
    Write-Warning "BLOCKED: $message"
}

# --- Helper: SHA256 hash comparison ---
function Test-FileMatchesSource($targetFile, $sourceFile) {
    if (-not (Test-Path -LiteralPath $targetFile)) { return $false }
    if (-not (Test-Path -LiteralPath $sourceFile)) { return $false }
    try {
        $targetHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash
        $sourceHash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
        return $targetHash -eq $sourceHash
    } catch {
        return $false
    }
}

function Test-FileMatchesContent($targetFile, $expectedContent) {
    if (-not (Test-Path -LiteralPath $targetFile)) { return $false }
    try {
        $actual = (Get-Content -LiteralPath $targetFile -Raw -Encoding UTF8).TrimEnd()
        $expected = $expectedContent.TrimEnd()
        return $actual -eq $expected
    } catch {
        return $false
    }
}

function Remove-IfExists($path, $description) {
    if (Test-Path -LiteralPath $path) {
        Write-UninstallInfo "Removing $description"
        if ($shouldWrite) {
            try {
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
            } catch {
                Add-Blocker "Failed to remove $description : $_"
                return $false
            }
        }
        $script:removedCount++
        return $true
    }
    return $false
}

# --- Known file lists ---
$copyOnceFiles = @(
    "TASK_BOARD_PROTOCOL.md",
    "CODEX_REVIEW_RHYTHM.md",
    "SESSION_LOOP_SPEC.md",
    "PHASE4_COMPACT_BRIDGE_DESIGN.md",
    "PHASE5_INSTALLER_DESIGN.md"
)

$mergeFiles = @(
    "START_HERE_FOR_CLAUDE.md",
    "START_HERE_FOR_CODEX.md"
)

$allRootDocFiles = $copyOnceFiles + $mergeFiles + @("ROADMAP.md", "README.md")

# Generated content matching (same content as install.ps1 generates)
$roadmapStarter = @'
# Project Roadmap

## Phase 1: File Board and Claude Loop MVP

Goal: prove that one long-running Claude Code session can poll and execute a Codex task through local files.

Deliverables:

- `.session-loop/` directory scaffold
- `STATE.json`
- one example Codex task
- Claude `/loop` prompt
- one Claude report
- one Codex review

Success criteria:

- all work is done in a persistent Claude Code session (no one-shot CLI invocations)
- no stateless batch loop
- Claude keeps the same Cursor terminal session
- Codex can understand the report and decide the next step

Estimated time: 0.5 to 1 day.

## Recommended Next Step

Complete Phase 1 deliverables, then extend to a second round to validate the loop.
'@

# README stub is project-specific (contains project name), so we match on the fixed prefix
$readmePrefix = "This project uses a persistent session agent loop (Codex App + Claude Code) for task-driven development."

function Test-IsReadmeStub($targetFile) {
    if (-not (Test-Path -LiteralPath $targetFile)) { return $false }
    try {
        $content = Get-Content -LiteralPath $targetFile -Raw -Encoding UTF8
        return $content.Contains($readmePrefix)
    } catch {
        return $false
    }
}

# --- Begin uninstall ---
Write-UninstallInfo "=== Persistent Session Loop Uninstaller ==="
Write-UninstallInfo "Target : $TargetPath"
if ($WhatIf) {
    Write-UninstallInfo "Mode   : Dry-run (-WhatIf) -- no changes will be made"
}
Write-UninstallInfo ""

# --- Warn about history loss ---
$inboxPath = Join-Path $TargetPath ".session-loop\inbox"
$outboxPath = Join-Path $TargetPath ".session-loop\outbox"
$reviewsPath = Join-Path $TargetPath ".session-loop\reviews"

$inboxFiles = if (Test-Path -LiteralPath $inboxPath) { @(Get-ChildItem -LiteralPath $inboxPath -File -ErrorAction SilentlyContinue) } else { @() }
$outboxFiles = if (Test-Path -LiteralPath $outboxPath) { @(Get-ChildItem -LiteralPath $outboxPath -File -ErrorAction SilentlyContinue) } else { @() }
$reviewFiles = if (Test-Path -LiteralPath $reviewsPath) { @(Get-ChildItem -LiteralPath $reviewsPath -File -ErrorAction SilentlyContinue) } else { @() }

$historyCount = $inboxFiles.Count + $outboxFiles.Count + $reviewFiles.Count
if ($historyCount -gt 0) {
    Write-UninstallInfo "Warning: $historyCount task/report/review file(s) exist and will be removed."
    Write-UninstallInfo "  inbox:   $($inboxFiles.Count) files"
    Write-UninstallInfo "  outbox:  $($outboxFiles.Count) files"
    Write-UninstallInfo "  reviews: $($reviewFiles.Count) files"
    Write-UninstallInfo ""
}

# --- Step 1: Handle root documentation files ---
Write-UninstallInfo "--- Root documentation ---"

foreach ($f in $allRootDocFiles) {
    $targetFile = Join-Path $TargetPath $f
    $sourceFile = Join-Path $SourcePath $f

    if (-not (Test-Path -LiteralPath $targetFile)) {
        continue  # file doesn't exist, nothing to do
    }

    $shouldRemove = $false
    $reason = ""

    # Determine if this file can be safely removed
    if ($f -eq "README.md") {
        # README is installer-generated stub; check for known content pattern
        if (Test-IsReadmeStub $targetFile) {
            $shouldRemove = $true
            $reason = "installer-generated stub"
        } else {
            if ($Force) {
                $shouldRemove = $true
                $reason = "user-edited, -Force"
            } else {
                Write-SkipWarn "$f -- user-edited, not installer-generated (use -Force to remove)"
            }
        }
    } elseif ($f -eq "ROADMAP.md") {
        # Check source template first, then generated starter
        if (Test-FileMatchesSource $targetFile $sourceFile) {
            $shouldRemove = $true
            $reason = "matches source template"
        } elseif (Test-FileMatchesContent $targetFile $roadmapStarter) {
            $shouldRemove = $true
            $reason = "installer-generated starter"
        } else {
            if ($Force) {
                $shouldRemove = $true
                $reason = "user-edited, -Force"
            } else {
                Add-Blocker "$f -- user-edited (neither source template nor generated starter)"
            }
        }
    } else {
        # Copy Once or Merge file: compare against source
        if (Test-FileMatchesSource $targetFile $sourceFile) {
            $shouldRemove = $true
            $reason = "matches source template"
        } else {
            if ($Force) {
                $shouldRemove = $true
                $reason = "user-edited, -Force"
            } else {
                Add-Blocker "$f -- user-edited (use -Force to remove)"
            }
        }
    }

    if ($shouldRemove) {
        Write-UninstallInfo "$f -- removing ($reason)"
        if ($shouldWrite) {
            try {
                Remove-Item -LiteralPath $targetFile -Force -ErrorAction Stop
            } catch {
                Add-Blocker "Failed to remove $f : $_"
                $shouldRemove = $false
            }
        }
        if ($shouldRemove) {
            $script:removedCount++
        }
    }
}

# --- Step 2: Remove .session-loop/ directory ---
Write-UninstallInfo ""
Write-UninstallInfo "--- .session-loop/ removal ---"

$loopPath = Join-Path $TargetPath ".session-loop"
if (Test-Path -LiteralPath $loopPath) {
    Write-UninstallInfo "Removing .session-loop/ (full directory tree)"
    $removed = $false
    if ($shouldWrite) {
        try {
            Remove-Item -LiteralPath $loopPath -Recurse -Force -ErrorAction Stop
            $removed = $true
        } catch {
            Add-Blocker "Failed to remove .session-loop/ : $_"
        }
    } else {
        $removed = $true
    }
    if ($removed) {
        $script:removedCount++
    }
} else {
    Write-UninstallInfo ".session-loop/ not found, nothing to remove"
}

# --- Summary ---
Write-UninstallInfo ""
Write-UninstallInfo "=== Uninstall complete ==="
Write-UninstallInfo "Removed: $script:removedCount  Skipped: $script:skippedCount  Blocked: $($script:blockers.Count)"
if ($script:blockers.Count -gt 0) {
    Write-UninstallInfo "Blocked files (use -Force to remove):"
    foreach ($b in $script:blockers) {
        Write-UninstallInfo "  $b"
    }
}

if ($script:blockers.Count -gt 0) {
    exit 1
}
exit 0
