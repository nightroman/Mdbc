
. .\Zoo.ps1
Import-Module Mdbc

task BadId {
	$d = @{_id = 1,2}
	Invoke-Test {
		Test-Error { $d | Add-MdbcData } '*_id cannot be an array*'
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
		assert ("$r" -ceq '{ "_id" : 1, "x" : 1 }')
		assert ($e -like $131111_121454) $e
		if ($PSVersionTable.PSVersion.Major -le 2) {
			assert ($null -eq $e.TargetObject)
		}
		else {
			assert ($e.TargetObject.x -eq 2)
		}
	}{
		Connect-Mdbc -NewCollection
		$131111_121454 = '*E11000 duplicate key error index: test.test.$_id_  dup key: { : 1 }*'
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
			assert ($null -eq $result)
		}
		else {
			# file collection fails
			Test-Error { $document | Add-MdbcData -Result -WriteConcern ([MongoDB.Driver.WriteConcern]::Unacknowledged) } '*131107103027*'
		}

		# Test: Name is still 'Hello', 'World' is not added or saved
		$data = @(Get-MdbcData)
		assert ($data.Count -eq 1)
		assert ($data[0].Name -eq 'Hello')

		# Add again, this time with the Update switch
		$document.Name = 'World'
		$document | Add-MdbcData -Update

		# Test: Name is 'World', the document is updated
		$data = @(Get-MdbcData)
		assert ($data.Count -eq 1)
		assert ($data[0].Name -eq 'World')
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
		assert ("$(Get-MdbcData -Distinct _id)" -eq '1 2')
		assert ($r.DocumentsAffected -eq 0)
		assert (!$r.UpdatedExisting)
		assert ($null -eq $r.ErrorMessage)
		assert ($r.Ok)
		assert ($r.LastErrorMessage -like '*duplicate*')
		assert ($e -like '*duplicate*')

		# 1 added, 1 result
		$r = @{_id=3; x=3} | Add-MdbcData -Result
		assert ("$(Get-MdbcData -Distinct _id)" -eq '1 2 3')
		assert ($r.DocumentsAffected -eq 0)
		assert (!$r.UpdatedExisting)
		assert ($null -eq $r.LastErrorMessage)
		assert ($null -eq $r.ErrorMessage)
		assert ($r.Ok)

		# 2 added, 2 results
		$r = @{_id=4; x=4}, @{_id=5; x=5} | Add-MdbcData -Result
		assert ("$(Get-MdbcData -Distinct _id)" -eq '1 2 3 4 5')
		assert ($r.Count -eq 2)
		foreach($r in $r) {
			assert ($r.DocumentsAffected -eq 0)
			assert (!$r.UpdatedExisting)
			assert ($null -eq $r.LastErrorMessage)
			assert ($null -eq $r.ErrorMessage)
			assert ($r.Ok)
		}

		# 1 added with -Update
		$r = @{_id=6; x=6} | Add-MdbcData -Result -Update
		assert ("$(Get-MdbcData -Distinct _id)" -eq '1 2 3 4 5 6')
		assert ($r.DocumentsAffected -eq 1)
		assert (!$r.UpdatedExisting)
		assert ($null -eq $r.LastErrorMessage)
		assert ($null -eq $r.ErrorMessage)
		assert ($r.Ok)

		# 1 updated with -Update
		$r = @{_id=1; x=1} | Add-MdbcData -Result -Update
		assert ("$(Get-MdbcData -Distinct _id)" -eq '1 2 3 4 5 6')
		assert ($r.DocumentsAffected -eq 1)
		assert ($r.UpdatedExisting)
		assert ($null -eq $r.LastErrorMessage)
		assert ($null -eq $r.ErrorMessage)
		assert ($r.Ok)
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}
