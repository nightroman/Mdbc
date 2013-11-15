
<#
.Synopsis
	Downloads the latest package and extracts files.

.Description
	The script downloads Mdbc.zip to the current location and extracts files
	to the new directory Mdbc. If these items exist remove them manually or
	use another location.
#>

function DownloadModule([Parameter()]$PackageId) {
	$ErrorActionPreference = 'Stop'

	$here = $PSCmdlet.GetUnresolvedProviderPathFromPSPath('')
	$zip = "$here\$PackageId.zip"
	$dir = "$here\$PackageId"
	if ((Test-Path -LiteralPath $zip) -or (Test-Path -LiteralPath $dir)) {
		Write-Error "Remove '$zip' and '$dir' or use another directory."
	}

	$web = New-Object -TypeName System.Net.WebClient
	$web.UseDefaultCredentials = $true
	try {
		$web.DownloadFile("http://nuget.org/api/v2/package/$PackageId", $zip)
	}
	catch {
		Write-Error "Cannot download the package : $_"
	}

	$shell = New-Object -ComObject Shell.Application
	$from = $shell.Namespace("$zip\tools\$PackageId")
	if (!$from) {
		Write-Error "Missing package item '$zip\tools\$PackageId'."
	}

	$null = mkdir $dir
	$shell.Namespace($dir).CopyHere($from.items())
}

DownloadModule Mdbc
