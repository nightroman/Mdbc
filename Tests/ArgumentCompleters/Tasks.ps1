
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

#! completer variable conflict ($data)
#TODO TabExpansionPlusPlus works as a script but gets nothing as a task
task Property -If ($BuildFile -notlike '*\TabExpansionPlusPlus.build.ps1') {
	$data = @{Dictionary=1}, $Host

	($r = Invoke-Complete '$data | Add-MdbcData -Property dic')
	equals $r Dictionary
	($r = Invoke-Complete '$data | Add-MdbcData -Property na')
	equals $r Name

	($r = Invoke-Complete '$data | New-MdbcData -Property dic')
	equals $r Dictionary
	($r = Invoke-Complete '$data | New-MdbcData -Property na')
	equals $r Name

	($r = Invoke-Complete '$data | Export-MdbcData -Property dic')
	equals $r Dictionary
	($r = Invoke-Complete '$data | Export-MdbcData -Property na')
	equals $r Name
}
