
<#
.Synopsis
	Tests Update-MongoFiles.ps1 and Get-MongoFile.ps1.
#>

Import-Module Mdbc
Set-StrictMode -Version Latest

task Update-MongoFiles {
	# init
	Connect-Mdbc -NewCollection
	$log = $Database.GetCollection('test_log')
	$null = $log.Drop()
	remove z

	# add alien data
	@{Name = 'alien'} | Add-MdbcData
	equals (Get-MdbcData -Count (New-MdbcQuery Name alien)) 1L

	# update files, no log
	$r = Update-MongoFiles .. -CollectionName test
	assert ($r.Path -like '*\Mdbc')
	assert ($r.Created -gt 100)
	equals $r.Changed 0
	equals $r.Removed 1
	equals (Get-MdbcData -Count (New-MdbcQuery Name alien)) 0L
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
	$1, $2 = Get-MdbcData -Collection $log -SortBy _id

	assert ($1._id -like '*\Tests\z')
	equals $1.Log.Count 2
	equals $1.Log[1].Op 2

	assert ($2._id -like '*\Tests\z\z.txt')
	equals $2.Log.Count 3
	equals $2.Log[2].Op 2
}

task Get-MongoFile Update-MongoFiles, {
	$r = @(Get-MongoFile -CollectionName test 'collectionhost|querycompiler' | Sort-Object)
	$r
	equals 3 $r.Count
	assert ($r[0] -clike '*\Mdbc\Src\CollectionHost.cs')
	assert ($r[1] -clike '*\Mdbc\Src\QueryCompiler.cs')
	assert ($r[2] -clike '*\Mdbc\Tests\QueryCompiler.test.ps1')

	$r = @(Get-MongoFile -CollectionName test 'CollectionHost.cs' -Name)
	equals 1 $r.Count
	assert ($r[0] -clike '*\Mdbc\Src\CollectionHost.cs')
}

task Test-MongoFiles Update-MongoFiles, {
	# minimum time
	$time1 = (Get-ChildItem | Sort-Object LastWriteTime | Select-Object -First 1).LastWriteTime

	Connect-Mdbc

	# Write-Verbose is used because the function returns a number
	function Test-Query($query) {
		Write-Verbose -Verbose $query.ToString()
		$watch = [System.Diagnostics.Stopwatch]::StartNew()
		$count = Get-MdbcData -Count $query
		Write-Verbose -Verbose "$count for $($watch.Elapsed)"
		$count
	}

	$total = $Collection.Count()
	"$total documents"

	"EQ NE"
	$EQReadme = Test-Query (New-MdbcQuery Name Readme.txt)
	$NEReadme = Test-Query (New-MdbcQuery Name -NE Readme.txt)
	assert ($total -eq $EQReadme + $NEReadme) "$total -ne $EQReadme + $NEReadme"

	"IEQ INE"
	$n1 = Test-Query (New-MdbcQuery Name -IEQ README.TXT)
	assert ($n1 -ge $EQReadme)
	$n2 = Test-Query (New-MdbcQuery Name -INE README.TXT)
	equals $n2 ($total - $n1)

	"EQ GT LT"
	$n1 = Test-Query (New-MdbcQuery LastWriteTime $time1)
	$n2 = Test-Query (New-MdbcQuery LastWriteTime -GT $time1)
	$n3 = Test-Query (New-MdbcQuery LastWriteTime -LT $time1)
	equals $total ($n1 + $n2 + $n3)

	"GTE LTE"
	$n2 = Test-Query (New-MdbcQuery LastWriteTime -GTE $time1)
	$n3 = Test-Query (New-MdbcQuery LastWriteTime -LTE $time1)
	equals $total (-$n1 + $n2 + $n3)

	"And"
	$n1 = Test-Query (New-MdbcQuery -And (New-MdbcQuery Name Readme.txt), (New-MdbcQuery LastWriteTime -GT $time1))
	$n2 = Test-Query (New-MdbcQuery -And (New-MdbcQuery Name Readme.txt), (New-MdbcQuery LastWriteTime -LT $time1))
	equals $EQReadme ($n1 + $n2)

	"Or In Match"
	$n1 = Test-Query (New-MdbcQuery -Or (New-MdbcQuery Name Readme.txt), (New-MdbcQuery Name About.txt), (New-MdbcQuery Name LICENSE))
	$n2 = Test-Query (New-MdbcQuery Name -In Readme.txt, About.txt, LICENSE)
	equals $n1 $n2
	$n2 = Test-Query (New-MdbcQuery Name -Matches '^(?:Readme\.txt|About\.txt|LICENSE)$')
	equals $n1 $n2

	"Matches, ignore case"
	$n1 = Test-Query (New-MdbcQuery Name -Matches '^(?i:Readme\.txt|About\.txt|LICENSE)$')
	$n2 = Test-Query (New-MdbcQuery Name -Matches (New-Object regex '^(?:Readme\.txt|About\.txt|LICENSE)$', IgnoreCase))
	equals $n1 $n2

	"Exists Mod Not"
	$MissingLength = Test-Query (New-MdbcQuery Length -NotExists)
	$n1 = Test-Query (New-MdbcQuery Length -Mod 2, 0)
	$n2 = Test-Query (New-MdbcQuery -Not (New-MdbcQuery Length -Mod 2, 1))
	equals ($MissingLength + $n1) $n2
	$n1 = Test-Query (New-MdbcQuery Length -Mod 2, 1)
	$n2 = Test-Query (New-MdbcQuery -Not (New-MdbcQuery Length -Mod 2, 0))
	equals ($MissingLength + $n1) $n2

	"Type"
	$n1 = Test-Query (New-MdbcQuery Length -Type Int64)
	equals $n1 ($total - $MissingLength)

	"Where (slow)"
	$n1 = Test-Query (New-MdbcQuery -Where 'this.Length == null')
	equals $n1 $MissingLength
}
