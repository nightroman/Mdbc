
<#
.Synopsis
	Updates the file system snapshot database.

.Description
	Requires: Mdbc module
	Server: local
	Database: test
	Collection: files

	The script scans the specified directory tree, updates file and directory
	documents, and then removes orphan documents that have not been updated.

	This is rather a toy for making a data collection for experiments. But
	these data are still useful for some tasks. Example: Get-MongoFile.ps1.

	Fields are similar to [FileInfo] and [DirectoryInfo] properties:
	* _id : String : FullName property
	* Name : String
	* Extension : String
	* Updated : DateTime : document update time
	* CreationTime : DateTime
	* LastWriteTime : DateTime
	* Attributes : Int32 : Attributes converted to Int32
	* Length : Int64 : exists for files only

.Parameter Path
		The directory path which contents has to be updated in the test.test
		collection. Note that for paths like C:\ it may take several minutes.
		PowerShell Get-ChildItem is relatively slow.

.Link
	Get-MongoFile.ps1
#>

param
(
	$Path = '.'
)

Set-StrictMode -Version 2
$updated = [DateTime]::Now

# Resolves exact case sensitive paths
function Resolve-ExactCasePath($Path) {
	$directory = [IO.DirectoryInfo]$Path
	if ($directory.Parent) {
		Join-Path (Resolve-ExactCasePath $directory.Parent.FullName) $directory.Parent.GetFileSystemInfos($directory.Name)[0].Name
	}
	else {
		$directory.Name.ToUpper()
	}
}
$Path = Resolve-ExactCasePath $Path
if (!$Path.EndsWith('\')) {
	$Path += '\'
}

Import-Module Mdbc
$collection = Connect-Mdbc . test files

### Update data for existing files

Write-Host "Updating data for existing files in $Path ..."
$watch = [Diagnostics.Stopwatch]::StartNew()
Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction Continue | .{process{
	$document = New-MdbcData -DocumentId $_.FullName
	$document.Name = $_.Name
	$document.Extension = $_.Extension
	$document.Updated = $updated
	$document.CreationTime = $_.CreationTime
	$document.LastWriteTime = $_.LastWriteTime
	$document.Attributes = [int]$_.Attributes
	if (!$_.PSIsContainer) {
		$document.Length = $_.Length
	}
	$document
}} |
Add-MdbcData -Update $collection -ErrorAction Continue
Write-Host $watch.Elapsed

### Remove data of missing files

$pattern = '^' + [regex]::Escape($Path)
$query = query @(
	query Updated -LT $updated
	query _id -Match $pattern
)

Write-Host "Removing data of missing files in $Path ..."
$watch = [Diagnostics.Stopwatch]::StartNew()

Remove-MdbcData -Safe $collection $query
Write-Host $watch.Elapsed
