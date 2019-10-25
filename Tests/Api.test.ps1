
. ./Zoo.ps1

task BadCommand {
	Test-Error { [Mdbc.Api]::Command($null) } '*: "Value cannot be null.*'
	Test-Error { [Mdbc.Api]::Command('') } '*: "Invalid JSON."'
	Test-Error { [Mdbc.Api]::Command('bad') } '*: "Invalid JSON."'

	Test-Error { [Mdbc.Api]::Command('{}') } "*""$ErrorEmptyDocument"""
	Test-Error { [Mdbc.Api]::Command(@{}) } "*""$ErrorEmptyDocument"""

	Test-Error { [Mdbc.Api]::Command(1) } '*: "Unable to cast object of type ''System.Int32'' to type ''MongoDB.Driver.Command*'
}

task Command {
	$(
		# bad commands but Api works, Command fails later
		[Mdbc.Api]::Command((New-MdbcData -Id 1))
		($r1 = [Mdbc.Api]::Command(@{bad = 1}))
		($r2 = [Mdbc.Api]::Command($r1))
		equals $r1 $r2
	) | Out-String
}

task BadPipelineDefinition {
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

task PipelineDefinition {
	$(
		# JSON
		[Mdbc.Api]::PipelineDefinition('[]')
		[Mdbc.Api]::PipelineDefinition('{}')
		[Mdbc.Api]::PipelineDefinition('{x : 1}')
		[Mdbc.Api]::PipelineDefinition('[{x : 1}]')
		($r1 = [Mdbc.Api]::PipelineDefinition(('{x : 1}', '{x : 1}')))

		# dictionary
		[Mdbc.Api]::PipelineDefinition(@{})
		[Mdbc.Api]::PipelineDefinition((@{}, @{}))
		[Mdbc.Api]::PipelineDefinition(@(New-MdbcData; New-MdbcData)) #_191103_084410

		# self
		$r2 = [Mdbc.Api]::PipelineDefinition($r1)
		equals $r1 $r2
	) | Out-String
}

task BadUpdateDefinition {
	Test-Error { [Mdbc.Api]::UpdateDefinition($null) } '*: "Value cannot be null.*'
	Test-Error { [Mdbc.Api]::UpdateDefinition('') } '*: "Invalid JSON."'
	Test-Error { [Mdbc.Api]::UpdateDefinition('bad') } '*: "Invalid JSON."'

	Test-Error { [Mdbc.Api]::UpdateDefinition('{}') } "*""$ErrorEmptyDocument"""
	Test-Error { [Mdbc.Api]::UpdateDefinition(@{}) } "*""$ErrorEmptyDocument"""

	Test-Error { [Mdbc.Api]::UpdateDefinition(1) } '*: "Unable to cast object of type ''System.Int32'' to type ''MongoDB.Driver.UpdateDefinition*'
}

task UpdateDefinition {
	$(
		($r1 = [Mdbc.Api]::UpdateDefinition(@{bad = 1}))
		($r2 = [Mdbc.Api]::UpdateDefinition($r1))
		equals $r1 $r2
	) | Out-String
}
