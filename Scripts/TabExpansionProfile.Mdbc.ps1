
<#
.Synopsis
	TabExpansion2 profile for Mdbc.

.Description
	Use this profile with the custom TabExpansion2
	https://farnet.googlecode.com/svn/trunk/PowerShellFar/TabExpansion2.ps1

	Normally TabExpansion2.ps1 should be called in the very beginning of a
	session from a PowerShell profile. This script should be placed to the
	system path. It will be called on the first code completion.

	This completion profile adds completers for the following arguments:

		Connect-Mdbc
			DatabaseName
			CollectionName
#>

$TabExpansionOptions.CustomArgumentCompleters += @{
	'Connect-Mdbc:DatabaseName' = {
		param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)
		if (!($ConnectionString = $boundParameters['ConnectionString'])) { $ConnectionString = '.' }
		@(Connect-Mdbc $ConnectionString *) -like "$wordToComplete*"
	}
	'Connect-Mdbc:CollectionName' = {
		param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)
		if (!($ConnectionString = $boundParameters['ConnectionString'])) { $ConnectionString = '.' }
		if (!($DatabaseName = $boundParameters['DatabaseName'])) { $DatabaseName = 'test' }
		@(Connect-Mdbc $ConnectionString $DatabaseName * | ForEach-Object Name) -like "$wordToComplete*"
	}
}
