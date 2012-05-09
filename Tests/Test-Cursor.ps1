
<#
.Synopsis
	Tests MongoCursor Get-MdbcData -Cursor.
#>

Import-Module Mdbc
$mtest = Connect-Mdbc . test test -NewCollection

# add 11 documents
20..1 | %{@{Value = $_}} | Add-MdbcData $mtest

# get 5 skipping 5
$cursor = Get-MdbcData $mtest -Cursor -First 5 -Skip 5
if ($cursor.Count() -ne 20) {throw}
if ($cursor.Size() -ne 5) {throw}

# get raw data as an array; NB: raw BsonDocument and BsonValue are not so friendly
$set = @($cursor)
if ($set[0]['Value'].AsInt32 -ne 15) {throw}
if ($set[-1]['Value'].AsInt32 -ne 11) {throw}

# get data again, converted to Mdbc.Dictionary; NB: these data are more friendly
$set = $cursor | New-MdbcData
if ($set[0].Value -ne 15) {throw}
if ($set[-1].Value -ne 11) {throw}

# get and test ordered data
# Set* methods returns the cursor, both handy and gotcha
$cursor = Get-MdbcData $mtest -Cursor -First 5 -Skip 5
$set = $cursor.SetSortOrder('Value') | New-MdbcData
if ($set[0].Value -ne 6) {throw}
if ($set[-1].Value -ne 10) {throw}
