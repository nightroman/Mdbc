
<#
.Synopsis
	TabExpansion2 profile for Mdbc.

.Description
	This script should be in the path. It is invoked on the first call of the
	custom TabExpansion2. It adds code completers to the global option table.
	https://github.com/nightroman/FarNet/blob/master/PowerShellFar/TabExpansion2.ps1

	Completers are added for arguments of

	Connect-Mdbc
		-DatabaseName ..
		-CollectionName ..

	Add-MdbcData
	New-MdbcData
	Export-MdbcData
		-Property .., ..
#>

# Common Property completer
$completeProperty = {
	param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

	$data = $boundParameters['InputObject']
	if (!$data) {
		$ast = $commandAst.Parent
		if ($ast -isnot [System.Management.Automation.Language.PipelineAst] -or $ast.PipelineElements.Count -ne 2) {
			return
		}

		try {
			$data = Invoke-Expression $ast.PipelineElements[0]
		}
		catch {
			return
		}
	}

	$keys = [System.Collections.Generic.HashSet[object]]@()
	$pattern = "$wordToComplete*"
	foreach($_ in $data) {
		if ($_ -is [System.Collections.IDictionary]) {
			foreach($_ in $_.Keys -like $pattern) { $null = $keys.Add($_) }
		}
		elseif ($_) {
			foreach($_ in $_.PSObject.Properties.Match($pattern)) { $null = $keys.Add($_.Name) }
		}
	}

	$keys | Sort-Object -CaseSensitive | .{process{ New-CompletionResult $_ }}
}

# Add completers
$TabExpansionOptions.CustomArgumentCompleters += @{
	'Add-MdbcData:Property' = $completeProperty
	'New-MdbcData:Property' = $completeProperty
	'Export-MdbcData:Property' = $completeProperty

	'Connect-Mdbc:DatabaseName' = {
		param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

		if (!($ConnectionString = $boundParameters['ConnectionString'])) { $ConnectionString = '.' }

		@(Connect-Mdbc $ConnectionString *) -like "$wordToComplete*" |
		.{process{ New-CompletionResult $_ }}
	}

	'Connect-Mdbc:CollectionName' = {
		param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

		if (!($ConnectionString = $boundParameters['ConnectionString'])) { $ConnectionString = '.' }
		if (!($DatabaseName = $boundParameters['DatabaseName'])) { $DatabaseName = 'test' }

		@(Connect-Mdbc $ConnectionString $DatabaseName * | ForEach-Object Name) -like "$wordToComplete*" |
		.{process{ New-CompletionResult $_ }}
	}
}
