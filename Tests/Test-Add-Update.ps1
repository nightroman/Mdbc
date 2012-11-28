
<#
.Synopsis
	Add with the same _id and Add -Update.
#>

Import-Module Mdbc
Connect-Mdbc . test test -NewCollection

# New document
$document = New-MdbcData
$document._id = 12345
$document.Name = 'Hello'

# Add the document
$document | Add-MdbcData

# To add with the same _id and another Name
$document.Name = 'World'

# This throws an exception
$message = ''
try {$document | Add-MdbcData -ErrorAction Stop}
catch {$message = "$_"}
if ($message -notlike 'WriteConcern detected an error*') {throw}

# This writes an error to the specified variable
$document | Add-MdbcData -ErrorAction 0 -ErrorVariable ev
if ("$ev" -notlike 'WriteConcern detected an error*') {throw}

# This fails silently and returns nothing
$result = $document | Add-MdbcData -Result -WriteConcern ([MongoDB.Driver.WriteConcern]::Unacknowledged)
if ($null -ne $result) {throw}

# Test: Name is still 'Hello', 'World' is not added or saved
$data = @(Get-MdbcData)
if ($data.Count -ne 1) { throw }
if ($data[0].Name -ne 'Hello') { throw }

# Add again, this time with the Update switch
$document.Name = 'World'
$document | Add-MdbcData -Update

# Test: Name is 'World', the document is updated
$data = @(Get-MdbcData)
if ($data.Count -ne 1) { throw }
if ($data[0].Name -ne 'World') { throw }

# End
'OK'
