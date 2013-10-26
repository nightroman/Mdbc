
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

$bson = "$env:TEMP\test.bson"

task Basics {
	# fake old file
	Set-Content $bson 1
	assert (Test-Path $bson)

	# open as new collection
	Open-MdbcFile $bson -NewCollection
	assert (Test-Path $bson) # file still exists
	assert ((Get-MdbcData -Count) -eq 0) # empty

	# no leaked public members
	assert (4 -eq ($Collection | Get-Member).Count)

	# add data
	@{x=1; y=1}, @{x=2; y=2} | Add-MdbcData
	assert (2 -eq (Get-MdbcData -Count))

	# save
	Save-MdbcFile
	assert (Test-Path $bson)
	assert (2 -eq (Get-MdbcData -Count))

	# test
	$r = @(Import-MdbcData $bson)
	assert ($r.Count -eq 2)
	assert ($r[0].x -eq 1)
	assert ($r[1].x -eq 2)

	# remove
	Remove-MdbcData @{x=1}
	assert (1 -eq (Get-MdbcData -Count))

	# save, test
	Save-MdbcFile
	assert (1 -eq (Get-MdbcData -Count))
	$r = @(Import-MdbcData $bson)
	assert ($r.Count -eq 1)
	assert ($r[0].x -eq 2)
}

# Test invalid names with Add-MdbcData and Add-MdbcData -Update for normal and simple data
task ValidateElementNames {
	$errorLike = "Element name '*' is not valid because it * a '?'."
	Invoke-Test {
		Test-Error { @{'$it'=1} | Add-MdbcData } $errorLike
		Test-Error { @{'it.name'=1} | Add-MdbcData } $errorLike

		if ($Collection.GetType().Name -eq 'NormalDataFile') {
			Test-Error { @{'$it'=1} | Add-MdbcData -Update } $errorLike
			Test-Error { @{'it.name'=1} | Add-MdbcData -Update } $errorLike
		}
		else {
			Test-Error { @{} | Add-MdbcData -Update } 'Add -Update is not supported for simple data files.'
		}
	}{
		Open-MdbcFile
	}{
		Open-MdbcFile -Simple
	}
}

# What happens when Open-MdbcFile is used with a bson file with invalid names
task InvalidElementNames {
	# bson file with bad names for a collection
	@{'$it'=1}, @{'it.name'=1} | Export-MdbcData $bson

	# we still can read it as a collection
	Open-MdbcFile $bson -Simple

	# and get all data
	$r = Get-MdbcData
	assert ($r.Count -eq 2 -and $r[0]['$it'] -eq 1 -and $r[1]['it.name'] -eq 1)

	# but some queries either fail
	Test-Error { Get-MdbcData (New-MdbcQuery '$it' 1) } 'Not implemented operator $it'

	# or do not work
	$r = Get-MdbcData (New-MdbcQuery 'it.name' 1)
	assert ($null -eq $r)
}

task NormalData {
	@{_id=42}, @{x=1} | Export-MdbcData $bson
	Test-Error { Open-MdbcFile $bson } 'The document at 1 has no _id.'

	@{_id=42}, @{_id=42} | Export-MdbcData $bson
	Test-Error { Open-MdbcFile $bson } 'The document at 1 has not unique _id "42".'
}

task Distinct {
	$data = @{x=1}, @{x=2}, @{x=2}, @{x=1.0}, @{x=1L}, @{x=$true}

	Connect-Mdbc -NewCollection
	$data | Add-MdbcData
	$r1 = Get-MdbcData -Distinct x
	"$r1"

	Open-MdbcFile
	$data | Add-MdbcData
	$r2 = Get-MdbcData -Distinct x
	"$r2"

	Test-List $r1 $r2
}
