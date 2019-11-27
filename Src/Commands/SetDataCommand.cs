
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Set, "MdbcData"), OutputType(typeof(ReplaceOneResult))]
	public sealed class SetDataCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 0)]
		public object Filter { set { _FilterSet = true; _Filter = Api.FilterDefinition(value); } }
		FilterDefinition<BsonDocument> _Filter;
		bool _FilterSet;

		//! `get` is needed for PS
		[Parameter(Position = 1, ValueFromPipeline = true)]
		public object Set { get { return _Set; } set { if (value != null) _Set = Actor.ToBsonDocument(value); } }
		BsonDocument _Set;

		[Parameter]
		public SwitchParameter Add { get; set; }

		[Parameter]
		public UpdateOptions Options { get; set; }

		[Parameter]
		public SwitchParameter Result { get; set; }

		protected override void BeginProcessing()
		{
			if (MyInvocation.ExpectingInput)
			{
				if (_FilterSet)
					throw new PSArgumentException(Res.ParameterFilter2);
			}
			else
			{
				if (_Filter == null)
					throw new PSArgumentException(Res.ParameterFilter1);
			}

			if (Options == null)
				Options = new UpdateOptions();
			if (Add)
				Options.IsUpsert = true;
		}

		protected override void ProcessRecord()
		{
			try
			{
				if (Set == null)
					throw new PSArgumentException(Res.InputDocNull);

				if (MyInvocation.ExpectingInput)
				{
					if (_Set.TryGetElement(BsonId.Name, out BsonElement elem))
						_Filter = new BsonDocument(elem);
					else
						throw new PSArgumentException(Res.InputDocId);
				}

				var result = Collection.ReplaceOne(Session, _Filter, _Set, Options);

				if (Result)
					WriteObject(result);
			}
			catch (MongoException exn)
			{
				WriteException(exn, _Set);
			}
		}
	}
}
