
. ./Zoo.ps1
Set-StrictMode -Version Latest

task Invalid {
	Connect-Mdbc . test
	Test-Error { Invoke-MdbcCommand } -Text ([Mdbc.Res]::ParameterCommand)
	Test-Error { Invoke-MdbcCommand $null } -Text ([Mdbc.Res]::ParameterCommand)
}

task GetVersion {
	Get-ServerVersion
}

task ErrorControl {
	Connect-Mdbc -NewCollection
	@{_id=1; n=1} | Add-MdbcData

	$pattern = "*Command findAndModify failed: Plan executor error during findAndModify :: caused by :: Path 'n' contains an element of non-array type 'int'.*"

	$command = New-MdbcData
	$command.findAndModify = 'test'
	$command.update = @{'$pop'=@{n=1}}

	Test-Error { Invoke-MdbcCommand $command -ErrorAction Stop } $pattern

	$r = Invoke-MdbcCommand $command -ErrorAction 0 -ErrorVariable e
	equals $r # Driver 1.10
	equals $e.Count 1
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
	"$r"
	$r.value | Out-String
	assert $r.ok # success
	equals $r.value.Count 3 # modified document

	# ditto -As PS
	$r = Invoke-MdbcCommand $command -As PS
	$r | Out-String
	equals ($r.GetType().Name) PSCustomObject
}
