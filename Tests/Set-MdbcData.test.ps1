<#
.Synopsis
	Tests Set-MdbcData.
#>

. ./Zoo.ps1

task BadSet {
	Test-Error { Set-MdbcData } -Text $ErrorFilter
	Test-Error { Set-MdbcData '' } -Text $ErrorFilter
	Test-Error { Set-MdbcData $null } -Text $ErrorFilter
	Test-Error { Set-MdbcData @{} } -Text $TextInputDocNull
	Test-Error { Set-MdbcData @{} $null } -Text $TextInputDocNull
	Test-Error { Set-MdbcData @{} '' } -Text @'
Cannot bind parameter 'Set' to the target. Exception setting "Set": "Cannot convert 'System.String' to 'BsonDocument'."
'@
}

task BadInput {
	Test-Error { @{} | Set-MdbcData $null } -Text 'Parameter Filter must be omitted with pipeline input.'
	Test-Error { $null | Set-MdbcData } -Text $TextInputDocNull
	Test-Error { @{} | Set-MdbcData } -Text $TextInputDocId
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
