
<#
.Synopsis
	Connect-Mdbc tests.
#>

. .\Zoo.ps1
Import-Module Mdbc

# Test error messages on invalid input
task BadParameters {
	Test-Error {Connect-Mdbc -DatabaseName test} 'ConnectionString parameter is null or missing.'
	Test-Error {Connect-Mdbc -CollectionName test} 'ConnectionString parameter is null or missing.'
}

# By the convention, Connect-Mdbc without parameters is works as Connect-Mdbc . test test
task Parameterless {
	Connect-Mdbc
	Test-Type $Server MongoDB.Driver.MongoServer
	Test-Type $Database MongoDB.Driver.MongoDatabase
	Test-Type $Collection MongoDB.Driver.MongoCollection
	equals $Database.Name test
	equals $Collection.Name test
}

# By the convention, Connect-Mdbc .. * gets database objects.
task StarDatabase {
	$r = Connect-Mdbc . * | .{process{ $_.Name }}
	assert ($r -ccontains 'test')
	assert ($r -ccontains 'local')
}

# By the convention, Connect-Mdbc .. .. * gets collection objects.
task StarCollection {
	$r = Connect-Mdbc . test * | .{process{ $_.Name }}
	assert ($r -ccontains 'test')
}
