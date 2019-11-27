
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsData.Update, "MdbcData"), OutputType(typeof(UpdateResult))]
	public sealed class UpdateDataCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 0)]
		public object Filter { set { _Filter = Api.FilterDefinition(value); } }
		FilterDefinition<BsonDocument> _Filter;

		[Parameter(Position = 1)]
		public object Update { set { if (value != null) _Update = Api.UpdateDefinition(value); } }
		UpdateDefinition<BsonDocument> _Update;

		[Parameter]
		public SwitchParameter Add { get; set; }

		[Parameter]
		public SwitchParameter Many { get; set; }

		[Parameter]
		public UpdateOptions Options { get; set; }

		[Parameter]
		public SwitchParameter Result { get; set; }

		protected override void BeginProcessing()
		{
			if (_Filter == null)
				throw new PSArgumentException(Res.ParameterFilter1);

			if (_Update == null)
				throw new PSArgumentException(Res.ParameterUpdate);

			var options = Options ?? new UpdateOptions();
			if (Add)
				options.IsUpsert = true;

			try
			{
				UpdateResult result;
				if (Many)
				{
					result = Collection.UpdateMany(Session, _Filter, _Update, options);
				}
				else
				{
					result = Collection.UpdateOne(Session, _Filter, _Update, options);
				}

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
