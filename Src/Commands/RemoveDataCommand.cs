
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
		//_131121_104038 Not mandatory to avoid prompts. Manual null check is used instead for consistent messages.
		// String values from prompts might imply unexpected results.
		[Parameter(Position = 0)]
		public object Filter { set { _Filter = Api.FilterDefinition(value); } }
		FilterDefinition<BsonDocument> _Filter;

		[Parameter]
		public SwitchParameter Many { get; set; }

		[Parameter]
		public SwitchParameter Result { get; set; }

		protected override void BeginProcessing()
		{
			if (_Filter == null) throw new PSArgumentException(Api.TextParameterFilter); //_131121_104038

			try
			{
				DeleteResult result;
				if (Many)
				{
					result = Collection.DeleteMany(_Filter);
				}
				else
				{
					result = Collection.DeleteOne(_Filter);
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
