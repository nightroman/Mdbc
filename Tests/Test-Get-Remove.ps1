
<#
.Synopsis
	Tests Get-MdbcData -Remove
#>

Import-Module Mdbc
$mtest = Connect-Mdbc . test test -NewCollection

# add documents
1..9 | %{@{Value1 = $_; Value2 = $_ % 2}} | Add-MdbcData $mtest

# get and remove the first even > 2, it is 4
$data = Get-MdbcData $mtest (New-MdbcQuery Value1 -GT 2) -SortBy Value2, Value1 -Remove
if ($data.Value1 -ne 4) {throw}

# do again, it is 6
$data = Get-MdbcData $mtest (New-MdbcQuery Value1 -GT 2) -SortBy Value2, Value1 -Remove
if ($data.Value1 -ne 6) {throw}

# try missing
$data = Get-MdbcData $mtest (New-MdbcQuery Value1 -LT 0) -SortBy Value2, Value1 -Remove
if ($data -ne $null) {throw}

# count: 9 - 2
if (7 -ne (Get-MdbcData $mtest -Count)) {throw}

# null SortBy
$data = Get-MdbcData $mtest (New-MdbcQuery Value1 -GT 2) -Remove
if ($data.Value1 -ne 3) {throw}
if (6 -ne (Get-MdbcData $mtest -Count)) {throw}

# null Query
$data = Get-MdbcData $mtest -SortBy Value2, Value1 -Remove
if ($data.Value1 -ne 2) {throw}
if (5 -ne (Get-MdbcData $mtest -Count)) {throw}
