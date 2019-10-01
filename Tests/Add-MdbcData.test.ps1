
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

task BadId {
	$d = @{_id = 1,2}
	Invoke-Test {
		Test-Error { $d | Add-MdbcData } "*Can't use an array for _id*"
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

#_131119_113717
task Duplicate {
	Invoke-Test {
		# true is not 1
		@{_id=1}, @{_id=$true} | Add-MdbcData

		# same 2 and 2L
		Test-Error { @{_id=2}, @{_id=2L} | Add-MdbcData } '*duplicate*'

		# same 3 and 3.0
		Test-Error { @{_id=3}, @{_id=3.0} | Add-MdbcData } '*duplicate*'

		# same documents
		Test-Error { @{_id=@{y=4}}, @{_id=@{y=4.0}} | Add-MdbcData } '*duplicate*'
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task ErrorTargetObject {
	Invoke-Test {
		# add and get result
		@{_id=1; x=1}, @{_id=1; x=2} | Add-MdbcData -ErrorAction 0 -ErrorVariable e
		$r = Get-MdbcData
		Test-Table @{_id=1; x=1} $r
		assert ($e -like $131111_121454) $e
		equals $e.TargetObject.x 2
	}{
		Connect-Mdbc -NewCollection
		$131111_121454 = '*E11000 duplicate key error*dup key: { _id: 1 }*'
	}{
		Open-MdbcFile
		$131111_121454 = 'Duplicate _id 1.'
	}
}

task WithSameIdAndWithUpdate {
	Invoke-Test {
		# New document
		$document = New-MdbcData
		$document._id = 131107103027
		$document.Name = 'Hello'

		# Add the document
		$document | Add-MdbcData

		# To add with the same _id and another Name
		$document.Name = 'World'

		# This throws an exception
		Test-Error {$document | Add-MdbcData -ErrorAction Stop} '*131107103027*'

		# This writes an error to the specified variable
		$document | Add-MdbcData -ErrorAction 0 -ErrorVariable e
		assert ($e -like '*131107103027*')

		# error on Unacknowledged
		if ('test.test' -eq $Collection) {
			# native collection works and gets no result
			$result = $document | Add-MdbcData -Result -WriteConcern ([MongoDB.Driver.WriteConcern]::Unacknowledged)
			equals $null $result
		}
		else {
			# file collection fails
			Test-Error { $document | Add-MdbcData -Result -WriteConcern ([MongoDB.Driver.WriteConcern]::Unacknowledged) } '*131107103027*'
		}

		# Test: Name is still 'Hello', 'World' is not added or saved
		$data = @(Get-MdbcData)
		equals $data.Count 1
		equals $data[0].Name 'Hello'

		# Add again, this time with the Update switch
		$document.Name = 'World'
		$document | Add-MdbcData -Update

		# Test: Name is 'World', the document is updated
		$data = @(Get-MdbcData)
		equals $data.Count 1
		equals $data[0].Name 'World'
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task WriteConcernResult {
	Invoke-Test {
		@{_id=1; x=1}, @{_id=2; x=2} | Add-MdbcData

		# 0 added due to error
		$r = @{_id=2; x=2} | Add-MdbcData -Result -ErrorAction 0 -ErrorVariable e
		equals "$(Get-MdbcData -Distinct _id)" '1 2'
		equals $r # Driver 1.10
		assert ($e -like '*duplicate*')

		# 1 added, 1 result
		$r = @{_id=3; x=3} | Add-MdbcData -Result
		equals "$(Get-MdbcData -Distinct _id)" '1 2 3'
		equals $r.DocumentsAffected 0L
		assert (!$r.UpdatedExisting)
		equals $r.LastErrorMessage
		equals $r.HasLastErrorMessage $false

		# 2 added, 2 results
		$r = @{_id=4; x=4}, @{_id=5; x=5} | Add-MdbcData -Result
		equals "$(Get-MdbcData -Distinct _id)" '1 2 3 4 5'
		equals $r.Count 2
		foreach($r in $r) {
			equals $r.DocumentsAffected 0L
			assert (!$r.UpdatedExisting)
			equals $r.LastErrorMessage
			equals $r.HasLastErrorMessage $false
		}

		# 1 added with -Update
		$r = @{_id=6; x=6} | Add-MdbcData -Result -Update
		equals "$(Get-MdbcData -Distinct _id)" '1 2 3 4 5 6'
		equals $r.DocumentsAffected 1L
		assert (!$r.UpdatedExisting)
		equals $r.LastErrorMessage
		equals $r.HasLastErrorMessage $false

		# 1 updated with -Update
		$r = @{_id=1; x=1} | Add-MdbcData -Result -Update
		equals "$(Get-MdbcData -Distinct _id)" '1 2 3 4 5 6'
		equals $r.DocumentsAffected 1L
		assert ($r.UpdatedExisting)
		equals $r.LastErrorMessage
		equals $r.HasLastErrorMessage $false
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}
