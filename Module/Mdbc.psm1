
# A few features in addition to cmdlets.

# Predefined aliases
Set-Alias query New-MdbcQuery
Set-Alias update New-MdbcUpdate

<#
.Synopsis
	Converts Mdbc data to PowerShell objects.
#>
filter Convert-MdbcData {
	New-Object PSObject -Property $_
}

<#
.Synopsis
	Converts Mdbc data to JSON strings.
#>
filter Convert-MdbcJson {
	$_.Document().ToString()
}

Export-ModuleMember -Alias * -Cmdlet * -Function *
