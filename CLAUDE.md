# Global preferences

## Editing files
- Edit project files only with the harness Edit / Write tools. Never patch or write files through python, sed, sd, Set-Content, or other shell scripts. Shell is for builds, adb, git, and reading.
- Prefer the harness Read / Grep / Glob tools over shell `cat` / `grep` / `find`. Use the shell for search only when those tools cannot do it.
- Scratch scripts and temp output go in the session scratchpad directory, written with the Write tool.

## Environment (Windows 11, user konra)
- The PowerShell tool is PowerShell 7 (pwsh, currently 7.7) started with `-NoProfile`. The user's interactive shell is the same pwsh WITH a profile that defines aliases (grep=rg, find=fd, sed=sd) and functions (pgrep, pkill, killall, kill); none of that exists for you. Do not use those names in PowerShell. Windows PowerShell 5.1 is also installed; if a session ever runs on it, `curl` is an Invoke-WebRequest alias (call `curl.exe`) and `2>&1` on native exes produces NativeCommandError noise.
- The Bash tool is Git Bash: real GNU grep/sed/find/awk/vim. `rg`, `fd`, `bat`, `sd`, `eza`, `fzf`, `jq` and `curl` are on PATH in both shells; `rg` and `fd` are good for fast search in the shell.
- To kill processes: `Stop-Process -Id <pid> -Force` or `Stop-Process -Name <name> -Force` (PowerShell), `taskkill /F /PID <pid>` (any shell).
- When you spawn `pwsh` yourself, always use `pwsh -NoProfile`: the user's profile loads PSFzf/CompletionPredictor/starship, which can hang on exit when output is redirected.

## Python
- Exactly one Python is installed: 3.15 via the Python Install Manager. `python`, `py` and `pip` all resolve to it. Do not hunt for other interpreters, probe the registry, or run `py -0p`; just use `python`.
- In Git Bash, use `python` / `python3` (resolves to `~/AppData/Local/Python/bin`). `py` is NOT usable from Git Bash: it only exists as a Store alias in WindowsApps ("Permission denied"); use the PowerShell tool for `py`.
- If `python` fails with "Permission denied", the shell has a stale PATH (Store alias first): use `/c/Users/konra/AppData/Local/Python/bin/python`. If it fails with "No Python at '...'" (exit 103), a dead virtualenv's `python.exe` launcher is first on PATH (VS Code activates the workspace's selected venv, and its base Python no longer exists). Run `python3` instead, or call `/c/Users/konra/AppData/Local/Python/bin/python`; tell the user which venv is broken (`VIRTUAL_ENV`, or the first `python` in `type -a python`). Do not search for interpreters or recreate venvs on your own.
- A fresh 3.15 has no packages: `python -m pip install -r requirements.txt` for the project before assuming imports work.
- `pip install` into the global 3.15 is fine for small tools; for a project, use a venv in the project dir.
- PlatformIO has its own private Python under `~/.platformio`. Leave it alone.

## Installing software
- Prefer Scoop (user-level, no admin), then winget. Chocolatey and anything else that writes to Program Files / ProgramData needs admin and will fail with "Access is denied".
- You cannot elevate. If a step needs admin (choco, protected paths like `C:\Python39`, machine PATH), stop and give the user the exact command to run in an admin shell instead of retrying.
- After installing, the current shell's PATH is stale. Refresh it with `$env:Path = [Environment]::GetEnvironmentVariable('Path','User') + ';' + [Environment]::GetEnvironmentVariable('Path','Machine')`.

## PowerShell gotchas
- Only on Windows PowerShell 5.1: `2>&1` on a native exe wraps stderr in NativeCommandError and sets a failing status even when the exe succeeded. Do not redirect stderr on native commands there.
- Nested quotes in `-Command` strings get mangled. For anything multi-line or quote-heavy, Write a .ps1 to the scratchpad and run it with `-File`.
- Set a timeout on anything that might wait for input or a network; do not poll background commands.
