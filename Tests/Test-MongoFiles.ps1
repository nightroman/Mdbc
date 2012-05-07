
<#
.Synopsis
	Tests data in test.files created by Scripts\Update-MongoFiles.ps1
#>

Set-StrictMode -Version 2
$time1 = [DateTime]'2010-01-01'

Import-Module Mdbc
$collection = Connect-Mdbc . test files

function Test-Query($query) {
	Write-Verbose -Verbose $query.ToString()
	$watch = [System.Diagnostics.Stopwatch]::StartNew()
	$count = Get-MdbcData -Count $collection $query
	Write-Verbose -Verbose "$count for $($watch.Elapsed)"
	$count
}

$total = $collection.Count()
"$total documents"

"EQ NE"
$EQReadme = Test-Query (New-MdbcQuery Name Readme.txt)
$NEReadme = Test-Query (New-MdbcQuery Name -NE Readme.txt)
if ($total -ne $EQReadme + $NEReadme) { throw "$total -ne $EQReadme + $NEReadme" }

"IEQ INE"
$n1 = Test-Query (New-MdbcQuery Name -IEQ README.TXT)
if ($n1 -lt $EQReadme) { throw }
$n2 = Test-Query (New-MdbcQuery Name -INE README.TXT)
if ($n2 -ne $total - $n1) { throw }

"EQ GT LT"
$n1 = Test-Query (New-MdbcQuery LastWriteTime $time1)
$n2 = Test-Query (New-MdbcQuery LastWriteTime -GT $time1)
$n3 = Test-Query (New-MdbcQuery LastWriteTime -LT $time1)
if ($total -ne $n1 + $n2 + $n3) { throw }

"GE LE"
$n2 = Test-Query (New-MdbcQuery LastWriteTime -GE $time1)
$n3 = Test-Query (New-MdbcQuery LastWriteTime -LE $time1)
if ($total -ne -$n1 + $n2 + $n3) { throw }

"And"
$n1 = Test-Query (New-MdbcQuery -And (New-MdbcQuery Name Readme.txt), (New-MdbcQuery LastWriteTime -GT $time1))
$n2 = Test-Query (New-MdbcQuery -And (New-MdbcQuery Name Readme.txt), (New-MdbcQuery LastWriteTime -LT $time1))
if ($EQReadme -ne $n1 + $n2) { throw }

"Or In Match"
$n1 = Test-Query (New-MdbcQuery -Or (New-MdbcQuery Name Readme.txt), (New-MdbcQuery Name About.txt), (New-MdbcQuery Name LICENSE))
$n2 = Test-Query (New-MdbcQuery Name -In Readme.txt, About.txt, LICENSE)
if ($n1 -ne $n2) { throw }
$n2 = Test-Query (New-MdbcQuery Name -Match '^(?:Readme\.txt|About\.txt|LICENSE)$')
if ($n1 -ne $n2) { throw }

"Match, ignore case"
$n1 = Test-Query (New-MdbcQuery Name -Match '^(?i:Readme\.txt|About\.txt|LICENSE)$')
$n2 = Test-Query (New-MdbcQuery Name -Match (New-Object regex '^(?:Readme\.txt|About\.txt|LICENSE)$', IgnoreCase))
if ($n1 -ne $n2) { throw }

"Exists Mod Not"
$MissingLength = Test-Query (New-MdbcQuery Length -Exists $false)
$n1 = Test-Query (New-MdbcQuery Length -Mod 2, 0)
$n2 = Test-Query (New-MdbcQuery Length -Not -Mod 2, 1)
if ($MissingLength + $n1 -ne $n2) { throw }
$n1 = Test-Query (New-MdbcQuery Length -Mod 2, 1)
$n2 = Test-Query (New-MdbcQuery Length -Not -Mod 2, 0)
if ($MissingLength + $n1 -ne $n2) { throw }

"Type"
$n1 = Test-Query (New-MdbcQuery Length -Type Int64)
if ($n1 -ne $total - $MissingLength) { throw }

"Where (slow)"
$n1 = Test-Query (New-MdbcQuery -Where 'this.Length == null')
if ($n1 -ne $MissingLength) { throw }
