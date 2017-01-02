
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Collections;
using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsLifecycle.Invoke, "MdbcCommand")]
	public sealed class InvokeCommandCommand : AbstractDatabaseCommand
	{
		[Parameter(Position = 0, Mandatory = true)]
		public PSObject Command
		{
			get { return null; }
			set
			{
				_CommandName = value.BaseObject as string;
				if (_CommandName == null)
				{
					var dictionary = value.BaseObject as IDictionary;
					if (dictionary != null)
						_CommandDocument = new CommandDocument(Actor.ToBsonDocument(dictionary));
					else
						throw new PSArgumentException("Invalid command object type.");
				}
			}
		}
		string _CommandName;
		CommandDocument _CommandDocument;

		[Parameter(Position = 1)]
		public object Value { get; set; }

		protected override void BeginProcessing()
		{
			if (_CommandDocument == null)
			{
				if (Value == null)
					_CommandDocument = new CommandDocument(_CommandName, 1);
				else
					_CommandDocument = new CommandDocument(_CommandName, Actor.ToBsonValue(Value));
			}

			try
			{
				var result = Database.RunCommand(_CommandDocument);
				WriteObject(new Dictionary(result.Response));
			}
			catch (MongoCommandException ex)
			{
				WriteException(ex, null);
			}
		}
	}
}
