
. .\Zoo.ps1
Import-Module Mdbc

task Export.Basics {
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
		Test-Dictionary $data1[0] $data2[0]
		'[1]'
		Test-Dictionary $data1[1] $data2[1]
		'[2]'
		Test-Dictionary $data1[2] $data2[2]
	}

	# dump by mongodump
	Connect-Mdbc -NewCollection
	$1, $2, $3 | Add-MdbcData
	Set-Alias mongodump ([IO.Path]::GetDirectoryName((Get-Process mongod).Path) + '\mongodump.exe')
	exec {mongodump -d test -c test}

	# dump by mdbc
	$1, $2 | Export-MdbcData test2.bson
	Export-MdbcData test2.bson -InputObject $3 -Append
	Import-MdbcData test2.bson -As PS | Format-Table -AutoSize | Out-String

	# the same file size
	$file1 = Get-Item dump\test\test.bson
	$file2 = Get-Item test2.bson
	assert ($file1.Length -eq $file2.Length)

	# import both data for comparison
	$data1 = Import-MdbcData dump\test\test.bson
	$data2 = Import-MdbcData test2.bson
	Test-Dictionary3 $data1 $data2

	# restore from our dump
	Connect-Mdbc -NewCollection
	assert ($collection.Count() -eq 0)
	Set-Alias mongorestore ([IO.Path]::GetDirectoryName((Get-Process mongod).Path) + '\mongorestore.exe')
	exec {mongorestore -d test -c test test2.bson}
	$data2 = Get-MdbcData
	Test-Dictionary3 $data1 $data2

	# end
	Remove-Item test2.bson, dump -Recurse -Force
}
