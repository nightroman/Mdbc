
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

task Result {
	$init = { @{_id=1; x=1}, @{_id=2; x=2}, @{_id=3; x=2} | Add-MdbcData }
	Invoke-Test {
		# 0 removed
		. $$
		$r = Remove-MdbcData (New-MdbcQuery x 3) -Result
		assert ('1 2 3' -eq (Get-MdbcData -Distinct _id))
		equals $r.DocumentsAffected 0L
		equals $r.UpdatedExisting $false
		assert $r.Ok

		# 1 removed
		. $$
		$r = Remove-MdbcData (New-MdbcQuery x 2) -One -Result
		assert ('1 3' -eq (Get-MdbcData -Distinct _id))
		equals $r.DocumentsAffected 1L
		equals $r.UpdatedExisting $false
		assert $r.Ok

		# 2 removed
		. $$
		$r = Remove-MdbcData (New-MdbcQuery x 2) -Result
		equals 1 (Get-MdbcData -Distinct _id)
		equals $r.DocumentsAffected 2L
		equals $r.UpdatedExisting $false
		assert $r.Ok

		# pipeline with _id's
		. $$
		$1, $2 = 1, 3 | Remove-MdbcData -Result
		equals 2 (Get-MdbcData -Distinct _id)
		equals $1.DocumentsAffected 1L
		equals $1.UpdatedExisting $false
		equals $2.DocumentsAffected 1L
		equals $2.UpdatedExisting $false

		# pipeline with queries
		. $$
		$0, $1, $2 = @{x='miss'}, @{x=2}, @{x=1} | Remove-MdbcData -Result
		equals $Collection.Count() 0L
		equals $0.DocumentsAffected 0L
		equals $0.UpdatedExisting $false
		equals $1.DocumentsAffected 2L
		equals $1.UpdatedExisting $false
		equals $2.DocumentsAffected 1L
		equals $2.UpdatedExisting $false
	}{
		$$ = { Connect-Mdbc -NewCollection; . $init }
	}{
		$$ = { Open-MdbcFile; . $init }
	}
}

#_131121_104038
task NoQuery {
	$m = 'Parameter Query must be specified and cannot be null.'

	# omitted
	Open-MdbcFile # ensure $Collection
	Test-Error { Remove-MdbcData } $m

	# null query
	Test-Error { Remove-MdbcData $null } $m
	Test-Error { $null | Remove-MdbcData } $m

	$init = { @{_id=''}, @{_id=1} | Add-MdbcData }
	Invoke-Test {

		# empty query is for all
		. $$
		$r = Remove-MdbcData @{} -Result
		equals $r.DocumentsAffected 2L
		equals $Collection.Count() 0L

		# empty string is for _id ''
		. $$
		$r = Remove-MdbcData '' -Result
		equals $r.DocumentsAffected 1L
		equals $Collection.Count() 1L
	}{
		$$ = { Connect-Mdbc -NewCollection; . $init }
	}{
		$$ = { Open-MdbcFile; . $init }
	}
}
