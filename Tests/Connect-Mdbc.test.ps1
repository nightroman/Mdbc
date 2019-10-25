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
	Test-Type $Client MongoDB.Driver.MongoClient
	Test-Type $Database MongoDB.Driver.MongoDatabaseImpl
	Test-Type $Collection MongoDB.Driver.MongoCollectionImpl
	equals $Database.DatabaseNamespace.DatabaseName test
	equals $Collection.CollectionNamespace.FullName test.test
	equals $Collection.CollectionNamespace.CollectionName test
}

# By the convention, Connect-Mdbc .. * gets database objects.
task StarDatabase {
	$r = Connect-Mdbc . *
	assert ($r -ccontains 'test')
	assert ($r -ccontains 'local')
}

# By the convention, Connect-Mdbc .. .. * gets collection objects.
task StarCollection {
	$r = Connect-Mdbc . test *
	assert ($r -ccontains 'test')
}
