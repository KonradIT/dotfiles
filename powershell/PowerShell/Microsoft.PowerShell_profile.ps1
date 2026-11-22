# starship init is slow (~500ms via iex); cache the generated init script (and its continuation prompt,
# which would otherwise spawn starship.exe on every startup).
# After upgrading starship or changing [continuation_prompt], run: Remove-Item ~\.cache\starship-init.ps1
$starshipInit = "$HOME\.cache\starship-init.ps1"
if (-not (Test-Path $starshipInit)) {
	$starshipExe = (Get-Command starship -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
	if ($starshipExe) {
		New-Item -ItemType Directory -Force (Split-Path $starshipInit) | Out-Null
		$cont = (& $starshipExe prompt --continuation) -join ''
		$init = (& $starshipExe init powershell --print-full-init) -join "`n"
		$init = $init -replace '(?s)Set-PSReadLineOption -ContinuationPrompt \(.*?\n    \)', { "Set-PSReadLineOption -ContinuationPrompt '" + ($cont -replace "'", "''") + "'" }
		Set-Content $starshipInit $init -Encoding utf8
	}
}
if (Test-Path $starshipInit) { . $starshipInit }
$env:Path = "$HOME\scoop\shims;" + $env:Path # scoop curl (newer) beats System32 curl
# PS7 has no 'curl' alias and supports native 'cd -', so the old custom cd and alias removal are gone.

# Tab completes like bash (common prefix + list), not cycling
Set-PSReadlineKeyHandler -Key Tab -Function Complete
# Or like in zsh:
# Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Predictive IntelliSense: history + completion-engine suggestions (Right Arrow / End to accept)
Import-Module CompletionPredictor
if ($Host.UI.SupportsVirtualTerminal -and -not [Console]::IsOutputRedirected) {
	Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle InlineView
}

# Ctrl+R = fuzzy history search (fzf). PSFzf takes ~1s to import, so it loads on the first Ctrl+R press;
# after that PSFzf's own Ctrl+R binding takes over.
$env:FZF_DEFAULT_OPTS = '--height=40% --layout=reverse --border'
Set-PSReadLineKeyHandler -Chord Ctrl+r -BriefDescription 'FuzzyHistory' -ScriptBlock {
	if (-not (Get-Module PSFzf)) {
		Import-Module PSFzf -Global
		Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'
	}
	Invoke-FzfPsReadlineHandlerHistory
}

# Terminal-Icons takes ~1s to import, so load it once after the first prompt is shown (needs a Nerd Font)
$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
	Import-Module Terminal-Icons -Global
}

# --- unix-style process tools ---
Set-Alias htop btop

function pgrep {
	# pgrep <regex>  -> "PID name" for each process whose name matches
	$pattern = $args | Where-Object { "$_" -notmatch '^-' } | Select-Object -First 1
	if (-not $pattern) { Write-Error "usage: pgrep <name-regex>"; return }
	Get-Process | Where-Object { $_.ProcessName -match $pattern } | ForEach-Object { "{0,7} {1}" -f $_.Id, $_.ProcessName }
}

function pkill {
	# pkill [-9] <regex>  -> kill every process whose name matches (always a hard kill on Windows)
	$pattern = $args | Where-Object { "$_" -notmatch '^-' } | Select-Object -First 1
	if (-not $pattern) { Write-Error "usage: pkill [-9] <name-regex>"; return }
	$procs = @(Get-Process | Where-Object { $_.ProcessName -match $pattern -and $_.Id -ne $PID })
	if (-not $procs) { Write-Error "pkill: no process matches '$pattern'"; return }
	$procs | ForEach-Object { "killing {0} {1}" -f $_.Id, $_.ProcessName }
	$procs | Stop-Process -Force
}

function killall {
	# killall <name>  -> kill processes with exactly this name ('.exe' optional)
	$name = ($args | Where-Object { "$_" -notmatch '^-' } | Select-Object -First 1) -replace '\.exe$', ''
	if (-not $name) { Write-Error "usage: killall <name>"; return }
	$procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
	if (-not $procs) { Write-Error "killall: no process named '$name'"; return }
	$procs | ForEach-Object { "killing {0} {1}" -f $_.Id, $_.ProcessName }
	$procs | Stop-Process -Force
}

Remove-Item Alias:kill -Force -ErrorAction SilentlyContinue # builtin alias would shadow this function
function kill {
	# kill [-9|-KILL|-SIGKILL|...] <pid> [pid...]  -> signal flags are accepted and ignored; always a hard kill
	$ids = $args | Where-Object { "$_" -match '^\d+$' }
	if (-not $ids) { Write-Error "usage: kill [-9] <pid>..."; return }
	Stop-Process -Id $ids -Force
}

# --- modern replacements for the classic tools (interactive pwsh only; scripts/bash are unaffected) ---
Set-Alias grep rg   # NOTE: rg flags differ from grep (e.g. -r is --replace; rg is recursive by default)
Set-Alias find fd   # NOTE: fd syntax differs from find: fd <pattern> [path]
Set-Alias sed sd    # NOTE: sd syntax differs from sed: sd '<regex>' '<replacement>' [files]

# '..' = cd ..
function .. { cd .. }
function ... { cd ..\.. }
