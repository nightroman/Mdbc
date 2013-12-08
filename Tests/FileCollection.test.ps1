
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

$bson = "$env:TEMP\test.bson"
$json = "$env:TEMP\test.json"

task NoLeakedPublicMembers {
	Open-MdbcFile
	$r = $Collection | Get-Member | %{$_.Name} | Out-String
	assert ($r -eq @'
Count
Distinct
Equals
FindAndModifyAs
FindAndRemoveAs
FindAs
GetHashCode
GetType
Insert
Remove
Save
ToString
Update
Collection

'@)
}

task Basics {
	Invoke-Test {
		# fake old file
		Set-Content $file 1
		assert (Test-Path $file)

		# open as new collection
		Open-MdbcFile $file -NewCollection
		assert (Test-Path $file) # file still exists
		assert ((Get-MdbcData -Count) -eq 0) # empty

		# add data
		@{x=1; y=1}, @{x=2; y=2} | Add-MdbcData
		assert (2 -eq (Get-MdbcData -Count))

		# save
		Save-MdbcFile
		assert (Test-Path $file)
		assert (2 -eq (Get-MdbcData -Count))

		# test
		$r = @(Import-MdbcData $file)
		assert ($r.Count -eq 2)
		assert ($r[0].x -eq 1)
		assert ($r[1].x -eq 2)

		# remove
		Remove-MdbcData @{x=1}
		assert (1 -eq (Get-MdbcData -Count))

		# save, test
		Save-MdbcFile
		assert (1 -eq (Get-MdbcData -Count))
		$r = @(Import-MdbcData $file)
		assert ($r.Count -eq 1)
		assert ($r[0].x -eq 2)
	}{
		$file = $bson
	}{
		$file = $json
	}
}

# Test invalid names with Add-MdbcData and Add-MdbcData -Update for normal and simple files
task ValidateElementNamesAndSimpleData {
	$errorLike = "Element name '*' is not valid because it * a '?'."
	Invoke-Test {
		# insert
		Test-Error { @{'$it'=1} | Add-MdbcData } $errorLike
		Test-Error { @{'it.name'=1} | Add-MdbcData } $errorLike

		# upsert
		if ($Collection.GetType().Name -eq 'NormalFileCollection') {
			Test-Error { @{'$it'=1} | Add-MdbcData -Update } $errorLike
			Test-Error { @{'it.name'=1} | Add-MdbcData -Update } $errorLike
		}
		else {
			Test-Error { @{} | Add-MdbcData -Update } 'Update-or-insert is not supported by simple collections.'
		}
	}{
		Open-MdbcFile
	}{
		Open-MdbcFile -Simple
	}
}

# What happens when Open-MdbcFile is used with a bson file with invalid names
task OpenWithInvalidElementNames {
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
	Test-Error { Open-MdbcFile $bson } 'The document (index 1) has no _id.'

	@{_id=42}, @{_id=42} | Export-MdbcData $bson
	Test-Error { Open-MdbcFile $bson } 'The document (index 1) has duplicate _id "42".'
}

#_131119_113717
task _idQuery {
	Open-MdbcFile
	@{_id=1}, @{_id='apple'}, @{_id='banana'}, @{_id='orange'}, @{_id=@{x=2}} | Add-MdbcData

	$r = Get-MdbcData miss
	assert (!$r)

	$r = Get-MdbcData 1.0 #! double
	assert ("$r" -ceq '{ "_id" : 1 }')

	$r = Get-MdbcData @{_id=@{x=2.0}} #! double
	assert ("$r" -ceq '{ "_id" : { "x" : 2 } }')

	$r = Get-MdbcData ([regex]'e')
	assert ("$r" -ceq '{ "_id" : "apple" } { "_id" : "orange" }')
}
