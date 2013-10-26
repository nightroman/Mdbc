
<#
.Synopsis
	Gets file paths from the file system snapshot database.

.Description
	Requires: Mdbc module
	Server: local
	Database: test
	Collection: files (default)

	The script searches for file paths by a regular expression pattern or a
	name. It works with data created by Update-MongoFiles.ps1.

.Parameter Pattern
		Regular expression pattern or literal file name.

.Parameter CollectionName
		Specifies the collection name. Default: files.

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
	[Parameter(Position=0, Mandatory=$true)][string]$Pattern,
	$CollectionName = 'files',
	[switch]$Name
)

Import-Module Mdbc
Connect-Mdbc . test $CollectionName

if ($Name) {
	$query = New-MdbcQuery Name -IEQ $Pattern
}
else {
	$query = New-MdbcQuery Name -Matches $Pattern, i
}

foreach($_ in Get-MdbcData $query -Property @()) { $_._id }
