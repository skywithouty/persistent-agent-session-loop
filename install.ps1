# Phase 5 Installer -- persistent session loop
# Usage:
#   .\install.ps1 -TargetPath "D:\Projects\my-project"
#   .\install.ps1 -TargetPath "D:\Projects\my-project" -Force
#   .\install.ps1 -TargetPath "D:\Projects\my-project" -WhatIf
#   .\install.ps1 -TargetPath "D:\Projects\my-project" -Check

param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Project directory to install into")]
    [string]$TargetPath,

    [string]$SourcePath,

    [switch]$Force,
    [switch]$Check,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$script:skippedCount = 0
$script:createdCount = 0

# Resolve SourcePath
if (-not $SourcePath) {
    $SourcePath = $PSScriptRoot
}
$SourcePath = (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path

# --- Check mode: delegate to doctor and exit ---
if ($Check) {
    $doctorScript = Join-Path $SourcePath "doctor.ps1"
    if (-not (Test-Path -LiteralPath $doctorScript)) {
        Write-Error "doctor.ps1 not found at $doctorScript"
        exit 2
    }
    Write-Host "=== Doctor check for $TargetPath ==="
    & powershell -NoProfile -ExecutionPolicy Bypass -File $doctorScript -TargetPath $TargetPath
    exit $LASTEXITCODE
}

# --- State ---
$shouldWrite = -not $WhatIf

function Write-InstallInfo($message) {
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

# --- Source validation ---
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

$allSrcFiles = $copyOnceFiles + $mergeFiles
foreach ($f in $allSrcFiles) {
    $srcFile = Join-Path $SourcePath $f
    if (-not (Test-Path -LiteralPath $srcFile)) {
        Write-Error "Source template missing: $f (expected at $srcFile)"
        exit 2
    }
}

# --- Helper: safe file copy with overwrite policy ---
function Copy-Template($sourceFile, $targetFile, $description) {
    if (Test-Path -LiteralPath $targetFile) {
        if ($Force) {
            Write-InstallInfo "$description -- overwriting (-Force)"
            if ($shouldWrite) {
                Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
            }
            $script:createdCount++
            return "copied"
        } else {
            Write-SkipWarn "$description -- already exists (use -Force to overwrite)"
            return "skipped"
        }
    } else {
        Write-InstallInfo "$description -- creating"
        if ($shouldWrite) {
            Copy-Item -LiteralPath $sourceFile -Destination $targetFile
        }
        $script:createdCount++
        return "copied"
    }
}

function New-SafeDir($path, $description) {
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        Write-InstallInfo "$description -- creating directory"
        if ($shouldWrite) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
        $script:createdCount++
    } else {
        Write-InstallInfo "$description -- already exists"
    }
}

# --- Begin install ---
Write-InstallInfo "=== Persistent Session Loop Installer ==="
Write-InstallInfo "Source : $SourcePath"
Write-InstallInfo "Target : $TargetPath"
if ($WhatIf) {
    Write-InstallInfo "Mode   : Dry-run (-WhatIf) -- no changes will be made"
}
Write-InstallInfo ""

# --- Create target directory ---
if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
    Write-InstallInfo "Creating target directory: $TargetPath"
    if ($shouldWrite) {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    }
    $script:createdCount++
}

# --- Step 1: Copy root template docs ---
Write-InstallInfo "--- Root documentation ---"

foreach ($f in $copyOnceFiles) {
    $src = Join-Path $SourcePath $f
    $dst = Join-Path $TargetPath $f
    $null = Copy-Template $src $dst $f
}

foreach ($f in $mergeFiles) {
    $src = Join-Path $SourcePath $f
    $dst = Join-Path $TargetPath $f
    $null = Copy-Template $src $dst $f
}

# --- ROADMAP.md: generate starter with Phase 1 only ---
$roadmapDst = Join-Path $TargetPath "ROADMAP.md"
if (Test-Path -LiteralPath $roadmapDst) {
    if ($Force) {
        Write-InstallInfo "ROADMAP.md -- overwriting with starter (-Force)"
        $createRoadmap = $true
    } else {
        Write-SkipWarn "ROADMAP.md -- already exists (use -Force to overwrite)"
        $createRoadmap = $false
    }
} else {
    Write-InstallInfo "ROADMAP.md -- creating starter (Phase 1 only)"
    $createRoadmap = $true
}

if ($createRoadmap -and $shouldWrite) {
@'
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
'@ | Set-Content -LiteralPath $roadmapDst -Encoding UTF8 -NoNewline
}
if ($createRoadmap) {
    $script:createdCount++
}

# --- README.md: stub if absent ---
$readmeDst = Join-Path $TargetPath "README.md"
if (Test-Path -LiteralPath $readmeDst) {
    Write-InstallInfo "README.md -- already exists, skipping"
} else {
    Write-InstallInfo "README.md -- creating minimal stub"
    if ($shouldWrite) {
@"
# $(Split-Path $TargetPath -Leaf)

This project uses a persistent session agent loop (Codex App + Claude Code) for task-driven development.

See `START_HERE_FOR_CLAUDE.md` or `START_HERE_FOR_CODEX.md` to get started.
"@ | Set-Content -LiteralPath $readmeDst -Encoding UTF8 -NoNewline
    }
    $script:createdCount++
}

# --- Step 2: Create .session-loop directory scaffold ---
Write-InstallInfo ""
Write-InstallInfo "--- .session-loop/ scaffold ---"

$loopRoot = Join-Path $TargetPath ".session-loop"

$dirs = @("inbox", "outbox", "reviews", "context", "logs", "locks", "memory", "tmp")
foreach ($d in $dirs) {
    $dirPath = Join-Path $loopRoot $d
    New-SafeDir $dirPath ".session-loop/$d/"
}

# --- Step 3: Create factory-fresh STATE.json ---
$stateDst = Join-Path $loopRoot "STATE.json"
if (Test-Path -LiteralPath $stateDst) {
    $existingState = $null
    $isInit = $false
    try {
        $existingState = Get-Content -LiteralPath $stateDst -Raw -Encoding UTF8 | ConvertFrom-Json
        $isInit = ($existingState.PSObject.Properties["status"] -and $existingState.status -eq "init")
    } catch {
        $isInit = $false
    }

    if ($Force -or $isInit) {
        $reason = if ($Force) { "-Force" } else { "existing status = 'init'" }
        Write-InstallInfo ".session-loop/STATE.json -- overwriting ($reason)"
        $createState = $true
    } else {
        Write-SkipWarn ".session-loop/STATE.json -- already exists with non-init status (use -Force to overwrite)"
        $createState = $false
    }
} else {
    Write-InstallInfo ".session-loop/STATE.json -- creating factory-fresh"
    $createState = $true
}

if ($createState -and $shouldWrite) {
    $factoryState = @{
        protocol_version = 1
        status = "init"
        round = 0
        current_task_id = ""
        last_report_id = ""
        last_review_id = ""
        next_actor = "codex"
        goal_done = $false
        stop_reason = ""
    }
    $factoryState | ConvertTo-Json -Compress | Set-Content -LiteralPath $stateDst -Encoding UTF8 -NoNewline
    $script:createdCount++
}

# --- Step 4: Create empty events.jsonl ---
$eventsDst = Join-Path $loopRoot "logs\events.jsonl"
if (Test-Path -LiteralPath $eventsDst) {
    $existingContent = Get-Content -LiteralPath $eventsDst -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($existingContent -and $existingContent.Trim().Length -gt 0) {
        if ($Force) {
            Write-InstallInfo ".session-loop/logs/events.jsonl -- overwriting non-empty file (-Force)"
            $createEvents = $true
        } else {
            Write-SkipWarn ".session-loop/logs/events.jsonl -- non-empty, skipping (use -Force to overwrite)"
            $createEvents = $false
        }
    } else {
        Write-InstallInfo ".session-loop/logs/events.jsonl -- already exists (empty), leaving as-is"
        $createEvents = $false
    }
} else {
    Write-InstallInfo ".session-loop/logs/events.jsonl -- creating empty"
    $createEvents = $true
}

if ($createEvents -and $shouldWrite) {
    New-Item -ItemType File -Path $eventsDst -Force | Out-Null
    $script:createdCount++
}

# --- Summary ---
Write-InstallInfo ""
Write-InstallInfo "=== Install complete ==="
Write-InstallInfo "Created: $script:createdCount  Skipped: $script:skippedCount"
Write-InstallInfo ""

# --- Post-install doctor ---
$doctorScript = Join-Path $SourcePath "doctor.ps1"
if (-not (Test-Path -LiteralPath $doctorScript)) {
    Write-Warning "doctor.ps1 not found at $doctorScript -- skipping validation"
    exit 0
}

# When -WhatIf, doctor would see empty/missing target, so skip it
if ($WhatIf) {
    Write-InstallInfo "[WHATIF] Would run: doctor.ps1 -TargetPath $TargetPath"
    exit 0
}

Write-InstallInfo "--- Doctor validation ---"
& powershell -NoProfile -ExecutionPolicy Bypass -File $doctorScript -TargetPath $TargetPath
exit $LASTEXITCODE
