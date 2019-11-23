
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsLifecycle.Invoke, "MdbcAggregate", DefaultParameterSetName = nsAll), OutputType(typeof(Dictionary))]
	public sealed class InvokeAggregateCommand : AbstractCollectionCommand
	{
		const string nsAll = "All";
		const string nsGroup = "Group";

		[Parameter(Position = 0, ParameterSetName = nsAll)]
		public object Pipeline { set { if (value != null) _Pipeline = Api.PipelineDefinition(value); } }
		PipelineDefinition<BsonDocument, BsonDocument> _Pipeline;

		[Parameter(Position = 0, Mandatory = true, ParameterSetName = nsGroup)]
		public object Group { set { _Group = Api.BsonDocument(value); } }
		BsonDocument _Group;

		[Parameter]
		public AggregateOptions Options { get; set; }

		[Parameter]
		public object As { set { _As.Set(value); } }
		readonly ParameterAs _As = new ParameterAs();

		protected override void BeginProcessing()
		{
			if (_Pipeline == null)
			{
				if (ParameterSetName == nsAll)
					throw new PSArgumentException(Api.TextParameterPipeline);

				if (_Group.Contains(BsonId.Name))
				{
					// with _id, just use input
					var docGroup = new BsonDocument("$group", _Group);
					_Pipeline = new BsonDocument[] { docGroup };
				}
				else
				{
					// make new doc with _id=null and input
					var docIdNull = new BsonDocument(BsonId.Element(BsonNull.Value));
					docIdNull.AddRange(_Group);
					var docGroup = new BsonDocument("$group", docIdNull);

					// $project to remove _id
					var docIdFalse = new BsonDocument(BsonId.Element(BsonBoolean.False));
					var docProject = new BsonDocument("$project", docIdFalse);

					// combine stages
					_Pipeline = new BsonDocument[] { docGroup, docProject };
				}
			}

			var convert = Actor.ConvertDocument(_As.Type);
			foreach (var document in Collection.Aggregate(_Pipeline, Options).ToEnumerable())
			{
				WriteObject(convert(document));
			}
		}
	}
}
