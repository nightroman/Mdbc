
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsLifecycle.Invoke, "MdbcAggregate"), OutputType(typeof(Dictionary))]
	public sealed class InvokeAggregateCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 0)]
		public object Pipeline { get { return null; } set { if (value != null) _Pipeline = Api.PipelineDefinition(value); } }
		PipelineDefinition<BsonDocument, BsonDocument> _Pipeline;

		[Parameter]
		public AggregateOptions Options { get; set; }

		[Parameter]
		public PSObject As { get { return null; } set { _ParameterAs_ = new ParameterAs(value); } }
		Type DocumentType { get { return _ParameterAs_ == null ? typeof(Dictionary) : _ParameterAs_.Type; } }
		ParameterAs _ParameterAs_;

		protected override void BeginProcessing()
		{
			if (_Pipeline == null) throw new PSArgumentException(Api.TextParameterPipeline);
			var convert = Actor.ConvertDocument(DocumentType);
			foreach (var document in Collection.Aggregate(_Pipeline, Options).ToEnumerable())
			{
				WriteObject(convert(document));
			}
		}
	}
}
