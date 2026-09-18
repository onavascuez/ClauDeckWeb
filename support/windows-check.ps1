<#
  ClauDeck · Windows readiness and diagnostics

  Prints everything a support reply needs: Windows build, Stream Deck plugin version,
  whether Claude Code is installed and logged in, whether the plugin answers on its
  local port, and the last lines of its log.

  Read-only, except for one fake hook event sent to the plugin (a session named
  "windows-check" that disappears immediately afterwards). It prints no token: only
  whether the credentials file exists and the length of the string inside it.

  Run it from PowerShell, in one line:

    irm https://claudeck.dev/support/windows-check.ps1 -OutFile $env:TEMP\claudeck-check.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\claudeck-check.ps1

  Or download it and run:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\windows-check.ps1

  Then paste the whole output into your issue or discussion.
#>

$ErrorActionPreference = 'Continue'
function Section($t) { Write-Host ""; Write-Host "=== $t" -ForegroundColor Cyan }
function Ok($t)   { Write-Host "  [ok]   $t" -ForegroundColor Green }
function Warn($t) { Write-Host "  [warn] $t" -ForegroundColor Yellow }
function Bad($t)  { Write-Host "  [FAIL] $t" -ForegroundColor Red }
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$port = if ($env:CLAUDE_DECK_PORT) { $env:CLAUDE_DECK_PORT } else { "41417" }
$base = "http://127.0.0.1:$port"

Section "System"
Write-Host "  $((Get-CimInstance Win32_OperatingSystem).Caption) build $([Environment]::OSVersion.Version)"
Write-Host "  PowerShell $($PSVersionTable.PSVersion) · $([Environment]::Is64BitOperatingSystem ? 'x64' : 'x86')"

Section "Claude Code"
$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($claude) { Ok "claude at $($claude.Source) · $(& claude --version 2>&1)" } else { Bad "claude not on PATH — install with: irm https://claude.ai/install.ps1 | iex" }
$gitBash = Test-Path "C:\Program Files\Git\bin\bash.exe"
if ($gitBash) { Ok "Git for Windows present (Claude uses Git Bash for the Bash tool)" } else { Warn "No Git for Windows: Claude uses the PowerShell tool. ClauDeck's hooks should still work; report if they do not." }

Section "Credentials (what the Usage keys read)"
$cred = Join-Path $claudeDir ".credentials.json"
if (Test-Path $cred) {
  try {
    $tok = (Get-Content $cred -Raw | ConvertFrom-Json).claudeAiOauth.accessToken
    if ($tok) { Ok ".credentials.json has claudeAiOauth.accessToken (length $($tok.Length))" } else { Bad ".credentials.json exists but has no claudeAiOauth.accessToken — Usage keys will show 'no login'" }
  } catch { Bad ".credentials.json is not readable JSON: $($_.Exception.Message)" }
} else {
  Bad "No $cred — run 'claude' and log in. If Windows stores the token elsewhere, say so: win32.readOAuthToken must be adjusted."
}

Section "Session registry (gives discovery the cwd and /rename names)"
$sessions = Join-Path $claudeDir "sessions"
if (Test-Path $sessions) {
  $files = Get-ChildItem $sessions -Filter *.json -ErrorAction SilentlyContinue
  if ($files) {
    Ok "$($files.Count) file(s) in ~\.claude\sessions"
    $files | Select-Object -First 2 | ForEach-Object {
      try { $j = Get-Content $_.FullName -Raw | ConvertFrom-Json; Write-Host "    pid=$($j.pid) name=$($j.name) source=$($j.nameSource) cwd=$($j.cwd)" } catch {}
    }
  } else { Warn "sessions folder is empty — open a Claude Code session and rerun" }
} else { Bad "No $sessions — on Windows discovery would then show sessions without a project name" }

Section "Hooks in settings.json"
$settings = Join-Path $claudeDir "settings.json"
if (Test-Path $settings) {
  $raw = Get-Content $settings -Raw
  $mine = ([regex]::Matches($raw, 'claude-deck-[a-z-]+\.ps1')).Count
  if ($mine -gt 0) {
    Ok "$mine ClauDeck hook reference(s) found"
    ([regex]::Matches($raw, '"command":\s*"([^"]*claude-deck[^"]*)"')) | Select-Object -First 2 | ForEach-Object { Write-Host "    $($_.Groups[1].Value)" }
    if ($raw -match 'claude-deck-hook\.sh') { Bad "A macOS .sh hook is registered on Windows — press Remove, then Install hooks again" }
  } else { Bad "No ClauDeck hooks — add a ClauDeck key and press 'Install hooks' in its settings" }
} else { Bad "No $settings" }
$hookDir = Join-Path $claudeDir "claude-deck\hooks"
if (Test-Path $hookDir) { Ok "hook scripts: $((Get-ChildItem $hookDir).Name -join ', ')" } else { Warn "No $hookDir yet" }

Section "Plugin"
$pluginDir = Join-Path $env:APPDATA "Elgato\StreamDeck\Plugins\dev.claudeck.streamdeck.sdPlugin"
if (Test-Path $pluginDir) {
  try { Ok "ClauDeck $((Get-Content (Join-Path $pluginDir 'manifest.json') -Raw | ConvertFrom-Json).Version)" } catch { Warn "manifest unreadable" }
  $log = Get-ChildItem (Join-Path $pluginDir "logs") -Filter *.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($log) { Write-Host "  last log lines:"; Get-Content $log.FullName -Tail 6 | ForEach-Object { Write-Host "    $_" } }
} else { Bad "Plugin not installed at $pluginDir" }
$lite = Join-Path $env:APPDATA "Elgato\StreamDeck\Plugins\dev.claudeck.lite.sdPlugin"
if (Test-Path $lite) { try { Ok "ClauDeck Lite $((Get-Content (Join-Path $lite 'manifest.json') -Raw | ConvertFrom-Json).Version)" } catch {} }

Section "Plugin HTTP endpoints"
function Get-Json($path) { try { Invoke-RestMethod -Uri "$base$path" -TimeoutSec 5 } catch { $null } }
$state = Get-Json "/state"
if ($null -ne $state) {
  Ok "/state answers · $(@($state).Count) session(s)"
  @($state) | Select-Object -First 6 | ForEach-Object {
    Write-Host "    $($_.project) name=$($_.name) status=$($_.status) pid=$($_.pid) tty=$($_.tty) ctx=$($_.contextPct) discovered=$($_.discovered)"
  }
} else { Bad "/state does not answer — is the plugin running? Check the log above." }
$usage = Get-Json "/usage"
if ($null -ne $usage) { Ok "/usage · 5h=$($usage.session.percent)% 7d=$($usage.weekly.percent)% error=$($usage.error) spend=$($usage.spend.usedMinor)" } else { Warn "/usage no answer" }
$hist = Get-Json "/history"
if ($null -ne $hist) { Ok "/history · samples=$($hist.samples) hourly=$($hist.hourly) daily=$($hist.daily) rate5h=$($hist.derived.session.rate)" } else { Warn "/history no answer" }

Section "Discovery: does the plugin's process query see Claude?"
$procs = Get-CimInstance Win32_Process -Filter "Name='claude.exe' OR Name='node.exe' OR Name='bun.exe'" -Property ProcessId,ParentProcessId,Name,CommandLine,CreationDate |
  Where-Object { $_.CommandLine -match 'claude' -and $_.CommandLine -notmatch 'claude-deck' }
if ($procs) {
  Ok "$(@($procs).Count) Claude process(es) visible to CIM"
  $procs | Select-Object -First 4 | ForEach-Object {
    $sid = if ($_.CommandLine -match '--session-id\s+([0-9a-f-]{36})') { $Matches[1].Substring(0,8) } else { "none" }
    Write-Host "    pid=$($_.ProcessId) name=$($_.Name) session-id=$sid started=$($_.CreationDate)"
  }
} else { Warn "No Claude process found by CIM — open a session and rerun" }

Section "Hook round trip (sends one fake event)"
$hook = Join-Path $hookDir "claude-deck-hook.ps1"
if (Test-Path $hook) {
  $payload = '{"session_id":"windows-check","hook_event_name":"SessionStart","cwd":"C:\\Users\\Public","permission_mode":"default"}'
  $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $hook
  Start-Sleep -Seconds 1
  $after = Get-Json "/state"
  if (@($after) | Where-Object { $_.id -eq "windows-check" }) { Ok "the plugin received the fake event" } else { Bad "the fake event never arrived — the hook cannot reach $base" }
  '{"session_id":"windows-check","hook_event_name":"SessionEnd"}' | & powershell -NoProfile -ExecutionPolicy Bypass -File $hook | Out-Null
} else { Warn "No hook script to test yet" }

Section "Transcript path (context bar depends on the folder name)"
$projects = Join-Path $claudeDir "projects"
if (Test-Path $projects) {
  Ok "slug examples:"
  Get-ChildItem $projects -Directory | Select-Object -First 4 | ForEach-Object { Write-Host "    $($_.Name)" }
  Write-Host "  Expected shape for C:\Users\you\proj -> C--Users-you-proj (report if different)"
} else { Warn "No $projects yet" }

Section "Focus helper"
$focus = Join-Path $claudeDir "claude-deck\bin\focus.ps1"
if (Test-Path $focus) {
  Ok "focus.ps1 present"
  if ($procs) {
    $pid0 = @($procs)[0].ProcessId
    & powershell -NoProfile -ExecutionPolicy Bypass -File $focus -TargetPid $pid0
    Write-Host "    ran focus.ps1 -TargetPid $pid0 (exit $LASTEXITCODE; 0 means a window was raised) — did the terminal come to the front?"
  }
} else { Warn "No focus.ps1 yet: it is written the first time a key focuses a session" }

Write-Host ""
Write-Host "Done. Paste this output back, plus: did notifications appear, did a permission key light up, and did the deck show your sessions?" -ForegroundColor Cyan
