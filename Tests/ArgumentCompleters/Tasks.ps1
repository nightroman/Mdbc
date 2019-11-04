
# In TabExpansionPlusPlus completers cannot see variables in calling scopes.
$IsTabExpansionPlusPlus = $BuildFile -like '*\TabExpansionPlusPlus.build.ps1'

Enter-Build {
	Import-Module Mdbc
	Connect-Mdbc -NewCollection
	@{a=1} | Add-MdbcData
}

function Invoke-Complete([Parameter()]$line, $caret=$line.Length) {
	Write-Host "Complete: $line" -ForegroundColor Magenta
	foreach($_ in (TabExpansion2 $line $caret).CompletionMatches) {
		$_.CompletionText
	}
}

task DatabaseName {
	($r = Invoke-Complete 'Connect-Mdbc . te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Connect-Mdbc -DatabaseName te')
	assert ($r -ccontains 'test')
}

task Get-MdbcDatabase.Name -If (!$IsTabExpansionPlusPlus) {
	$IsTabExpansionPlusPlus
	Connect-Mdbc .

	($r = Invoke-Complete 'Get-MdbcDatabase te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Get-MdbcDatabase -Name te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Get-MdbcDatabase -Client $Client -Name te')
	assert ($r -ccontains 'test')
}

task Remove-MdbcDatabase.Name -If (!$IsTabExpansionPlusPlus) {
	Connect-Mdbc .

	($r = Invoke-Complete 'Remove-MdbcDatabase te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Remove-MdbcDatabase -Name te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Remove-MdbcDatabase -Client $Client -Name te')
	assert ($r -ccontains 'test')
}

task CollectionName {
	($r = Invoke-Complete 'Connect-Mdbc . test te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Connect-Mdbc -CollectionName te')
	assert ($r -ccontains 'test')
}

task Get-MdbcCollection.Name -If (!$IsTabExpansionPlusPlus) {
	Connect-Mdbc . test

	($r = Invoke-Complete 'Get-MdbcCollection te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Get-MdbcCollection -Name te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Get-MdbcCollection -Database $Database te')
	assert ($r -ccontains 'test')
}

task Remove-MdbcCollection.Name -If (!$IsTabExpansionPlusPlus) {
	Connect-Mdbc . test

	($r = Invoke-Complete 'Remove-MdbcCollection te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Remove-MdbcCollection -Name te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Remove-MdbcCollection -Database $Database te')
	assert ($r -ccontains 'test')
}

task Rename-MdbcCollection.Name -If (!$IsTabExpansionPlusPlus) {
	Connect-Mdbc . test

	($r = Invoke-Complete 'Rename-MdbcCollection te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Rename-MdbcCollection -Name te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Rename-MdbcCollection -Database $Database te')
	assert ($r -ccontains 'test')
}

<#
	1. Inner completer variable $data conflicts with this test $data. Fixed by
	declaring the inner variable private.

	2. If we use `$data = ...` and pipe $data then TE++ works as a script but
	gets nothing as a task. Not fixed but it is not a real case. In reality
	TE++ is called from a prompt.
#>
task Property {
	($r = Invoke-Complete '@{Dictionary=1}, $Host | Add-MdbcData -Property dic')
	equals $r Dictionary
	($r = Invoke-Complete '@{Dictionary=1}, $Host | Add-MdbcData -Property na')
	equals $r Name

	($r = Invoke-Complete '@{Dictionary=1}, $Host | New-MdbcData -Property dic')
	equals $r Dictionary
	($r = Invoke-Complete '@{Dictionary=1}, $Host | New-MdbcData -Property na')
	equals $r Name

	($r = Invoke-Complete '@{Dictionary=1}, $Host | Export-MdbcData -Property dic')
	equals $r Dictionary
	($r = Invoke-Complete '@{Dictionary=1}, $Host | Export-MdbcData -Property na')
	equals $r Name
}

task Conflicts -If (!$IsTabExpansionPlusPlus) {
	$commandName = $parameterName = $wordToComplete = $commandAst = $boundParameters = $Host

	($r = Invoke-Complete '$commandName | New-MdbcData -Property na')
	equals $r Name

	($r = Invoke-Complete '$parameterName | New-MdbcData -Property na')
	equals $r Name

	($r = Invoke-Complete '$wordToComplete | New-MdbcData -Property na')
	equals $r Name

	($r = Invoke-Complete '$commandAst | New-MdbcData -Property na')
	equals $r Name

	($r = Invoke-Complete '$boundParameters | New-MdbcData -Property na')
	equals $r Name
}
