
<#
.Synopsis
	Argument completers for Mdbc commands.

.Description
	The script registers Mdbc completers for command parameters:

		Connect-Mdbc
			-DatabaseName ..
			-CollectionName ..

		Add-MdbcData
		New-MdbcData
		Export-MdbcData
			-Property .., ..

	Completers can be used with:

	* PowerShell v5 native Register-ArgumentCompleter
	Simply invoke Mdbc.ArgumentCompleters.ps1, e.g. in a profile.

	* TabExpansionPlusPlus https://github.com/lzybkr/TabExpansionPlusPlus
	Put Mdbc.ArgumentCompleters.ps1 to TabExpansionPlusPlus module directory in
	order to be loaded automatically. Or invoke it after importing the module,
	e.g. in a profile.

	* TabExpansion2.ps1 https://www.powershellgallery.com/packages/TabExpansion2
	Put Mdbc.ArgumentCompleters.ps1 to the path in order to be loaded on the
	first completion. Or invoke after TabExpansion2.ps1, e.g. in a profile.
#>

Register-ArgumentCompleter -CommandName Connect-Mdbc -ParameterName DatabaseName -ScriptBlock {
	param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

	if (!($ConnectionString = $boundParameters['ConnectionString'])) { $ConnectionString = '.' }

	@(Connect-Mdbc $ConnectionString *) -like "$wordToComplete*" | .{process{
		New-Object System.Management.Automation.CompletionResult $_, $_, 'ParameterValue', $_
	}}
}

Register-ArgumentCompleter -CommandName Connect-Mdbc -ParameterName CollectionName -ScriptBlock {
	param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

	if (!($ConnectionString = $boundParameters['ConnectionString'])) { $ConnectionString = '.' }
	if (!($DatabaseName = $boundParameters['DatabaseName'])) { $DatabaseName = 'test' }

	@(Connect-Mdbc $ConnectionString $DatabaseName * | ForEach-Object Name) -like "$wordToComplete*" | .{process{
		New-Object System.Management.Automation.CompletionResult $_, $_, 'ParameterValue', $_
	}}
}

Register-ArgumentCompleter -CommandName Add-MdbcData, New-MdbcData, Export-MdbcData -ParameterName Property -ScriptBlock {
	param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

	$private:data = $boundParameters['InputObject']
	if (!$data) {
		$private:ast = $commandAst.Parent
		if ($ast -isnot [System.Management.Automation.Language.PipelineAst] -or $ast.PipelineElements.Count -ne 2) {
			return
		}

		try {
			$data = & ([scriptblock]::Create($ast.PipelineElements[0]))
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

	$keys | Sort-Object -CaseSensitive | .{process{
		New-Object System.Management.Automation.CompletionResult $_, $_, 'ParameterValue', $_
	}}
}
