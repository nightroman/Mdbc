
<#
.Synopsis
	Gets file paths from the file system snapshot database.

.Description
	Requires: Mdbc module
	Server: local
	Database: test
	Collection: files

	The script searches for file paths by a name or a regular expression
	pattern. It works with data created by Update-MongoFiles.ps1.

.Parameter Name
		A file name or a regular expression to search for. The search is case
		insensitive.

.Parameter Match
		Tells that the Name is a regular expression pattern.

.Example
	> Get-MongoFile readme.txt
	Get files named "readme.txt"

.Example
	> Get-MongoFile -Match readme
	Get files which names contain "readme".

.Link
	Update-MongoFiles.ps1
#>

param
(
	[Parameter(Mandatory = $true)]$Name,
	[switch]$Match
)

Import-Module Mdbc
$collection = Connect-Mdbc . test files

if ($Match) {
	$query = New-MdbcQuery Name -Match $Name, i
}
else {
	$query = New-MdbcQuery Name -IEQ $Name
}

Get-MdbcData $collection $query -Property @() | .{process{ $_._id }}
