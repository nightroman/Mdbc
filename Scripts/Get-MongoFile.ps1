
<#
.Synopsis
	Gets file paths from the file system snapshot database.

.Description
	Requires: Mdbc module
	Server: local
	Database: test
	Collection: files

	The script searches for file paths by a regular expression pattern or a
	name. It works with data created by Update-MongoFiles.ps1.

.Parameter Pattern
		Regular expression pattern or literal file name.

.Parameter Name
		Tells that the Pattern is a literal name.

.Example
	> Get-MongoFile readme
	Get files which names contain "readme".

.Example
	> Get-MongoFile readme.txt -Name
	Get files named "readme.txt"

.Link
	Update-MongoFiles.ps1
#>

param
(
	[Parameter(Mandatory=$true)][string]$Pattern,
	[switch]$Name
)

Import-Module Mdbc
Connect-Mdbc . test files

if ($Name) {
	$query = New-MdbcQuery Name -IEQ $Pattern
}
else {
	$query = New-MdbcQuery Name -Matches $Pattern, i
}

Get-MdbcData $query -Property @() | .{process{ $_._id }}
