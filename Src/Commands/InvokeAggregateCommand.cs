
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsLifecycle.Invoke, "MdbcAggregate"), OutputType(typeof(Dictionary))]
	public sealed class InvokeAggregateCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 0)]
		public object Pipeline { set { if (value != null) _Pipeline = Api.PipelineDefinition(value); } }
		PipelineDefinition<BsonDocument, BsonDocument> _Pipeline;

		[Parameter]
		public AggregateOptions Options { get; set; }

		[Parameter]
		public object As { set { _As.Set(value); } }
		readonly ParameterAs _As = new ParameterAs();

		protected override void BeginProcessing()
		{
			if (_Pipeline == null) throw new PSArgumentException(Api.TextParameterPipeline);
			var convert = Actor.ConvertDocument(_As.Type);
			foreach (var document in Collection.Aggregate(_Pipeline, Options).ToEnumerable())
			{
				WriteObject(convert(document));
			}
		}
	}
}
