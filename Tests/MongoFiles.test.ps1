<#
.Synopsis
	Tests Update-MongoFiles.ps1 and Get-MongoFile.ps1.
#>

Import-Module Mdbc
Set-StrictMode -Version Latest

task Update-MongoFiles {
	# init
	Connect-Mdbc -NewCollection
	$log = Get-MdbcCollection test_log -NewCollection
	remove z

	# add alien data
	@{Name = 'alien'} | Add-MdbcData
	equals (Get-MdbcData -Count @{Name = 'alien'}) 1L

	# update files, no log
	$r = Update-MongoFiles .. -CollectionName test
	assert ($r.Path -like '*\Mdbc')
	assert ($r.Created -gt 100)
	equals $r.Changed 0
	equals $r.Removed 1
	equals (Get-MdbcData -Count @{Name = 'alien'}) 0L
	equals (Get-MdbcData -Count) ([long]$r.Created)

	# new directory and file
	$null = mkdir z
	1 > z\z.txt

	# update
	$r = Update-MongoFiles . -CollectionName test -Log
	equals $r.Created 2
	equals $r.Changed 0
	equals $r.Removed 0

	equals (Get-MdbcData -Count -Collection $log) 2L
	$1, $2 = Get-MdbcData -Collection $log

	assert ($1._id -like '*\Tests\z')
	equals $1.Log.Count 1
	equals $1.Log[0].Op 0

	assert ($2._id -like '*\Tests\z\z.txt')
	equals $2.Log.Count 1
	equals $2.Log[0].Op 0

	# change file
	1 >> z\z.txt

	# update
	$r = Update-MongoFiles . -CollectionName test -Log
	equals $r.Created 0
	equals $r.Changed 1
	equals $r.Removed 0

	equals (Get-MdbcData -Count -Collection $log) 2L
	$1, $2 = Get-MdbcData -Collection $log

	assert ($1._id -like '*\Tests\z')
	equals $1.Log.Count 1
	equals $1.Log[0].Op 0

	assert ($2._id -like '*\Tests\z\z.txt')
	equals $2.Log.Count 2
	equals $2.Log[1].Op 1

	# remove directory and file
	remove z

	# update
	$r = Update-MongoFiles . -CollectionName test -Log
	equals $r.Created 0
	equals $r.Changed 0
	equals $r.Removed 2

	equals (Get-MdbcData -Count -Collection $log) 2L
	$1, $2 = Get-MdbcData -Collection $log -Sort @{_id = 1}

	assert ($1._id -like '*\Tests\z')
	equals $1.Log.Count 2
	equals $1.Log[1].Op 2

	assert ($2._id -like '*\Tests\z\z.txt')
	equals $2.Log.Count 3
	equals $2.Log[2].Op 2
}

task Get-MongoFile Update-MongoFiles, {
	$r = @(Get-MongoFile -CollectionName test 'collectionext|documentinput' | Sort-Object)
	$r
	equals 3 $r.Count
	assert ($r[0] -clike '*\Mdbc\Src\CollectionExt.cs')
	assert ($r[1] -clike '*\Mdbc\Src\DocumentInput.cs')
	assert ($r[2] -clike '*\Mdbc\Tests\DocumentInput.test.ps1')

	$r = @(Get-MongoFile -CollectionName test 'CollectionExt.cs' -Name)
	equals 1 $r.Count
	assert ($r[0] -clike '*\Mdbc\Src\CollectionExt.cs')
}

task Test-MongoFiles Update-MongoFiles, {
	# minimum time
	$time1 = (Get-ChildItem | Sort-Object LastWriteTime | Select-Object -First 1).LastWriteTime

	Connect-Mdbc

	# Write-Verbose is used because the function returns a number
	function Test-Query($query) {
		$watch = [System.Diagnostics.Stopwatch]::StartNew()
		$count = Get-MdbcData -Count $query
		Write-Verbose -Verbose "$count for $($watch.Elapsed)"
		$count
	}

	$total = Get-MdbcData -Count
	"$total documents"

	"eq ne"
	$EQReadme = Test-Query @{Name = 'Readme.txt'}
	$NEReadme = Test-Query @{Name = @{'$ne' = 'Readme.txt'}}
	assert ($total -eq $EQReadme + $NEReadme) "$total -ne $EQReadme + $NEReadme"

	"exists"
	$MissingLength = Test-Query @{Length = @{'$exists' = $false}}
	$ExistingLength = Test-Query @{Length = @{'$exists' = $true}}
	equals ($MissingLength + $ExistingLength) $total
}
