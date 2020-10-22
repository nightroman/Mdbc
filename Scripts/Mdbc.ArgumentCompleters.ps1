<#
.Synopsis
	Argument completers for Mdbc commands.

.Description
	The script adds completers for:

		Connect-Mdbc
			-DatabaseName ..
			-CollectionName ..

		Add-MdbcData
		New-MdbcData
		Export-MdbcData
			-Property .., ..

		Get-MdbcDatabase
		Get-MdbcCollection
		Remove-MdbcDatabase
		Remove-MdbcCollection
		Rename-MdbcCollection
			[-Name] ..

	How to use:

	* PowerShell v5 native
	Invoke Mdbc.ArgumentCompleters.ps1, e.g. in a profile.

	* TabExpansion2.ps1 https://www.powershellgallery.com/packages/TabExpansion2
	Put Mdbc.ArgumentCompleters.ps1 to the path.
	Or invoke after TabExpansion2.ps1, e.g. in a profile.
#>

Register-ArgumentCompleter -CommandName Connect-Mdbc -ParameterName DatabaseName -ScriptBlock {
	param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

	if (!($ConnectionString = $boundParameters['ConnectionString'])) { $ConnectionString = '.' }

	@(Connect-Mdbc $ConnectionString *) -like "$wordToComplete*" | .{process{
		New-Object System.Management.Automation.CompletionResult $_, $_, 'ParameterValue', $_
	}}
}

Register-ArgumentCompleter -CommandName Get-MdbcDatabase, Remove-MdbcDatabase -ParameterName Name -ScriptBlock {
	param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

	if (!($myClient = $boundParameters['Client'])) { $myClient = $Client }

	@(
		foreach($_ in Get-MdbcDatabase -Client $myClient) {
			$_.DatabaseNamespace.DatabaseName
		}
	) -like "$wordToComplete*" | .{process{
		New-Object System.Management.Automation.CompletionResult $_, $_, 'ParameterValue', $_
	}}
}

Register-ArgumentCompleter -CommandName Connect-Mdbc -ParameterName CollectionName -ScriptBlock {
	param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

	if (!($ConnectionString = $boundParameters['ConnectionString'])) { $ConnectionString = '.' }
	if (!($DatabaseName = $boundParameters['DatabaseName'])) { $DatabaseName = 'test' }

	@(Connect-Mdbc $ConnectionString $DatabaseName *) -like "$wordToComplete*" | .{process{
		New-Object System.Management.Automation.CompletionResult $_, $_, 'ParameterValue', $_
	}}
}

Register-ArgumentCompleter -CommandName Get-MdbcCollection, Remove-MdbcCollection, Rename-MdbcCollection -ParameterName Name -ScriptBlock {
	param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

	if (!($myDatabase = $boundParameters['Database'])) { $myDatabase = $Database }

	@(
		foreach($_ in Get-MdbcCollection -Database $myDatabase) {
			$_.CollectionNamespace.CollectionName
		}
	) -like "$wordToComplete*" | .{process{
		New-Object System.Management.Automation.CompletionResult $_, $_, 'ParameterValue', $_
	}}
}

Register-ArgumentCompleter -CommandName Add-MdbcData, New-MdbcData, Export-MdbcData -ParameterName Property -ScriptBlock {
	$private:commandName, $private:parameterName, $private:wordToComplete, $private:commandAst, $private:boundParameters = $args

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
