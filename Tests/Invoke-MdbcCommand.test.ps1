
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

task Invalid {
	Connect-Mdbc . test
	Test-Error { Invoke-MdbcCommand 1 } '*Exception setting "Command": "Invalid command object type."'
}

task ErrorControl {
	Connect-Mdbc -NewCollection
	@{_id=1; n=1} | Add-MdbcData

	$pattern = '*Can only $pop from arrays.*'

	$command = New-MdbcData
	$command.findAndModify = 'test'
	$command.update = @{'$pop'=@{n=1}}

	Test-Error { Invoke-MdbcCommand $command -ErrorAction Stop } $pattern

	$r = Invoke-MdbcCommand $command -ErrorAction 0 -ErrorVariable e
	assert ($null -eq $r) # Driver 1.10
	assert ($e.Count -eq 1)
	assert ($e[0] -like $pattern)
}

task findAndModify {
	Connect-Mdbc -NewCollection

	# add data
	@{_id=1; created=Get-Date} | Add-MdbcData

	# modify data
	$command = New-MdbcData
	$command.findAndModify = 'test'
	$command.update = @{'$set'=@{modified=Get-Date}}
	$command.new = $true

	#! fixed Get-Date -> BsonValue
	$r = Invoke-MdbcCommand $command
	$r.value
	assert ($r.ok) # success
	assert ($r.value.Count -eq 3) # modified document
}
