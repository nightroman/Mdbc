
. .\Zoo.ps1
Import-Module Mdbc

# v4.4.1 no more mongodump and mongorestore
task Basics {
	# test relative paths
	Set-Location C:\TEMP

	$1 = New-MdbcData
	$1._id = 'Name1'
	$1.pr2 = 12345
	$1.pr3 = @{
		p4 = 'Name2'
		p5 = 67890
	}
	$1.имя = "имя1"

	$2 = @{
		_id = 'Name2'
		pr2 = 67890
		имя = "имя2"
	}

	$3 = @{
		_id = 'Name3'
		pr2 = 3.14
		имя = "имя3"
	}

	function Test-Dictionary3 {
		'[0]'
		Test-Table $data1[0] $data2[0]
		'[1]'
		Test-Table $data1[1] $data2[1]
		'[2]'
		Test-Table $data1[2] $data2[2]
	}

	# dump by mdbc
	$1, $2 | Export-MdbcData z.bson
	Export-MdbcData z.bson $3 -Append #! positional InputObject
	Import-MdbcData z.bson -As PS | Format-Table -AutoSize | Out-String

	# import both data for comparison
	$data1 = $1, $2, $3
	$data2 = Import-MdbcData z.bson
	Test-Dictionary3 $data1 $data2

	remove z.bson
}

task Retry {
	Import-Module SplitPipeline
	$dataCount = 2000
	$pipeCount = 3

	Invoke-Test {
		remove $file

		1..$dataCount | Split-Pipeline -Verbose -Count $pipeCount -Variable file -Module Mdbc {process{
			@{_id=$_; data=[runspace]::DefaultRunspace.InstanceId} |
			Export-MdbcData -Verbose -Append -Retry (New-TimeSpan -Seconds 10) $file
		}}

		# all data are there
		$r = Import-MdbcData $file -As PS
		equals $r.Count $dataCount

		# all writers are there
		$r = $r | Group-Object data
		assert($r.Count -eq $pipeCount)

		Remove-Item -LiteralPath $file
	}{
		$file = "$env:TEMP\z.bson"
	}{
		$file = "$env:TEMP\z.json"
	}
}
