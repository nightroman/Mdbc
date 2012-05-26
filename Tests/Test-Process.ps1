
<#
.Synopsis
	Tests the Mdbc module with some process data

.Notes
	TotalProcessorTime
		It can be null.
		Save as double, TimeSpan is not BSON type.
#>

Set-StrictMode -Version 2

Import-Module Mdbc
Connect-Mdbc mongodb://localhost test process -NewCollection

# Input: [System.Diagnostics.Process]
# Output: document with process and its module data
filter New-Document
{
	# create a document explicitly by New-MdbcData
	$process = New-MdbcData -Id $_.Id
	$process.Name = $_.Name
	$process.HandleCount = $_.HandleCount
	$process.WorkingSet = $_.WorkingSet
	$process.PrivateMemorySize = $_.PrivateMemorySize
	$process.StartTime = $_.StartTime
	$span = $_.TotalProcessorTime
	if ($span) {
		$process.TotalProcessorTime = $_.TotalProcessorTime.TotalMinutes
	}
	# array of nested documents for modules
	# documents are created implicitly from dictionaries
	$process.Modules = @(
		$_.Modules | %{
			try {
				@{
					FileName = $_.FileName
					ModuleMemorySize = $_.ModuleMemorySize
				}
			}
			catch {}
		}
	)
	# output the document
	$process
}

### Insert
Get-Process | New-Document | Add-MdbcData -ea Continue

### Upsert
Get-Process | New-Document | Add-MdbcData -Update -ea Continue

### Count
$Collection | Format-List | Out-String
$n1 = $Collection.FindAll().Count()
$n2 = Get-MdbcData -Count
if ($n1 -ne $n2) { throw }
"Count : $n1"

### Distinct
$set1 = $Collection.Distinct('Name')
$set2 = Get-MdbcData -Distinct Name
if ($set1.Count -ne $set2.Count) { throw }
if ($set1[0].GetType().Name -ne 'BsonString') { throw }
if ($set2[0].GetType().Name -ne 'String') { throw }
"Distinct : $($set1.Count)"

### Get by name
$1 = Get-MdbcData (New-MdbcQuery Name svchost) -Count
$2 = $Collection.Find([MongoDB.Driver.QueryDocument]@{ Name = 'svchost' }).Count()
$3 = $Collection.Find([MongoDB.Driver.Builders.Query]::EQ('Name', 'svchost')).Count()
if ($1 -ne $2) { throw }
if ($1 -ne $3) { throw }
"Find svchost : $1"

### Get by pattern/where
$1 = Get-MdbcData (New-MdbcQuery Name -Match '^svc|^mon') -Count
$2 = $Collection.Find([MongoDB.Driver.Builders.Query]::Matches('Name', '^svc|^mon')).Count()
$3 = $Collection.Find([MongoDB.Driver.QueryDocument]@{ '$where' = 'this.Name == "svchost" || this.Name == "mongod"' }).Count()
if ($1 -ne $2) { throw }
if ($1 -ne $3) { throw }
"Find match/where : $1"

Get-MdbcData (New-MdbcQuery Name mongod) | Update-MdbcData (New-MdbcUpdate HandleCount -Increment 1)
$document = Get-MdbcData (New-MdbcQuery Name mongod) -AsCustomObject

$document | Format-List | Out-String
