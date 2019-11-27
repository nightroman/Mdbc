
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

task Result {
	$$ = {
		Connect-Mdbc -NewCollection
		@{_id=1; x=1}, @{_id=2; x=2}, @{_id=3; x=2} | Add-MdbcData
	}

	# 0 removed
	. $$
	$r = Remove-MdbcData @{x=3} -Many -Result
	assert ('1 2 3' -eq (Get-MdbcData -Distinct _id))
	equals $r.DeletedCount 0L

	# 1 removed
	. $$
	$r = Remove-MdbcData @{x=2} -Result
	assert ('1 3' -eq (Get-MdbcData -Distinct _id))
	equals $r.DeletedCount 1L

	# 2 removed
	. $$
	$r = Remove-MdbcData @{x=2} -Many -Result
	equals 1 (Get-MdbcData -Distinct _id)
	equals $r.DeletedCount 2L
}

#_131121_104038
task NoFilter {
	# omitted, empty, null
	Connect-Mdbc -NewCollection
	Test-Error { Remove-MdbcData } $ErrorFilter
	#Test-Error { Remove-MdbcData '' } $ErrorFilter #TODO
	Test-Error { Remove-MdbcData $null } $ErrorFilter
	Test-Error { $null | Remove-MdbcData } -Text $TextInputDocNull
	Test-Error { @{} | Remove-MdbcData } -Text $TextInputDocId

	$$ = {
		Connect-Mdbc -NewCollection
		@{_id=''}, @{_id=1} | Add-MdbcData
	}

	# empty query is for all
	. $$
	$r = Remove-MdbcData @{} -Many -Result
	equals $r.DeletedCount 2L
	equals (Get-MdbcData -Count) 0L

	# empty string _id
	. $$
	$r = Remove-MdbcData '{_id : ""}' -Result
	equals $r.DeletedCount 1L
	equals (Get-MdbcData -Count) 1L
}

task TODO {
	$d1 = [Mdbc.Dictionary]1
	equals $d1._id.GetType().Name String # why, PS?

	$d1 = [Mdbc.Dictionary]::new(1)
	equals $d1._id.GetType().Name Int32
}

task Input {
	Connect-Mdbc -NewCollection
	@{_id = 1}, @{_id = 2}, @{_id = 3}, @{_id = 4} | Add-MdbcData

	$d1 = [Mdbc.Dictionary]@{_id = 1}
	$d2 = @{_id = 2}
	$d3 = [PSCustomObject]@{_id = 3}
	class T1 {$_id}
	$d4 = [T1]::new()
	$d4._id = 4

 	$r = $d1, $d2, $d3, $d4 | Remove-MdbcData -Result
 	foreach($_ in $r) {equals $_.DeletedCount 1L}

 	$r = Get-MdbcData
 	equals $r $null
}
