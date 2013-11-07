
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

task WriteConcernResult {
	$data = {
		@{_id=1; x=1}, @{_id=2; x=2}, @{_id=3; x=2} | Add-MdbcData
	}
	Invoke-Test {
		# 0 removed
		. $$
		$r = Remove-MdbcData (New-MdbcQuery x 3) -Result
		assert ("$(Get-MdbcData -Distinct _id)" -eq '1 2 3')
		assert ($r.DocumentsAffected -eq 0)
		assert (!$r.UpdatedExisting)
		assert ($r.Ok)

		# 1 removed
		. $$
		$r = Remove-MdbcData (New-MdbcQuery x 2) -Modes Single -Result
		assert ("$(Get-MdbcData -Distinct _id)" -eq '1 3')
		assert ($r.DocumentsAffected -eq 1)
		assert (!$r.UpdatedExisting)
		assert ($r.Ok)

		# 2 removed
		. $$
		$r = Remove-MdbcData (New-MdbcQuery x 2) -Result
		assert ("$(Get-MdbcData -Distinct _id)" -eq '1')
		assert ($r.DocumentsAffected -eq 2)
		assert (!$r.UpdatedExisting)
		assert ($r.Ok)
	}{
		$$ = { Connect-Mdbc -NewCollection; . $data }
	}{
		$$ = { Open-MdbcFile; . $data }
	}
}
