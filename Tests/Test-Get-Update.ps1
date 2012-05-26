
<#
.Synopsis
	Tests Get-MdbcData -Update -Add -New

.Link
	https://github.com/mongodb/mongo/blob/master/jstests/find_and_modify4.js
#>

Import-Module Mdbc
Connect-Mdbc . test test -NewCollection

# this is the best way to build auto-increment
function getNextVal($counterName) {
    (Get-MdbcData (New-MdbcQuery _id $counterName) -Update (New-MdbcUpdate val -Increment 1) -Add -New).val
}

if (1 -ne (getNextVal a)) {throw}
if (2 -ne (getNextVal a)) {throw}
if (3 -ne (getNextVal a)) {throw}
if (1 -ne (getNextVal z)) {throw}
if (2 -ne (getNextVal z)) {throw}
if (4 -ne (getNextVal a)) {throw}
$null = $Collection.Drop()

function helper($upsert) {
    Get-MdbcData (New-MdbcQuery _id asdf) -Update (New-MdbcUpdate val -Increment 1) -Add:$upsert
}

# upsert:false so nothing there before and after
if ($null -ne (helper $false)) {throw}
if (0 -ne $Collection.Count()) {throw}

# upsert:true so nothing there before; something there after
if ($null -eq (helper $true)) {throw}
if (1 -ne $Collection.Count()) {throw}

$data = helper $true
if ($data._id -ne 'asdf' -or $data.val -ne 1) {throw}

# upsert only matters when obj doesn't exist
$data = helper $false
if ($data._id -ne 'asdf' -or $data.val -ne 2) {throw}

$data = helper $true
if ($data._id -ne 'asdf' -or $data.val -ne 3) {throw}

# _id created if not specified
$out = Get-MdbcData (New-MdbcQuery a 1) -Update (New-MdbcUpdate b -Set 2) -Add -New
if ($null -eq $out._id) {throw}
if (1 -ne $out.a) {throw}
if (2 -ne $out.b) {throw}
