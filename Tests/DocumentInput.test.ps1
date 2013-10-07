
<#
.Synopsis
	Common tests for New-MdbcData, Add-MdbcData, Export-MdbcData
#>

. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version 2
Connect-Mdbc . test test -NewCollection

# BsonValue errors
task DocumentInput.BsonValueError {
	# good data to be done regardless of errors
	$good = @{_id = 1; Name = 'name1'}, @{_id = 2; Name = 'name2'}

	# bad data inserted before good
	$bad = @($Host) + $good

	Invoke-Test {
		$r = . $MakeData
		assert ($e -like '.NET type * cannot be mapped to a BsonValue.')
		assert ($PSVersionTable.PSVersion.Major -le 2 -or $e.TargetObject -eq $Host)
		Test-Array -Force $r $good
	}{
		$MakeData = {
			$bad | New-MdbcData -ErrorAction 0 -ErrorVariable e
		}
	}{
		$MakeData = {
			$null = $Collection.RemoveAll()
			$bad | Add-MdbcData -ErrorAction 0 -ErrorVariable e
			Get-MdbcData
		}
	}{
		$MakeData = {
			$bad | Export-MdbcData -ErrorAction 0 -ErrorVariable e -Path z.bson
			Import-MdbcData z.bson
		}
	}

	Remove-Item z.bson
}

# Parameters Id and NewId
task DocumentInput.-Id {
	# input object
	$ps = New-Object PSObject -Property @{ id = 'id1'; name = 'name1' }

	Invoke-Test {
		# Create with value
		$d = . $Data1
		assert ($d.Count -eq 3)
		assert ($d._id -eq 'value')

		# Create with script
		$d = . $Data2
		assert ($d.Count -eq 3)
		assert ($d._id -eq 'id1')

		# Generate _id
		$d = . $Data3
		assert ($d.Count -eq 3)
		assert ($d._id -is [MongoDB.Bson.BsonObjectId])
	}{
		$Data1 = {New-MdbcData $ps -Id 'value'}
		$Data2 = {New-MdbcData $ps -Id {$_.Id}}
		$Data3 = {New-MdbcData $ps -NewId -Id 'ignored'}
	}{
		$Data1 = {
			$null = $Collection.RemoveAll()
			Add-MdbcData $ps -Id 'value'
			Get-MdbcData
		}
		$Data2 = {
			$null = $Collection.RemoveAll()
			Add-MdbcData $ps -Id {$_.Id}
			Get-MdbcData
		}
		$Data3 = {
			$null = $Collection.RemoveAll()
			Add-MdbcData $ps -NewId -Id 'ignored'
			Get-MdbcData
		}
	}{
		$Data1 = {
			$ps | Export-MdbcData z.bson -Id 'value'
			Import-MdbcData z.bson
		}
		$Data2 = {
			$ps | Export-MdbcData z.bson -Id {$_.Id}
			Import-MdbcData z.bson
		}
		$Data3 = {
			$ps | Export-MdbcData z.bson -NewId -Id 'ignored'
			Import-MdbcData z.bson
		}
	}

	Remove-Item z.bson
}
