<#
.Synopsis
	Updates the file system snapshot collection.

.Description
	WARNING: This is a toy for making some test data, it may change without a
	notice. But it may be useful for some analysis and tracking file changes.
	Use it as the base for your own tool.

	The script scans the specified directory tree, updates file and directory
	documents, and then removes orphan documents which have not been updated.
	Changes are optionally logged to another collection.

	Server: local; database: test; collections: files, files_log (optional).

	Collection "files"
		._id  : full path
		.mode : system attributes
		.time : file write or folder create time
		.len  : file length
		.name : item name
		.ext  : file extension
		.seen : last check time

	Collection "files_log" (optional)
		._id  : full path
		.seen : check time
		.log  : array of item snapshots
		.op   : 0: created, 1: changed, 2: removed

.Parameter Path
		Specifies one or more literal directory paths to be processed.
.Parameter CollectionName
		Specifies the collection name. Default: files (implies files_log).
.Parameter Log
		Tells to log created, changed, and removed items to files_log.
.Parameter Split
		Tells to perform parallel data processing using SplitPipeline.
		Module: <https://github.com/nightroman/SplitPipeline>

.Outputs
	The result object with statistics
		.Path    : the input path
		.Created : count of created
		.Changed : count of changed
		.Removed : count of removed
		.Elapsed : elapsed time span
#>

param(
	[Parameter(Position=0)][string[]]$Path = '.',
	[string]$CollectionName = 'files',
	[switch]$Log,
	[switch]$Split
)

# Gets input items from the input paths.
function Get-Input {
	Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction Ignore
}

# Gets the exact case path for the given path.
function Resolve-Case($Path) {
	$directory = [IO.DirectoryInfo]$Path
	if ($directory.Parent) {
		Join-Path (Resolve-Case $directory.Parent.FullName) $directory.Parent.GetFileSystemInfos($directory.Name)[0].Name
	}
	else {
		$directory.Name.ToUpper()
	}
}

# Connects collections and initializes data. Dot-source this function, it
# makes the result variables $Collection, $CollectionLog, $Update, $info.
function Connect-Data {
	# connect the main and optional log collection
	Import-Module Mdbc
	Connect-Mdbc . test $CollectionName
	$CollectionLog = Get-MdbcCollection ($CollectionName + '_log')

	# update time expression used in several places
	$Update = @{'$set' = @{seen = $Now}}

	# result info, init counters
	$info = 1 | Select-Object Path, Created, Changed, Removed, Elapsed
	$info.Created = $info.Changed = $info.Removed = 0
}

# Updates documents related to input items.
function Update-Data {process{
	$isFile = !$_.PSIsContainer

	# data with _id = FullName and main changing fields
	$data = New-MdbcData -Id $_.FullName
	$data.mode = [int]$_.Attributes
	if ($isFile) {
		$data.time = $_.LastWriteTime
		$data.len = $_.Length
	}
	else {
		$data.time = $_.CreationTime
	}

	# query by main changing data and set .seen
	$r = Update-MdbcData $data $Update -Result

	# modified means $data is found, i.e. the same -> done
	if ($r.ModifiedCount) {return}

	# prepare to save changed data, add other fields
	$data.name = $_.Name
	if ($isFile) {
		$data.ext = $_.Extension
	}
	$data.seen = $Now

	# save changed data
	$qId = @{_id = $_.FullName}
	$r = Set-MdbcData $qId $data -Add -Result
	$op = [int]$r.ModifiedCount
	if ($op) {
		++$info.Changed
	}
	else {
		++$info.Created
	}

	# no log? done
	if (!$Log) {return}

	# log: remove some fields, set Op = created (0) or changed (1)
	$data.Remove('_id')
	$data.Remove('name')
	$data.Remove('ext')
	$data.op = $op
	Update-MdbcData $qId -Collection $CollectionLog -Add -Update @{
		'$set' = @{seen = $Now; op = $op}
		'$push' = @{log = $data}
	}
}}

###
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# same time for all
$Now = [DateTime]::Now

# full and exact case paths
$Path = foreach($_ in $Path) { Resolve-Case ($PSCmdlet.GetUnresolvedProviderPathFromPSPath($_)) }

### Update documents of existing input files and folders
Write-Host "Updating documents for $Path ..."

. Connect-Data
$info.Path = $Path
$time = [Diagnostics.Stopwatch]::StartNew()
if ($Split) {
	# parallel processing using SplitPipeline
	Import-Module SplitPipeline
	$param = @{
		Verbose = $true
		Count = 2, 4
		Load = 500, 5000
		Function = 'Connect-Data', 'Update-Data'
		Variable = 'CollectionName', 'Log', 'Now'
		Script = { $input | Update-Data }
		Begin = { . Connect-Data }
		End = { $info }
	}
	Get-Input | Split-Pipeline @param | .{process{
		$info.Created += $_.Created
		$info.Changed += $_.Changed
	}}
}
else {
	# normal processing
	Get-Input | Update-Data
}

### Compose some query parts (easier to read and test separately)

# query _id in the input path, use regex to match the substring
$qIdInPath = @{
	_id = @{
		'$in' = @(
			foreach($_ in $Path) {
				if (!$_.EndsWith('\')) {$_ += '\'}
				[regex]('^' + [regex]::Escape($_))
			}
		)
	}
}

# query removed from the input paths ~ with older .seen
$qNotSeen = @{'$and' = $qIdInPath, @{seen = @{'$lt' = $Now}}}

# and just in case unknown data ~ .seen is not 'date'
$qUnknown = @{seen = @{'$not' = @{'$type' = 'date'}}}

# final query for removing data
$qRemove = @{'$or' = $qUnknown, $qNotSeen}

### Remove documents of removed files and folders
Write-Host "Removing documents for $Path ..."

if ($Log) {
	# log: get data to remove, remove and log
	Get-MdbcData $qRemove | .{process{
		++$info.Removed

		# remove
		$qId = @{_id = $_._id}
		Remove-MdbcData $qId

		# log: remove some fields, set Op = removed (2)
		$_.Remove('_id')
		$_.Remove('name')
		$_.Remove('ext')
		$_.op = 2
		Update-MdbcData $qId -Collection $CollectionLog -Add -Update @{
			'$set' = @{seen = $Now; op = 2}
			'$push' = @{log = $_}
		}
	}}
}
else {
	# no log: just remove many and get result
	$r = Remove-MdbcData $qRemove -Many -Result
	$info.Removed += [int]$r.DeletedCount
}

### Complete and output results
$info.Elapsed = $time.Elapsed
$info
