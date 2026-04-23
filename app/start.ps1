# Olist Trade Routes — start or restart backend + frontend
# Run from repo root: powershell -File app\start.ps1

$RepoRoot    = Split-Path $PSScriptRoot -Parent
$BackendDir  = Join-Path $PSScriptRoot "backend"
$FrontendDir = Join-Path $PSScriptRoot "frontend"
$PidFile     = Join-Path $PSScriptRoot ".running_pids"

# Look for uvicorn: project .venv first, then user Scripts, then PATH
$VenvUvicorn = Join-Path $RepoRoot ".venv\Scripts\uvicorn.exe"
$UserUvicorn = "$env:APPDATA\Python\Python314\Scripts\uvicorn.exe"
$Uvicorn = if     (Test-Path $VenvUvicorn) { $VenvUvicorn }
           elseif (Test-Path $UserUvicorn)  { $UserUvicorn }
           else                             { "uvicorn" }

# ── Kill previous instances using saved PIDs ─────────────────────────────────
Write-Host "Stopping existing processes..." -ForegroundColor Yellow

if (Test-Path $PidFile) {
    $savedPids = Get-Content $PidFile
    foreach ($entry in $savedPids) {
        $parts = $entry -split ":"
        if ($parts.Count -eq 2) {
            $winPid   = [int]$parts[0]
            $childPid = [int]$parts[1]
            taskkill /PID $childPid /F /T 2>$null
            taskkill /PID $winPid  /F /T 2>$null
        }
    }
    Remove-Item $PidFile -Force
    Start-Sleep -Milliseconds 800
}

# Safety sweep
Get-WmiObject Win32_Process -Filter "Name='python.exe'" |
    Where-Object { $_.CommandLine -like '*uvicorn*' } |
    ForEach-Object { taskkill /PID $_.ProcessId /F /T 2>$null }

$viteOwners = (netstat -ano 2>$null | Select-String ':5173\s.*LISTENING') |
    ForEach-Object { ($_ -replace '.*LISTENING\s+', '').Trim() } |
    Select-Object -Unique
foreach ($procId in $viteOwners) {
    if ($procId -match '^\d+$') { taskkill /PID $procId /F /T 2>$null }
}

Start-Sleep -Milliseconds 500

# ── Start backend ─────────────────────────────────────────────────────────────
Write-Host "Starting backend   http://localhost:8000" -ForegroundColor Cyan

$backendProc = Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command",
    "cd '$BackendDir'; & '$Uvicorn' main:app --reload --port 8000"
) -WindowStyle Normal -PassThru

Start-Sleep -Seconds 3

$uvicornChild = Get-WmiObject Win32_Process -Filter "Name='python.exe'" |
    Where-Object { $_.CommandLine -like '*uvicorn*' } |
    Select-Object -First 1

$backendChildPid = if ($uvicornChild) { $uvicornChild.ProcessId } else { $backendProc.Id }

# ── Start frontend ────────────────────────────────────────────────────────────
Write-Host "Starting frontend  http://localhost:5173" -ForegroundColor Cyan

$frontendProc = Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command",
    "cd '$FrontendDir'; npm install --prefer-offline --silent; npm run dev"
) -WindowStyle Normal -PassThru

# ── Save PIDs ─────────────────────────────────────────────────────────────────
@(
    "$($backendProc.Id):$backendChildPid",
    "$($frontendProc.Id):$($frontendProc.Id)"
) | Set-Content $PidFile

Write-Host ""
Write-Host "Both services launched." -ForegroundColor Green
Write-Host "  Backend:  http://localhost:8000/docs" -ForegroundColor Gray
Write-Host "  Frontend: http://localhost:5173"      -ForegroundColor Gray
