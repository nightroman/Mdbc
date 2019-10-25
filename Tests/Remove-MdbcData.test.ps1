
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
	Test-Error { Remove-MdbcData '' } $ErrorFilter
	Test-Error { Remove-MdbcData $null } $ErrorFilter

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
