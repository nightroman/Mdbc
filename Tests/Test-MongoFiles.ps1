
<#
.Synopsis
	Tests data in test.files created by Scripts\Update-MongoFiles.ps1
#>

Set-StrictMode -Version 2
$time1 = [DateTime]'2010-01-01'

Import-Module Mdbc
$collection = Connect-Mdbc . test files

function Test-Query($query) {
	Write-Host $query.ToString()
	$watch = [System.Diagnostics.Stopwatch]::StartNew()
	$count = Get-MdbcData -Count $collection $query
	Write-Host "$count for $($watch.Elapsed)"
	$count
}

$total = $collection.Count()
Write-Host "$total documents"

Write-Host "EQ NE"
$EQReadme = Test-Query (query Name Readme.txt)
$NEReadme = Test-Query (query Name -NE Readme.txt)
if ($total -ne $EQReadme + $NEReadme) { throw }

Write-Host "IEQ INE"
$n1 = Test-Query (query Name -IEQ README.TXT)
if ($n1 -lt $EQReadme) { throw }
$n2 = Test-Query (query Name -INE README.TXT)
if ($n2 -ne $total - $n1) { throw }

Write-Host "EQ GT LT"
$n1 = Test-Query (query LastWriteTime $time1)
$n2 = Test-Query (query LastWriteTime -GT $time1)
$n3 = Test-Query (query LastWriteTime -LT $time1)
if ($total -ne $n1 + $n2 + $n3) { throw }

Write-Host "GE LE"
$n2 = Test-Query (query LastWriteTime -GE $time1)
$n3 = Test-Query (query LastWriteTime -LE $time1)
if ($total -ne -$n1 + $n2 + $n3) { throw }

Write-Host "And"
$n1 = Test-Query (query (query Name Readme.txt), (query LastWriteTime -GT $time1))
$n2 = Test-Query (query (query Name Readme.txt), (query LastWriteTime -LT $time1))
if ($EQReadme -ne $n1 + $n2) { throw }

Write-Host "Or In Matches"
$n1 = Test-Query (query -Or (query Name Readme.txt), (query Name About.txt), (query Name LICENSE))
$n2 = Test-Query (query Name -In Readme.txt, About.txt, LICENSE)
if ($n1 -ne $n2) { throw }
$n2 = Test-Query (query Name -Match '^(?:Readme\.txt|About\.txt|LICENSE)$')
if ($n1 -ne $n2) { throw }

Write-Host "Matches, ignore case"
$n1 = Test-Query (query Name -Match '^(?i:Readme\.txt|About\.txt|LICENSE)$')
$n2 = Test-Query (query Name -Match (New-Object regex '^(?:Readme\.txt|About\.txt|LICENSE)$', IgnoreCase))
if ($n1 -ne $n2) { throw }

Write-Host "Exists Mod Not"
$MissingLength = Test-Query (query Length -Exists $false)
$n1 = Test-Query (query Length -Mod 2, 0)
$n2 = Test-Query (query Length -Not -Mod 2, 1)
if ($MissingLength + $n1 -ne $n2) { throw }
$n1 = Test-Query (query Length -Mod 2, 1)
$n2 = Test-Query (query Length -Not -Mod 2, 0)
if ($MissingLength + $n1 -ne $n2) { throw }

Write-Host "Type"
$n1 = Test-Query (query Length -Type Int64)
if ($n1 -ne $total - $MissingLength) { throw }

if (0) {
	Write-Host "Where (VERY SLOW!)"
	$n1 = Test-Query (query -Where 'this.Length == null')
	if ($n1 -ne $MissingLength) { throw }
}
