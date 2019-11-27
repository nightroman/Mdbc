. ./Zoo.ps1

task BadSet {
	Test-Error { Set-MdbcData } -Text ([Mdbc.Res]::ParameterFilter1)
	Test-Error { Set-MdbcData '' } -Text ([Mdbc.Res]::ParameterFilter1)
	Test-Error { Set-MdbcData $null } -Text ([Mdbc.Res]::ParameterFilter1)
	Test-Error { Set-MdbcData @{} } -Text ([Mdbc.Res]::InputDocNull)
	Test-Error { Set-MdbcData @{} $null } -Text ([Mdbc.Res]::InputDocNull)
	Test-Error { Set-MdbcData @{} '' } -Text @'
Cannot bind parameter 'Set' to the target. Exception setting "Set": "Cannot convert 'System.String' to 'BsonDocument'."
'@
}

task BadInput {
	Test-Error { @{} | Set-MdbcData $null } -Text ([Mdbc.Res]::ParameterFilter2)
	Test-Error { $null | Set-MdbcData } -Text ([Mdbc.Res]::InputDocNull)
	Test-Error { @{} | Set-MdbcData } -Text ([Mdbc.Res]::InputDocId)
}

task PipelineSet {
	Connect-Mdbc -NewCollection
	@{_id = 1}, @{_id = 2} | Add-MdbcData

	Get-MdbcData | .{process{ $_.n = $_._id; $_ }} | Set-MdbcData

	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "n" : 1 } { "_id" : 2, "n" : 2 }'
}

task PipelineSetAddResult {
	Connect-Mdbc -NewCollection
	@{_id = 1; n = 0} | Add-MdbcData

	$r1, $r2 = @{_id = 1; n = 1}, @{_id = 2; n = 2} | Set-MdbcData -Add -Result
	equals $r1.MatchedCount 1L
	equals $r1.ModifiedCount 1L
	equals $r2.MatchedCount 0L
	equals $r2.ModifiedCount 0L
	equals $r2.UpsertedId ([MongoDB.Bson.BsonInt32]2)

	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "n" : 1 } { "_id" : 2, "n" : 2 }'
}

# Set-MdbcData -Add
task SetAdd {
	Connect-Mdbc -NewCollection

	Set-MdbcData @{_id = 87} @{p2 = 2} -Add
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 87, "p2" : 2 }'

	Set-MdbcData @{_id = 87} @{p3 = 3} -Add
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 87, "p3" : 3 }'
}
