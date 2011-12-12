
<#
.Synopsis
	Updates the file system snapshot database.

.Description
	Server: local
	Database: test
	Collection: files

	Required modules:
	* Mdbc: <https://github.com/nightroman/Mdbc>
	* SplitPipeline: <https://github.com/nightroman/SplitPipeline> [1]
	[1] SplitPipeline is needed only with the switch -Split

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

.Parameter Split
		Tells to perform parallel data processing using Split-Pipeline from the
		SplitPipeline module. Processing of massive data is typical for tasks
		related to databases and Split-Pipeline may improve performance.

.Link
	Get-MongoFile.ps1
#>

param
(
	[Parameter()]$Path = '.',
	[switch]$Split
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

### Gets input items.
function Get-Input {
	Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction Continue
}

### New documents from input items.
function New-Document {process{
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
}}

### Update data for existing files.
$time = [Diagnostics.Stopwatch]::StartNew()
Write-Host "Updating data for existing files in $Path ..."
if ($Split) {
	Import-Module SplitPipeline
	Get-Input |
	Split-Pipeline -Auto -Load 150 -Queue 10000 -Verbose -Module Mdbc -Function New-Document `
	-Begin {
		$collection = Connect-Mdbc . test files
	} `
	-Script {
		$input | New-Document | Add-MdbcData -Update $collection -ErrorAction Continue
	}
}
else {
	Get-Input | New-Document | Add-MdbcData -Update $collection -ErrorAction Continue
}

### Remove data of missing files
$pattern = '^' + [regex]::Escape($Path)
$query = query @(
	query Updated -LT $updated
	query _id -Match $pattern
)
Write-Host "Removing data of missing files in $Path ..."
$watch2 = [Diagnostics.Stopwatch]::StartNew()
$result = Remove-MdbcData -Safe $collection $query
Write-Host "Response: $($result.Response)"
Write-Host $time.Elapsed
