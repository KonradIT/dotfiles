Invoke-Expression (&starship init powershell)
Remove-Item Alias:curl -Force -ErrorAction SilentlyContinue # use real curl.exe, not Invoke-WebRequest
$env:Path = "$HOME\scoop\shims;" + $env:Path # scoop curl (newer) beats System32 curl
del alias:cd -Force # Remove builtin cd alias to Set-Location
function cd {
	$pwd = Get-Location
	if ($args.Count -eq 0) {
		Set-Location ~
	} elseif ($args[0] -eq "-") {
		Set-Location @global:OLDPWD
	} else {
		Set-Location @args
	}
	$global:OLDPWD = $pwd
}

# Bonus: Make autocompletion work like on bash:
Set-PSReadlineKeyHandler -Key Tab -Function Complete
# Or like in zsh:
# Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
# '..' = cd .. (routes through custom cd so 'cd -' still works)
function .. { cd .. }
function ... { cd ..\.. }
