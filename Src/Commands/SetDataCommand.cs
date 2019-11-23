
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
		//_131121_104038
		[Parameter(Position = 0)]
		public object Filter { set { _Filter = Api.FilterDefinition(value); } }
		FilterDefinition<BsonDocument> _Filter;

		//! keep it null, check later
		[Parameter(Position = 1)]
		public object Set { set { if (value != null) _Set = Actor.ToBsonDocument(value); } }
		BsonDocument _Set;

		[Parameter]
		public SwitchParameter Add { get; set; }

		[Parameter]
		public UpdateOptions Options { get; set; }

		[Parameter]
		public SwitchParameter Result { get; set; }

		protected override void BeginProcessing()
		{
			if (_Filter == null) throw new PSArgumentException(Api.TextParameterFilter); //_131121_104038
			if (_Set == null) throw new PSArgumentException(Api.TextParameterSet); //??

			var options = Options ?? new UpdateOptions();
			if (Add)
				options.IsUpsert = true;

			try
			{
				var result = Collection.ReplaceOne(Session, _Filter, _Set, options);

				if (Result)
					WriteObject(result);
			}
			catch (MongoException ex)
			{
				WriteException(ex, null);
			}
		}
	}
}
