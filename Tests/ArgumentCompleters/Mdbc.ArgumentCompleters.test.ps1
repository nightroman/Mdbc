
task TabExpansion2 {
	$pwsh = if ($PSEdition -eq 'Core') {'pwsh'} else {'powershell'}
	exec { & $pwsh -NoProfile -Command Invoke-Build * Mdbc.ArgumentCompleters.build.ps1 }
}
