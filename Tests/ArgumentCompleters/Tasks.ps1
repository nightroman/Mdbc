
function Invoke-Complete([Parameter()]$line, $caret=$line.Length) {
	foreach($_ in (TabExpansion2 $line $caret).CompletionMatches) {
		$_.CompletionText
	}
}

function Enter-Build {
	Import-Module Mdbc
	Connect-Mdbc -NewCollection
	@{a=1} | Add-MdbcData
}

task DatabaseName {
	($r = Invoke-Complete 'Connect-Mdbc . te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Connect-Mdbc -DatabaseName te')
	assert ($r -ccontains 'test')
}

task CollectionName {
	($r = Invoke-Complete 'Connect-Mdbc . test te')
	assert ($r -ccontains 'test')

	($r = Invoke-Complete 'Connect-Mdbc -CollectionName te')
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

#! skip TE++, it cannot see variables in this test scenario
task Conflicts -If ($BuildFile -notlike '*\TabExpansionPlusPlus.build.ps1') {
	$commandName = $parameterName = $wordToComplete = $commandAst = $boundParameters =$Host

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
