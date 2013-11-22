
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
		assert ($r.DocumentsAffected -eq 0 -and !$r.UpdatedExisting -and $r.Ok)

		# 1 removed
		. $$
		$r = Remove-MdbcData (New-MdbcQuery x 2) -One -Result
		assert ('1 3' -eq (Get-MdbcData -Distinct _id))
		assert ($r.DocumentsAffected -eq 1 -and !$r.UpdatedExisting -and $r.Ok)

		# 2 removed
		. $$
		$r = Remove-MdbcData (New-MdbcQuery x 2) -Result
		assert (1 -eq (Get-MdbcData -Distinct _id))
		assert ($r.DocumentsAffected -eq 2 -and !$r.UpdatedExisting -and $r.Ok)

		# pipeline with _id's
		. $$
		$1, $2 = 1, 3 | Remove-MdbcData -Result
		assert (2 -eq (Get-MdbcData -Distinct _id))
		assert ($1.DocumentsAffected -eq 1 -and !$1.UpdatedExisting)
		assert ($2.DocumentsAffected -eq 1 -and !$2.UpdatedExisting)

		# pipeline with queries
		. $$
		$0, $1, $2 = @{x='miss'}, @{x=2}, @{x=1} | Remove-MdbcData -Result
		assert (!$Collection.Count())
		assert ($0.DocumentsAffected -eq 0 -and !$0.UpdatedExisting)
		assert ($1.DocumentsAffected -eq 2 -and !$1.UpdatedExisting)
		assert ($2.DocumentsAffected -eq 1 -and !$2.UpdatedExisting)
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
		assert ($r.DocumentsAffected -eq 2 -and $Collection.Count() -eq 0)

		# empty string is for _id ''
		. $$
		$r = Remove-MdbcData '' -Result
		assert ($r.DocumentsAffected -eq 1 -and $Collection.Count() -eq 1)
	}{
		$$ = { Connect-Mdbc -NewCollection; . $init }
	}{
		$$ = { Open-MdbcFile; . $init }
	}
}
