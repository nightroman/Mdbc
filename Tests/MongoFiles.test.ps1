
<#
.Synopsis
	Tests data in test.files created by Scripts\Update-MongoFiles.ps1
#>

Import-Module Mdbc
Set-StrictMode -Version 2

task . {
	$time1 = [DateTime]'2010-01-01'

	Connect-Mdbc . test files

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
	assert ($n2 -eq $total - $n1)

	"EQ GT LT"
	$n1 = Test-Query (New-MdbcQuery LastWriteTime $time1)
	$n2 = Test-Query (New-MdbcQuery LastWriteTime -GT $time1)
	$n3 = Test-Query (New-MdbcQuery LastWriteTime -LT $time1)
	assert ($total -eq $n1 + $n2 + $n3)

	"GTE LTE"
	$n2 = Test-Query (New-MdbcQuery LastWriteTime -GTE $time1)
	$n3 = Test-Query (New-MdbcQuery LastWriteTime -LTE $time1)
	assert ($total -eq -$n1 + $n2 + $n3)

	"And"
	$n1 = Test-Query (New-MdbcQuery -And (New-MdbcQuery Name Readme.txt), (New-MdbcQuery LastWriteTime -GT $time1))
	$n2 = Test-Query (New-MdbcQuery -And (New-MdbcQuery Name Readme.txt), (New-MdbcQuery LastWriteTime -LT $time1))
	assert ($EQReadme -eq $n1 + $n2)

	"Or In Match"
	$n1 = Test-Query (New-MdbcQuery -Or (New-MdbcQuery Name Readme.txt), (New-MdbcQuery Name About.txt), (New-MdbcQuery Name LICENSE))
	$n2 = Test-Query (New-MdbcQuery Name -In Readme.txt, About.txt, LICENSE)
	assert ($n1 -eq $n2)
	$n2 = Test-Query (New-MdbcQuery Name -Matches '^(?:Readme\.txt|About\.txt|LICENSE)$')
	assert ($n1 -eq $n2)

	"Matches, ignore case"
	$n1 = Test-Query (New-MdbcQuery Name -Matches '^(?i:Readme\.txt|About\.txt|LICENSE)$')
	$n2 = Test-Query (New-MdbcQuery Name -Matches (New-Object regex '^(?:Readme\.txt|About\.txt|LICENSE)$', IgnoreCase))
	assert ($n1 -eq $n2)

	"Exists Mod Not"
	$MissingLength = Test-Query (New-MdbcQuery Length -NotExists)
	$n1 = Test-Query (New-MdbcQuery Length -Mod 2, 0)
	$n2 = Test-Query (New-MdbcQuery -Not (New-MdbcQuery Length -Mod 2, 1))
	assert ($MissingLength + $n1 -eq $n2)
	$n1 = Test-Query (New-MdbcQuery Length -Mod 2, 1)
	$n2 = Test-Query (New-MdbcQuery -Not (New-MdbcQuery Length -Mod 2, 0))
	assert ($MissingLength + $n1 -eq $n2)

	"Type"
	$n1 = Test-Query (New-MdbcQuery Length -Type Int64)
	assert ($n1 -eq $total - $MissingLength)
}
