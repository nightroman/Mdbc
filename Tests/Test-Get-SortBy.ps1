
<#
.Synopsis
	Tests Get-MdbcData -SortBy
#>

Import-Module Mdbc
Connect-Mdbc . test test -NewCollection

# add documents (9,1), (8,0), (7,1), .. (0,0)
9..0 | %{@{Value1 = $_; Value2 = $_ % 2}} | Add-MdbcData

# sort by Value1
$data = Get-MdbcData -SortBy Value1 -First 1
if ($data.Value1 -ne 0) {throw}

# sort by two values, ascending by default
$data = Get-MdbcData -SortBy Value2, Value1
if ($data[0].Value1 -ne 0) {throw}
if ($data[1].Value1 -ne 2) {throw}
if ($data[-2].Value1 -ne 7) {throw}
if ($data[-1].Value1 -ne 9) {throw}

# sort by two values, descending explicitly
$data = Get-MdbcData -SortBy @{Value2=0}, @{Value1=0}
if ($data[0].Value1 -ne 9) {throw}
if ($data[1].Value1 -ne 7) {throw}
if ($data[-2].Value1 -ne 2) {throw}
if ($data[-1].Value1 -ne 0) {throw}
