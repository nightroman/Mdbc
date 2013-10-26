
<#
.Synopsis
	Updates the file system snapshot database.

.Description
	Server: local, database: test, collection: files (by default)

	Required modules:
	* Mdbc: <https://github.com/nightroman/Mdbc>
	* SplitPipeline: <https://github.com/nightroman/SplitPipeline> is needed
	if the switch -Split is used

	The script scans the specified directory tree, updates file and directory
	documents, and then removes orphan documents which have not been updated.
	This is rather a toy for making a data collection for experiments.

	Fields reflect some [FileInfo] and [DirectoryInfo] properties:
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

.Parameter CollectionName
		Specifies the collection name. Default: files.

.Parameter Split
		Tells to perform parallel data processing using Split-Pipeline from the
		SplitPipeline module. Processing of massive data is typical for tasks
		related to databases and Split-Pipeline may improve performance.

.Link
	Get-MongoFile.ps1
#>

param
(
	[Parameter(Position=0)]$Path = '.',
	$CollectionName = 'files',
	[switch]$Split
)

Set-StrictMode -Version 2
$Updated = [DateTime]::Now

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
$Path = Resolve-ExactCasePath ($PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path))
if (!$Path.EndsWith('\')) {
	$Path += '\'
}

Import-Module Mdbc
Connect-Mdbc . test $CollectionName

### Gets input items.
function Get-Input {
	Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction Continue
}

### New documents from input items.
function New-Document {process{
	$document = New-MdbcData -Id $_.FullName
	$document.Name = $_.Name
	$document.Extension = $_.Extension
	$document.Updated = $Updated
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
	Split-Pipeline -Auto -Load 100, 5000 -Verbose -Module Mdbc -Function New-Document -Variable Updated, CollectionName `
	-Begin {
		Connect-Mdbc . test $CollectionName
	} `
	-Script {
		$input | New-Document | Add-MdbcData -Update -ErrorAction Continue
	}
}
else {
	Get-Input | New-Document | Add-MdbcData -Update -ErrorAction Continue
}

### Remove "unknown" data
Write-Host "Removing unknown data..."
$result = Remove-MdbcData (New-MdbcQuery Updated -NotExists) -Result
Write-Host $result.Response

### Remove data of missing files
$pattern = '^' + [regex]::Escape($Path)
$query = New-MdbcQuery -And (New-MdbcQuery Updated -LT $Updated), (New-MdbcQuery _id -Matches $pattern)
Write-Host "Removing data of missing files in $Path ..."
$result = Remove-MdbcData $query -Result
Write-Host $result.Response
Write-Host $time.Elapsed
