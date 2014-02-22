
<#
.Synopsis
	Updates the file system snapshot database.

.Description
	Server: local, database: test, collections: files, files_log
	Module: Mdbc <https://github.com/nightroman/Mdbc>

	The script scans the specified directory tree, updates file and directory
	documents, and then removes orphan documents which have not been updated.
	Changes are optionally logged in another collection.

	Collection "files"
		* _id           : full item path
		* Attributes    : file system flags
		* Length        : file length
		* LastWriteTime : last write time
		* CreationTime  : creation time
		* Name          : item name
		* Extension     : file extension
		* Updated       : last update time

	Collection "files_log"
		* _id           : full item path
		* Updated       : last update time
		* Log           : array of item snapshots
		* Op            : 0: created, 1: changed, 2: removed

.Parameter Path
		Specifies one or more literal directory paths to be processed.
.Parameter CollectionName
		Specifies the collection name. Default: files (implies files_log).
.Parameter Log
		Tells to log created, changed, and removed items to files_log.
.Parameter Split
		Tells to perform parallel data processing using Split-Pipeline.
		Module: SplitPipeline <https://github.com/nightroman/SplitPipeline>

.Inputs
	None. Use the parameters to specify input.

.Outputs
	The result object with statistics
		* Path    : the input path
		* Created : count of created
		* Changed : count of changed
		* Removed : count of removed
		* Elapsed : elapsed time span

.Link
	Get-MongoFile.ps1
#>

param
(
	[Parameter(Position=0)][string[]]$Path = '.',
	[string]$CollectionName = 'files',
	[switch]$Log,
	[switch]$Split
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$Now = [DateTime]::Now

# Resolves exact case paths.
function Resolve($Path) {
	$directory = [IO.DirectoryInfo]$Path
	if ($directory.Parent) {
		Join-Path (Resolve $directory.Parent.FullName) $directory.Parent.GetFileSystemInfos($directory.Name)[0].Name
	}
	else {
		$directory.Name.ToUpper()
	}
}
$Path = foreach($_ in $Path) { Resolve ($PSCmdlet.GetUnresolvedProviderPathFromPSPath($_)) }
Write-Host "Updating data for $Path ..."

# Connects collections and initializes data.
function Connect {
	Import-Module Mdbc
	Connect-Mdbc . test $CollectionName
	$CollectionLog = $Database.GetCollection(($CollectionName + '_log'))

	$info = 1 | Select-Object Path, Created, Changed, Removed, Elapsed
	$info.Created = $info.Changed = $info.Removed = 0
	$Update = New-MdbcUpdate -Set @{Updated = $Now}
}

# Gets input items from the path.
function Input {
	$ea = if ($PSVersionTable.PSVersion.Major -ge 3) {'Ignore'} else { 0 }
	Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction $ea
}

# Updates documents from input items.
function Update {process{
	$file = !$_.PSIsContainer

	# main data
	$data = New-MdbcData
	$data._id = $_.FullName
	$data.Attributes = [int]$_.Attributes
	if ($file) {
		$data.Length = $_.Length
		$data.LastWriteTime = $_.LastWriteTime
	}

	# query by main data and update Updated
	$r = Update-MdbcData $Update $data -Result

	# updated means not changed, done
	if ($r.DocumentsAffected) {return}

	# more data
	if (!$file) {
		$data.LastWriteTime = $_.LastWriteTime
	}
	$data.CreationTime = $_.CreationTime
	$data.Name = $_.Name
	if ($file) {
		$data.Extension = $_.Extension
	}
	$data.Updated = $Now

	# add or update data
	$r = Add-MdbcData $data -Update -Result
	$op = [int]$r.UpdatedExisting
	if ($op) {
		++$info.Changed
	}
	else {
		++$info.Created
	}
	if (!$Log) {return}

	# log created or changed
	$data.Remove('_id')
	$data.Remove('Name')
	$data.Remove('Extension')
	$data.Op = $op
	Update-MdbcData -Collection $CollectionLog -Add -Query $_.FullName -Update (
		New-MdbcUpdate -Set @{Updated = $Now; Op = $op} -Push @{Log = $data}
	)
}}

### Update existing
. Connect
$info.Path = $Path
$time = [Diagnostics.Stopwatch]::StartNew()
if ($Split) {
	Import-Module SplitPipeline
	Input | Split-Pipeline -Verbose -Count 2, 4 -Load 500, 5000 -Function Connect, Update -Variable CollectionName, Log, Now `
	-Begin { . Connect } -Script { $input | Update } -End { $info } | .{process{
		$info.Created += $_.Created
		$info.Changed += $_.Changed
	}}
}
else {
	Input | Update
}

### Remove missing
$in = foreach($_ in $Path) {
	if (!$_.EndsWith('\')) {$_ += '\'}
	[regex]('^' + [regex]::Escape($_))
}
$queryUnknown = New-MdbcQuery -Not (New-MdbcQuery Updated -Type 9)
$queryMissing = New-MdbcQuery -And (New-MdbcQuery _id -In $in), (New-MdbcQuery Updated -LT $Now)
foreach($data in Get-MdbcData (New-MdbcQuery -Or $queryUnknown, $queryMissing)) {
	++$info.Removed

	# remove data
	$id = $data._id
	Remove-MdbcData $id

	# log removed
	if ($Log) {
		$data.Remove('_id')
		$data.Remove('Name')
		$data.Remove('Extension')
		$data.Op = 2
		Update-MdbcData -Collection $CollectionLog -Add -Query $id -Update (
			New-MdbcUpdate -Set @{Updated = $Now; Op = 2} -Push @{Log = $data}
		)
	}
}

# output info
$info.Elapsed = $time.Elapsed
$info
