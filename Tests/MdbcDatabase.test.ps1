
. ./Zoo.ps1

Import-Module Mdbc

#! Values may be PSObject, use BaseObject.
task FixDefaultDatabaseAndCollection {
	Connect-Mdbc .
	Remove-MdbcDatabase z
	$Database = Get-MdbcDatabase z
	#! used to fail, cannot see $Database
	$Collection = Get-MdbcCollection z
	#! used to fail, cannot see $Collection
	equals 0L (Get-MdbcData -Count)
}

task AddGetRemoveDatabase {
	# ensure new database and collection by adding data
	Connect-Mdbc . z z
	@{} | Add-MdbcData

	# get database
	$r = Get-MdbcDatabase z
	equals $r.DatabaseNamespace.DatabaseName z

	# get all databases, z is there
	$r = Get-MdbcDatabase | .{process{ $_.DatabaseNamespace.DatabaseName }}
	assert ($r.Count -ge 3)
	assert ($r -ccontains 'z')
	assert ($r -ccontains 'admin')
	assert ($r -ccontains 'local')

	# remove z
	Remove-MdbcDatabase z

	# z is not there
	$r = Get-MdbcDatabase | .{process{ $_.DatabaseNamespace.DatabaseName }}
	assert ($r.Count -ge 2)
	assert ($r -cnotcontains 'z')

	# but we can get its missing instance anyway
	$r = Get-MdbcDatabase z
	equals $r.DatabaseNamespace.DatabaseName z

	# but it is not created yet
	$r = Get-MdbcDatabase | .{process{ $_.DatabaseNamespace.DatabaseName }}
	assert ($r.Count -ge 2)
	assert ($r -cnotcontains 'z')
}
