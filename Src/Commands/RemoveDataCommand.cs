
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Remove, "MdbcData"), OutputType(typeof(DeleteResult))]
	public sealed class RemoveDataCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 0, ValueFromPipeline = true)]
		public object Filter { get { return _Filter; } set { _Filter = value; _FilterSet = true; } }
		object _Filter;
		bool _FilterSet;

		[Parameter]
		public SwitchParameter Many { get; set; }

		[Parameter]
		public SwitchParameter Result { get; set; }

		protected override void BeginProcessing()
		{
			if (MyInvocation.ExpectingInput)
			{
				if (_FilterSet)
					throw new PSArgumentException(Api.TextParameterFilterInput);

				if (Many)
					throw new PSArgumentException("Parameter Many is not supported with pipeline input.");
			}
			else
			{
				if (_Filter == null)
					throw new PSArgumentException(Api.TextParameterFilter);
			}
		}

		protected override void ProcessRecord()
		{
			try
			{
				FilterDefinition<BsonDocument> filter;
				if (MyInvocation.ExpectingInput)
				{
					if (_Filter == null)
						throw new PSArgumentException(Api.TextInputDocNull);

					filter = Api.FilterDefinitionOfInputId(_Filter);
				}
				else
				{
					filter = Api.FilterDefinition(_Filter); //TODO
				}

				DeleteResult result;
				if (Many)
				{
					result = Collection.DeleteMany(Session, filter);
				}
				else
				{
					result = Collection.DeleteOne(Session, filter);
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
