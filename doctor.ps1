# Phase 5 Doctor — read-only session-loop installation validator
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File ".\doctor.ps1"
#   powershell -NoProfile -ExecutionPolicy Bypass -File ".\doctor.ps1" -TargetPath "D:\my-project"
#   powershell -NoProfile -ExecutionPolicy Bypass -File ".\doctor.ps1" -Json
#   powershell -NoProfile -ExecutionPolicy Bypass -File ".\doctor.ps1" -Quiet

param(
    [string]$TargetPath = (Get-Location).Path,
    [switch]$Json,
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"
$results = [System.Collections.ArrayList]::new()

function Add-Result($status, $check, $message, $path) {
    $r = [PSCustomObject]@{ status = $status; check = $check; message = $message }
    if ($path) { $r | Add-Member -NotePropertyName "path" -NotePropertyValue $path }
    [void]$results.Add($r)
}

# --- Check 1: Root Docs Present ---
$rootDocs = @(
    @{name="START_HERE_FOR_CLAUDE.md"; severity="FAIL"},
    @{name="START_HERE_FOR_CODEX.md"; severity="FAIL"},
    @{name="TASK_BOARD_PROTOCOL.md"; severity="FAIL"},
    @{name="CODEX_REVIEW_RHYTHM.md"; severity="FAIL"},
    @{name="SESSION_LOOP_SPEC.md"; severity="WARN"},
    @{name="PHASE4_COMPACT_BRIDGE_DESIGN.md"; severity="WARN"},
    @{name="ROADMAP.md"; severity="WARN"}
)

foreach ($doc in $rootDocs) {
    $docPath = Join-Path $TargetPath $doc.name
    if (Test-Path -LiteralPath $docPath) {
        Add-Result "PASS" "root_docs" "$($doc.name) present" $docPath
    } else {
        Add-Result $doc.severity "root_docs" "$($doc.name) missing" $docPath
    }
}

# --- Check 2: STATE.json ---
$statePath = Join-Path $TargetPath ".session-loop\STATE.json"
if (-not (Test-Path -LiteralPath $statePath)) {
    Add-Result "FAIL" "state_json" ".session-loop\STATE.json missing" $statePath
} else {
    try {
        $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $hasProto = $state.PSObject.Properties["protocol_version"] -and $null -ne $state.protocol_version
        $hasStatus = $state.PSObject.Properties["status"] -and $state.PSObject.Properties["next_actor"] -and $state.PSObject.Properties["round"] -and $state.PSObject.Properties["current_task_id"]
        if ($hasProto) {
            Add-Result "PASS" "state_json" ".session-loop\STATE.json valid JSON, protocol_version=$($state.protocol_version)" $statePath
        } else {
            Add-Result "FAIL" "state_json" ".session-loop\STATE.json missing protocol_version field" $statePath
        }
        if (-not $hasStatus) {
            Add-Result "WARN" "state_json" ".session-loop\STATE.json missing status/next_actor/round/current_task_id fields" $statePath
        }
    } catch {
        Add-Result "FAIL" "state_json" ".session-loop\STATE.json not valid JSON: $_" $statePath
    }
}

# --- Check 3: Directory Scaffold ---
$dirs = @(
    @{name="inbox"; severity="FAIL"},
    @{name="outbox"; severity="FAIL"},
    @{name="reviews"; severity="FAIL"},
    @{name="context"; severity="FAIL"},
    @{name="logs"; severity="FAIL"},
    @{name="locks"; severity="WARN"},
    @{name="memory"; severity="WARN"}
)

foreach ($dir in $dirs) {
    $dirPath = Join-Path $TargetPath ".session-loop\$($dir.name)"
    if (Test-Path -LiteralPath $dirPath -PathType Container) {
        Add-Result "PASS" "dir_scaffold" ".session-loop/$($dir.name)/ exists" $dirPath
    } else {
        Add-Result $dir.severity "dir_scaffold" ".session-loop/$($dir.name)/ missing" $dirPath
    }
}

# --- Check 4: Claude /loop Prompt ---
$shcfPath2 = Join-Path $TargetPath "START_HERE_FOR_CLAUDE.md"
if (Test-Path -LiteralPath $shcfPath2) {
    $shcf2 = Get-Content -LiteralPath $shcfPath2 -Raw -Encoding UTF8
    if ($shcf2 -match "/loop") {
        Add-Result "PASS" "loop_prompt" "START_HERE_FOR_CLAUDE.md contains /loop reference" $shcfPath2
    } else {
        Add-Result "WARN" "loop_prompt" "START_HERE_FOR_CLAUDE.md does not reference /loop" $shcfPath2
    }
    if ($shcf2 -match "Fresh Disk Read Rule") {
        Add-Result "PASS" "fresh_disk_read" "START_HERE_FOR_CLAUDE.md contains Fresh Disk Read Rule" $shcfPath2
    } else {
        Add-Result "WARN" "fresh_disk_read" "START_HERE_FOR_CLAUDE.md missing Fresh Disk Read Rule" $shcfPath2
    }
} else {
    Add-Result "WARN" "loop_prompt" "START_HERE_FOR_CLAUDE.md missing; cannot check /loop prompt"
    Add-Result "WARN" "fresh_disk_read" "START_HERE_FOR_CLAUDE.md missing; cannot check Fresh Disk Read Rule"
}

# --- Check 5: No Stale Bootstrap References ---
$staleFound = $false
$claudePFound = $false
$codexExecFound = $false

$excludeFromCheck5 = @("doctor.ps1", "SESSION_LOOP_SPEC.md", "PHASE5_INSTALLER_DESIGN.md", "PHASE4_COMPACT_BRIDGE_DESIGN.md")
$historyDirs = @(
    [System.IO.Path]::Combine($TargetPath, ".session-loop", "inbox"),
    [System.IO.Path]::Combine($TargetPath, ".session-loop", "outbox"),
    [System.IO.Path]::Combine($TargetPath, ".session-loop", "reviews"),
    [System.IO.Path]::Combine($TargetPath, ".session-loop", "logs"),
    [System.IO.Path]::Combine($TargetPath, ".session-loop", "memory")
)
Get-ChildItem -LiteralPath $TargetPath -Recurse -Include "*.md","*.ps1","*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -in $excludeFromCheck5) { return }
    foreach ($hd in $historyDirs) {
        if ($_.FullName.StartsWith($hd, [StringComparison]::OrdinalIgnoreCase)) { return }
    }
    $content = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    if ($content -match "docs/session-loop-bootstrap") {
        Add-Result "FAIL" "stale_bootstrap" "stale bootstrap reference 'docs/session-loop-bootstrap' found" $_.FullName
        $staleFound = $true
    }

    if ($content -match "claude -p") {
        Add-Result "WARN" "stale_claude_p" "'claude -p' reference found (may indicate stale batch-loop assumption)" $_.FullName
        $claudePFound = $true
    }

    if ($content -match "codex exec") {
        Add-Result "WARN" "stale_codex_exec" "'codex exec' reference found (may indicate stale batch-loop assumption)" $_.FullName
        $codexExecFound = $true
    }
}

if (-not $staleFound) {
    Add-Result "PASS" "stale_bootstrap" "no stale docs/session-loop-bootstrap references found"
}
if (-not $claudePFound) {
    Add-Result "PASS" "stale_claude_p" "no unexpected 'claude -p' references found"
}
if (-not $codexExecFound) {
    Add-Result "PASS" "stale_codex_exec" "no unexpected 'codex exec' references found"
}

# --- Output ---
$passCount = @($results | Where-Object { $_.status -eq "PASS" }).Count
$warnCount = @($results | Where-Object { $_.status -eq "WARN" }).Count
$failCount = @($results | Where-Object { $_.status -eq "FAIL" }).Count

if ($Json) {
    $output = [PSCustomObject]@{
        ts = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
        target = (Resolve-Path -LiteralPath $TargetPath -ErrorAction SilentlyContinue).Path
        summary = "PASS: $passCount  WARN: $warnCount  FAIL: $failCount"
        pass = $passCount
        warn = $warnCount
        fail = $failCount
        results = $results
    }
    $output | ConvertTo-Json -Depth 3
} else {
    if (-not $Quiet) {
        $results | ForEach-Object {
            $prefix = switch ($_.status) { "PASS" { "[PASS]" }; "WARN" { "[WARN]" }; "FAIL" { "[FAIL]" }; default { "[????]" } }
            $loc = if ($_.path) { " ($($_.path))" } else { "" }
            Write-Output "$prefix $($_.check): $($_.message)$loc"
        }
    } else {
        # In quiet mode, only output WARN and FAIL
        $results | Where-Object { $_.status -ne "PASS" } | ForEach-Object {
            $prefix = switch ($_.status) { "WARN" { "[WARN]" }; "FAIL" { "[FAIL]" }; default { "[????]" } }
            $loc = if ($_.path) { " ($($_.path))" } else { "" }
            Write-Output "$prefix $($_.check): $($_.message)$loc"
        }
    }
    Write-Output "PASS: $passCount  WARN: $warnCount  FAIL: $failCount"
}

if ($failCount -gt 0) { exit 1 } else { exit 0 }
