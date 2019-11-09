
. ./Zoo.ps1
. ./Classes.lib.ps1

# serialized class for tests
$Person = [Person]::new()

task Command {
	# bad commands but Api works, Command fails later
	assert ([Mdbc.Api]::Command((New-MdbcData -Id 1)))

	$r1 = [Mdbc.Api]::Command(@{bad = 1})
	$r2 = [Mdbc.Api]::Command($r1)
	assert ($r1 -and [object]::ReferenceEquals($r1, $r2))

	# not real but should not fail, so such reals work
	assert ([Mdbc.Api]::Command(@{bar = $Person}))

	Test-Error { [Mdbc.Api]::Command($null) } '*: "Value cannot be null.*'
	Test-Error { [Mdbc.Api]::Command('') } '*: "Invalid JSON."'
	Test-Error { [Mdbc.Api]::Command('bad') } '*: "Invalid JSON."'

	Test-Error { [Mdbc.Api]::Command('{}') } "*""$ErrorEmptyDocument"""
	Test-Error { [Mdbc.Api]::Command(@{}) } "*""$ErrorEmptyDocument"""

	Test-Error { [Mdbc.Api]::Command(1) } '*: "Unable to cast object of type ''System.Int32'' to type ''MongoDB.Driver.Command*'
}

task FilterDefinition {
	equals ([Mdbc.Api]::FilterDefinition('')) $null
	equals ([Mdbc.Api]::FilterDefinition($null)) $null

	assert ([Mdbc.Api]::FilterDefinition('{}'))
	assert ([Mdbc.Api]::FilterDefinition(@{}))
	$r1 = [Mdbc.Api]::FilterDefinition(@{p1 = 1})
	$r2 = [Mdbc.Api]::FilterDefinition($r1)
	assert ($r1 -and [object]::ReferenceEquals($r1, $r2))

	# not real but should not fail, so such reals work
	assert ([Mdbc.Api]::FilterDefinition(@{bar = $Person}))

	Test-Error { [Mdbc.Api]::FilterDefinition('bad') } '*: "Invalid JSON."'
	Test-Error { [Mdbc.Api]::FilterDefinition(1) } '*: "Unable to cast object of type ''System.Int32'' to type ''MongoDB.Driver.FilterDefinition*'
}

task SortDefinition {
	equals ([Mdbc.Api]::SortDefinition('')) $null
	equals ([Mdbc.Api]::SortDefinition($null)) $null

	assert ([Mdbc.Api]::SortDefinition('{}'))
	assert ([Mdbc.Api]::SortDefinition(@{}))
	$r1 = [Mdbc.Api]::SortDefinition(@{p1 = 1})
	$r2 = [Mdbc.Api]::SortDefinition($r1)
	assert ($r1 -and [object]::ReferenceEquals($r1, $r2))

	# not real but should not fail, so such reals work
	assert ([Mdbc.Api]::SortDefinition(@{bar = $Person}))

	Test-Error { [Mdbc.Api]::SortDefinition('bad') } '*: "Invalid JSON."'
	Test-Error { [Mdbc.Api]::SortDefinition(1) } '*: "Unable to cast object of type ''System.Int32'' to type ''MongoDB.Driver.SortDefinition*'
}

task PipelineDefinition {
	# JSON
	assert ([Mdbc.Api]::PipelineDefinition('[]'))
	assert ([Mdbc.Api]::PipelineDefinition('{}'))
	assert ([Mdbc.Api]::PipelineDefinition('{x : 1}'))
	assert ([Mdbc.Api]::PipelineDefinition('[{x : 1}]'))
	$r1 = [Mdbc.Api]::PipelineDefinition(('{x : 1}', '{x : 1}'))

	# dictionary
	assert ([Mdbc.Api]::PipelineDefinition(@{}))
	assert ([Mdbc.Api]::PipelineDefinition((@{}, @{})))
	assert ([Mdbc.Api]::PipelineDefinition(@(New-MdbcData; New-MdbcData))) #_191103_084410

	# self
	$r2 = [Mdbc.Api]::PipelineDefinition($r1)
	assert ([object]::ReferenceEquals($r1, $r2))

	# not real but should not fail, so such reals work
	assert ([Mdbc.Api]::PipelineDefinition(@{bar = $Person}))

	# null
	Test-Error { [Mdbc.Api]::PipelineDefinition($null) } '*: "Value cannot be null.*'

	# bad JSON
	Test-Error { [Mdbc.Api]::PipelineDefinition('') } '*: "Invalid JSON."'
	Test-Error { [Mdbc.Api]::PipelineDefinition(' ') } '*: "Invalid JSON."'
	Test-Error { [Mdbc.Api]::PipelineDefinition('bad') } '*: "Invalid JSON."'
	Test-Error { [Mdbc.Api]::PipelineDefinition('1') } '*: "JSON: expected Array or Document, found Int32."'
	Test-Error { [Mdbc.Api]::PipelineDefinition('[1]') } '*: "Unable to cast object of type ''MongoDB.Bson.BsonInt32'' to type ''MongoDB.Bson.BsonDocument''."'
	Test-Error { [Mdbc.Api]::PipelineDefinition(@('[{x : 1}]', '[{x : 1}]')) } '*: "JSON: expected document, found Array."'

	# bad type
	Test-Error { [Mdbc.Api]::PipelineDefinition(1) } '*: "Unable to cast object of type ''System.Int32'' to type ''MongoDB.Driver.PipelineDefinition``2*'
}

task ProjectionDefinition {
	equals ([Mdbc.Api]::ProjectionDefinition('')) $null
	equals ([Mdbc.Api]::ProjectionDefinition($null)) $null

	assert ([Mdbc.Api]::ProjectionDefinition('{}'))
	assert ([Mdbc.Api]::ProjectionDefinition(@{}))
	$r1 = [Mdbc.Api]::ProjectionDefinition(@{p1 = 1})
	$r2 = [Mdbc.Api]::ProjectionDefinition($r1)
	assert ($r1 -and [object]::ReferenceEquals($r1, $r2))

	# not real but should not fail, so such reals work
	assert ([Mdbc.Api]::ProjectionDefinition(@{bar = $Person}))

	Test-Error { [Mdbc.Api]::ProjectionDefinition('bad') } '*: "Invalid JSON."'
	Test-Error { [Mdbc.Api]::ProjectionDefinition(1) } '*: "Unable to cast object of type ''System.Int32'' to type ''MongoDB.Driver.ProjectionDefinition*'
}

task UpdateDefinition {
	$r1 = [Mdbc.Api]::UpdateDefinition(@{bad = 1})
	$r2 = [Mdbc.Api]::UpdateDefinition($r1)
	assert ($r1 -and [object]::ReferenceEquals($r1, $r2))

	# not real but should not fail, so such reals work
	assert ([Mdbc.Api]::UpdateDefinition(@{bar = $Person}))

	Test-Error { [Mdbc.Api]::UpdateDefinition($null) } '*: "Value cannot be null.*'
	Test-Error { [Mdbc.Api]::UpdateDefinition('') } '*: "Invalid JSON."'
	Test-Error { [Mdbc.Api]::UpdateDefinition('bad') } '*: "Invalid JSON."'

	Test-Error { [Mdbc.Api]::UpdateDefinition('{}') } "*""$ErrorEmptyDocument"""
	Test-Error { [Mdbc.Api]::UpdateDefinition(@{}) } "*""$ErrorEmptyDocument"""

	Test-Error { [Mdbc.Api]::UpdateDefinition(1) } '*: "Unable to cast object of type ''System.Int32'' to type ''MongoDB.Driver.UpdateDefinition*'
}

task BsonMapping {
	# PSObject registered mapper
	$custom = [PSCustomObject]@{p1 = 1; p2 = 2}
	$r = [MongoDB.Bson.BsonTypeMapper]::MapToBsonValue($custom)
	equals $r.GetType() ([MongoDB.Bson.BsonDocument])
}

task Issue32 {
	$manifestEntry = [PSCustomObject]@{releaseNumber = 1; p1 = 1}
	$r = [Mdbc.Api]::UpdateDefinition(@{'$set' = @{value = $manifestEntry}})
	equals $r.Render($null, $null).ToString() '{ "$set" : { "value" : { "releaseNumber" : 1, "p1" : 1 } } }'
}
