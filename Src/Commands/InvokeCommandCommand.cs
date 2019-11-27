
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsLifecycle.Invoke, "MdbcCommand"), OutputType(typeof(Dictionary))]
	public sealed class InvokeCommandCommand : AbstractDatabaseCommand2
	{
		[Parameter(Position = 0)]
		public object Command { set { if (value != null) _Command = Api.Command(value); } }
		Command<BsonDocument> _Command;

		[Parameter]
		public object As { set { _As.Set(value); } }
		readonly ParameterAs _As = new ParameterAs();

		protected override void BeginProcessing()
		{
			if (_Command == null)
				throw new PSArgumentException(Res.ParameterCommand);

			try
			{
				var document = Database.RunCommand(Session, _Command);
				var convert = Actor.ConvertDocument(_As.Type);
				WriteObject(convert(document));
			}
			catch (MongoCommandException ex)
			{
				WriteException(ex, null);
			}
		}
	}
}
