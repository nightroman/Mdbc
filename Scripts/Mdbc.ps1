
<#
.Synopsis
	Interactive profile with helpers for the Mdbc module.

.Description
	NOTE: This script is a profile for interactive use, it reflects personal
	preferences, features may not be suitable for all scenarios and they may
	change. Consider this as the base for your own interactive profiles.

	The script imports the Mdbc module, connects to the server and database,
	and installs aliases, functions, and variables for interactive use.

	Aliases:
		amd - Add-MdbcData
		gmd - Get-MdbcData
		gmh - Get-MdbcHelp
		imc - Invoke-MdbcCommand
		nmd - New-MdbcData
		nmq - New-MdbcQuery
		nmu - New-MdbcUpdate
		rmd - Remove-MdbcData
		umd - Update-MdbcData

	Functions:
		Get-MdbcHelp

	Variables:
		$Server     - connected server
		$Database   - default database
		$Collection - default collection
		$m<name>    - collection <name> (for each collection)
		$<operator> - operator shortcuts for JSON-like expressions

	With a large number of collections their names are not displayed. Command
	Get-Variable m*..* is useful for finding a collection by its name pattern.

.Parameter ConnectionString
		Connection string (see the C# driver manual for details).
		The default is "." which is used for the default C# driver connection.

.Parameter DatabaseName
		Database name or wildcard pattern. If it is not resolved to an existing
		database name then the script prints all database names and exits. The
		default name is 'test'.

.Parameter CollectionName
		Name of the default collection which instance is refrenced by
		$Collection. The default is 'test', not necessarily existing.
#>

param
(
	[Parameter()]
	$ConnectionString = '.',
	$DatabaseName = 'test',
	$CollectionName = 'test'
)

Import-Module Mdbc

<#
.Synopsis
	Gets help information for MongoDB command(s).

.Description
	Command format: {Name} {L}{S}{A} {Help}.
	L - lockType  R:read-lock W:write-lock
	S - slaveOk   S:slave-ok
	A - adminOnly A:admin-only

.Parameter Name
		Command name or wildcard pattern.
		The default is '*' (all commands).

.Parameter Database
		Target database.
		The default is $Database.

.Parameter All
		Tells to get all commands including internal.

.Link
	http://www.mongodb.org/display/DOCS/Commands
#>
function global:Get-MdbcHelp([Parameter()]$Name='*', $Database=$Database, [switch]$All)
{
	$commands = (Invoke-MdbcCommand listCommands -Database $Database).commands
	foreach($cmd in $commands.Keys | .{process{if ($_ -like $Name) {$_}}}) {
		$c = $commands[$cmd]
		$help = $c.help.Trim()
		if (!$All -and ($cmd[0] -eq '_' -or $help -match '^Internal')) {continue}
		$lock = switch($c.lockType) {-1 {'R'} 1 {'W'} 0 {'-'}}
		$slave = if ($c.slaveOk) {'S'} else {'-'}
		$admin = if($c.adminOnly) {'A'} else {'-'}
		@"
$('-'*($cmd.Length))
$cmd $lock$slave$admin
$help
"@
	}
}

### Aliases
Set-Alias -Scope global -Name amd -Value Add-MdbcData
Set-Alias -Scope global -Name gmd -Value Get-MdbcData
Set-Alias -Scope global -Name gmh -Value Get-MdbcHelp
Set-Alias -Scope global -Name imc -Value Invoke-MdbcCommand
Set-Alias -Scope global -Name nmd -Value New-MdbcData
Set-Alias -Scope global -Name nmq -Value New-MdbcQuery
Set-Alias -Scope global -Name nmu -Value New-MdbcUpdate
Set-Alias -Scope global -Name rmd -Value Remove-MdbcData
Set-Alias -Scope global -Name umd -Value Update-MdbcData

### Query operators
$global:all = '$all'
$global:and = '$and'
$global:elemMatch = '$elemMatch'
$global:exists = '$exists'
$global:gt = '$gt'
$global:gte = '$gte'
$global:in = '$in'
$global:lt = '$lt'
$global:lte = '$lte'
$global:mod = '$mod'
$global:ne = '$ne'
$global:nin = '$nin'
$global:nor = '$nor'
$global:not = '$not'
$global:options = '$options'
$global:or = '$or'
$global:regex = '$regex'
$global:size = '$size'
$global:type = '$type'

### Update operators
$global:addToSet = '$addToSet'
$global:bit = '$bit'
$global:each = '$each'
$global:inc = '$inc'
$global:pop = '$pop'
$global:pull = '$pull'
$global:pullAll = '$pullAll'
$global:push = '$push'
$global:pushAll = '$pushAll'
$global:rename = '$rename'
$global:set = '$set'
$global:unset = '$unset'

# Server variable
Connect-Mdbc $ConnectionString
$global:Server = $Server
Write-Host "Server `$Server $($Server.Settings.Server)"

# Database variable
$name = @($Server.GetDatabaseNames() -like $DatabaseName)
if ($name.Count -ne 1) {
	Write-Host "Server databases: $($Server.GetDatabaseNames())"
	return
}
Write-Host "Database `$Database $name"
$global:Database = $Server.GetDatabase($name)

# Collection variables
$global:Collection = $Database.GetCollection($CollectionName)
$collections = @($Database.GetCollectionNames())
Write-Host "$($collections.Count) collections"
$global:MaximumVariableCount = 32kb
foreach($name in $collections) {
	if (!$name.StartsWith('system.')) {
		if ($collections.Count -lt 50) { Write-Host "Collection `$m$name" }
		New-Variable -Scope global -Name "m$name" -Value $Database.GetCollection($name) -ErrorAction Continue -Force
	}
}
