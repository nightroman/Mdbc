
# A few more features in addition to cmdlets

<#
.SYNOPSIS
	Converts Mdbc data to PowerShell objects.
#>

filter Convert-MdbcData {
	New-Object PSObject -Property $_
}

<#
.SYNOPSIS
	Converts Mdbc data to JSON strings.
#>
filter Convert-MdbcJson {
	$_.Document().ToString()
}

Set-Alias query New-MdbcQuery
Set-Alias update New-MdbcUpdate

Export-ModuleMember -Alias * -Cmdlet * -Function *
