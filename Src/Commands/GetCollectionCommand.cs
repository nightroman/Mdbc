
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Get, "MdbcCollection"), OutputType(typeof(IMongoCollection<BsonDocument>))]
	public sealed class GetCollectionCommand : AbstractDatabaseCommand
	{
		[Parameter(Position = 0), ValidateNotNullOrEmpty]
		public string Name { get; set; }

		[Parameter]
		public MongoCollectionSettings Settings { get; set; }

		[Parameter]
		public SwitchParameter NewCollection { get; set; }

		protected override void BeginProcessing()
		{
			if (Name == null)
			{
				foreach (var collectionName in Database.ListCollectionNames().ToEnumerable())
				{
					WriteObject(Database.GetCollection<BsonDocument>(collectionName, Settings));
				}
			}
			else
			{
				if (NewCollection)
					Database.DropCollection(Name);

				WriteObject(Database.GetCollection<BsonDocument>(Name, Settings));
			}
		}
	}
}
