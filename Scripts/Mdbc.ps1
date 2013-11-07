
<#
.Synopsis
	Mdbc module helpers.

.Description
	NOTE: This script is a profile for interactive use, it reflects personal
	preferences, features may not be suitable for all scenarios and they may
	change. Consider this as the base for your own interactive profile.

	The script imports the module, sets aliases, functions, and variables for
	interactive use and optionally connects to a specified server and database.

	Aliases:
		amd - Add-MdbcData
		emd - Export-MdbcData
		gmd - Get-MdbcData
		gmh - Get-MdbcHelp
		imc - Invoke-MdbcCommand
		imd - Import-MdbcData
		nmd - New-MdbcData
		nmq - New-MdbcQuery
		nmu - New-MdbcUpdate
		omf - Open-MdbcFile
		rmd - Remove-MdbcData
		smf - Save-MdbcFile
		umd - Update-MdbcData

	Functions:
		Get-MdbcHelp

	Variables:
		$Server     - connected server
		$Database   - default database
		$Collection - default collection
		$m<name>    - collection <name> (for each collection)
		$<operator> - read only operator shortcuts for JSON-like expressions

	With a large number of collections their names are not displayed. Command
	Get-Variable m*..* is useful for finding a collection by its name pattern.

.Parameter ConnectionString
		Connection string, see Connect-Mdbc.
		The default is empty, the script does not connect.

.Parameter DatabaseName
		Database name or wildcard pattern. If it is not resolved to an existing
		database name then the script prints all database names and exits. The
		default name is 'test'.

.Parameter CollectionName
		Name of the default collection which instance is referenced by
		$Collection. The default is 'test', not necessarily existing.
#>

param
(
	[Parameter()]
	$ConnectionString,
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
	Invoke-MdbcCommand
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
Set-Alias -Scope global -Name emd -Value Export-MdbcData
Set-Alias -Scope global -Name gmd -Value Get-MdbcData
Set-Alias -Scope global -Name gmh -Value Get-MdbcHelp
Set-Alias -Scope global -Name imc -Value Invoke-MdbcCommand
Set-Alias -Scope global -Name imd -Value Import-MdbcData
Set-Alias -Scope global -Name nmd -Value New-MdbcData
Set-Alias -Scope global -Name nmq -Value New-MdbcQuery
Set-Alias -Scope global -Name nmu -Value New-MdbcUpdate
Set-Alias -Scope global -Name omf -Value Open-MdbcFile
Set-Alias -Scope global -Name rmd -Value Remove-MdbcData
Set-Alias -Scope global -Name smf -Value Save-MdbcFile
Set-Alias -Scope global -Name umd -Value Update-MdbcData

### Operators
@(
	'addToSet'
	'all'
	'and'
	'bit'
	'each'
	'elemMatch'
	'exists'
	'gt'
	'gte'
	'in'
	'inc'
	'lt'
	'lte'
	'mod'
	'ne'
	'nin'
	'nor'
	'not'
	'options'
	'or'
	'pop'
	'pull'
	'pullAll'
	'push'
	'pushAll'
	'regex'
	'rename'
	'set'
	'setOnInsert'
	'size'
	'slice'
	'sort'
	'type'
	'unset'
	'where'
) | .{process{ New-Variable -Name $_ -Value "`$$_" -Scope global -Option ReadOnly -Force }}

# Not connected
if (!$ConnectionString) {return}

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
