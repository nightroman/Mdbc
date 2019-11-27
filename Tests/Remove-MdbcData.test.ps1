. ./Zoo.ps1
Set-StrictMode -Version Latest

task Pipeline {
	# add docs to be removed
	$nCases = 5
	Connect-Mdbc -NewCollection
	1..5 | .{process{ @{_id = $_} }} | Add-MdbcData

	$d1 = [Mdbc.Dictionary]@{_id = 1}

	$d2 = @{_id = 2}

	$d3 = [PSCustomObject]@{_id = 3}

	class T1 {$_id}
	$d4 = [T1]::new()
	$d4._id = 4

	#! was error "must have _id"
	class T2 {[int]$Pin}
	Register-MdbcClassMap T2 -IdProperty Pin
	$d5 = [T2]::new()
	$d5.Pin = 5

 	$r = $d1, $d2, $d3, $d4, $d5 | Remove-MdbcData -Result
 	foreach($_ in $r) {equals $_.DeletedCount 1L}

 	$r = Get-MdbcData
 	equals $r $null
}

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

task BadFilter {
	Connect-Mdbc -NewCollection

	# omitted, empty, null, bad json
	Test-Error { Remove-MdbcData } -Text ([Mdbc.Res]::ParameterFilter1)
	Test-Error { Remove-MdbcData '' } -Text ([Mdbc.Res]::ParameterFilter1)
	Test-Error { Remove-MdbcData $null } -Text ([Mdbc.Res]::ParameterFilter1)
	Test-Error { Remove-MdbcData 'bar' } -Text "Parameter Filter: Invalid JSON."

	# pipeline input issues
	Test-Error { @{} | Remove-MdbcData } -Text ([Mdbc.Res]::InputDocId)
	Test-Error { $null | Remove-MdbcData } -Text ([Mdbc.Res]::InputDocNull)
}

task EmptyFilterForAll {
	Connect-Mdbc -NewCollection

	# empty hashtable
	@{_id = 1}, @{_id = 2} | Add-MdbcData
	$r = Remove-MdbcData @{} -Many -Result
	equals $r.DeletedCount 2L
	equals (Get-MdbcData) $null

	# empty json object
	@{_id = 1}, @{_id = 2} | Add-MdbcData
	$r = Remove-MdbcData '{}' -Many -Result
	equals $r.DeletedCount 2L
	equals (Get-MdbcData) $null
}
