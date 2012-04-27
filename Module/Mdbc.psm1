
# Helpers in addition to cmdlets.

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
