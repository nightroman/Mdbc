
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Get, "MdbcDatabase"), OutputType(typeof(IMongoDatabase))]
	public sealed class GetDatabaseCommand : AbstractClientCommand
	{
		[Parameter(Position = 0), ValidateNotNullOrEmpty]
		public string Name { get; set; }

		[Parameter]
		public MongoDatabaseSettings Settings { get; set; }

		protected override void BeginProcessing()
		{
			if (Name == null)
			{
				foreach (var databaseName in Client.ListDatabaseNames().ToEnumerable())
				{
					WriteObject(Client.GetDatabase(databaseName, Settings));
				}
			}
			else
			{
				WriteObject(Client.GetDatabase(Name, Settings));
			}
		}
	}
}
